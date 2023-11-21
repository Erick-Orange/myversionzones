#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <xs>
#include <colorchat>
#define PLUGIN "Timerszones"
#define VERSION "v1"
#define AUTHOR "Orange"


enum ZONEMODE {
	ZM_NOTHING,
	ZM_START,
	ZM_STOP	
}

new zonemode[ZONEMODE][] = { "ZONE_MODE_NONE", "ZONE_START", "ZONE_STOP" }
new zonename[ZONEMODE][] = { "wgz_none", "wgz_start", "wgz_stop"}
new solidtyp[ZONEMODE] = { SOLID_NOT, SOLID_TRIGGER, SOLID_TRIGGER}
new zonecolor[ZONEMODE][3] = {
	{ 255, 255, 255 },		// None
	{ 0, 0, 255 },		// Start
	{ 255, 0, 0 }		// Stop
}

#define CAMPERTIME pev_iuser2
#define ZONEID pev_iuser1
#define MAXZONES 100
new zone[MAXZONES]
new maxzones		
new index		
new setupunits = 10	
new direction = 0	
new koordinaten[3][] = { "TRANSLATE_X_KOORD", "TRANSLATE_Y_KOORD", "TRANSLATE_Z_KOORD" }
new spr_dot		
new editor = 0	
#define TASK_BASIS_SHOWZONES 1000
new bool:editando[33] = false;
new g_iMaxPlayers;

native zone_start_signal(id)
native zone_stop_signal(id)

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)


	register_menu("MainMenu", -1, "MainMenuAction", 0)
	register_menu("EditMenu", -1, "EditMenuAction", 0)
	register_menu("KillMenu", -1, "KillMenuAction", 0)
	register_clcmd("say /timerzone", "InitTimerzone", ADMIN_RCON, " Abre el Timerzone-Menu")
	register_dictionary("Timerzone.txt")
	g_iMaxPlayers = get_maxplayers();
	register_forward(FM_Touch, "fw_touch")

	// Zonen nachladen
	set_task(1.0, "LoadWGZ")
	
}

public plugin_precache() {
	precache_model("models/gib_skull.mdl")
	spr_dot = precache_model("sprites/dot.spr")
}


public client_disconnect(player){
	if(!is_user_bot(player))
		editando[player] = false;
}
public client_putinserver(player){
	if(is_user_bot(player)){
		return PLUGIN_HANDLED;
	}
	editando[player] = false;
	editor = player
	FindAllZones();
	ShowAllZones();
}


public fw_touch(zone, player) {
	//if (editor) return FMRES_IGNORED
	
	if(is_user_bot(player))
		return FMRES_IGNORED
		
	if (!pev_valid(zone) || !is_user_connected(player))
		return FMRES_IGNORED

	static classname[33]
	pev(player, pev_classname, classname, 32)
	if (!equal(classname, "player")) 
		return FMRES_IGNORED
	
	pev(zone, pev_classname, classname, 32)
	if (!equal(classname, "timerzones")) 
		return FMRES_IGNORED
	
	new zm = pev(zone, ZONEID)
	
	if ( (ZONEMODE:zm == ZM_START) ) {
		zone_start_signal(player)
		//client_cmd(player, "spk hello")
	}
	
	if ( (ZONEMODE:zm == ZM_STOP) ) {
		zone_stop_signal(player)
		//client_cmd(player, "spk die")

	}
	
	return FMRES_IGNORED
}
/*
public ZoneTouch(player, zone) {

	new zm = pev(zone, ZONEID)

	if ( (ZONEMODE:zm == ZM_START) ) {
		//zone_start_signal(player)
		client_cmd(player, "spk hello")
	}
	
	if ( (ZONEMODE:zm == ZM_STOP) ) {
		//zone_stop_signal(player)
		client_cmd(player, "spk hello")

	}
	
	
}
*/
public RandomDirection(player) {
	new Float:velocity[3]
	velocity[0] = random_float(-256.0, 256.0)
	velocity[1] = random_float(-256.0, 256.0)
	velocity[2] = random_float(-256.0, 256.0)
	set_pev(player, pev_velocity, velocity)
}

// -----------------------------------------------------------------------------------------
//
//	Zonenerstellung
//
// -----------------------------------------------------------------------------------------
public CreateZone(Float:position[3], Float:mins[3], Float:maxs[3], zm, campertime) {
	new entity = fm_create_entity("info_target")
	set_pev(entity, pev_classname, "timerzones")
	fm_entity_set_model(entity, "models/gib_skull.mdl")
	fm_entity_set_origin(entity, position)

	set_pev(entity, pev_movetype, MOVETYPE_FLY)
	new id = pev(entity, ZONEID)
	if (editor)
	{
		set_pev(entity, pev_solid, SOLID_NOT)
	} else
	{
		set_pev(entity, pev_solid, solidtyp[ZONEMODE:id])
	}
	
	fm_entity_set_size(entity, mins, maxs)
	
	fm_set_entity_visibility(entity, 0)
	
	set_pev(entity, ZONEID, zm)
	set_pev(entity, CAMPERTIME, campertime)
	
	//log_amx("create zone '%s' with campertime %i seconds", zonename[ZONEMODE:zm], campertime)
	
	return entity
}

public CreateNewZone(Float:position[3]) {
	new Float:mins[3] = { -130.0, -10.0, -32.0 }
	new Float:maxs[3] = { 130.0, 10.0, 15.0 }
	return CreateZone(position, mins, maxs, 0, 10);	// ZM_NONE
}

public CreateZoneOnPlayer(player) {
	// Position und erzeugen
	new Float:position[3]
	pev(player, pev_origin, position)
	
	new entity = CreateNewZone(position)
	FindAllZones()
	
	for(new i = 0; i < maxzones; i++) if (zone[i] == entity) index = i;
}


// -----------------------------------------------------------------------------------------
//
//	Load & Save der WGZ
//
// -----------------------------------------------------------------------------------------
public SaveWGZ(player) {
	new zonefile[200]
	new mapname[50]

	// Verzeichnis holen
	get_configsdir(zonefile, 199)
	format(zonefile, 199, "%s/Timerzones", zonefile)
	if (!dir_exists(zonefile)) mkdir(zonefile)
	
	// Namen über Map erstellen
	get_mapname(mapname, 49)
	format(zonefile, 199, "%s/%s.wgz", zonefile, mapname)
	delete_file(zonefile)	// pauschal
	
	FindAllZones()	// zur Sicherheit
	
	// Header
	write_file(zonefile, "Timerzones Zone-File")
	write_file(zonefile, "; <zonename> <position (x/y/z)> <mins (x/y/z)> <maxs (x/y/z)> [<parameter>] ")
	write_file(zonefile, ";")
	write_file(zonefile, "")
	
	// alle Zonen speichern
	for(new i = 0; i < maxzones; i++)
	{
		new z = zone[i]	// das Entity
		
		// diverse Daten der Zone
		new zm = pev(z, ZONEID)
		
		// Koordinaten holen
		new Float:pos[3]
		pev(z, pev_origin, pos)
		
		// Dimensionen holen
		new Float:mins[3], Float:maxs[3]
		pev(z, pev_mins, mins)
		pev(z, pev_maxs, maxs)
		
		// Ausgabe formatieren
		//  -> Type und CamperTime
		new output[1000]
		format(output, 999, "%s", zonename[ZONEMODE:zm])
		//  -> Position
		format(output, 999, "%s %.1f %.1f %.1f", output, pos[0], pos[1], pos[2])
		//  -> Dimensionen
		format(output, 999, "%s %.0f %.0f %.0f", output, mins[0], mins[1], mins[2])
		format(output, 999, "%s %.0f %.0f %.0f", output, maxs[0], maxs[1], maxs[2])
		
		// und schreiben
		write_file(zonefile, output)
	}
	
	client_print(player, print_chat, "%L", player, "ZONE_FILE_SAVED", zonefile)
}

public LoadWGZ() {
	new zonefile[200]
	new mapname[50]

	// Verzeichnis holen
	get_configsdir(zonefile, 199)
	format(zonefile, 199, "%s/Timerzones", zonefile)
	
	// Namen über Map erstellen
	get_mapname(mapname, 49)
	format(zonefile, 199, "%s/%s.wgz", zonefile, mapname)
	
	if (!file_exists(zonefile))
	{
		log_amx("no zone-file found")
		return
	}
	
	// einlesen der Daten
	new input[1000], line = 0, len
	
	while( (line = read_file(zonefile , line , input , 127 , len) ) != 0 ) 
	{
		if (!strlen(input)  || (input[0] == ';')) continue;	// Kommentar oder Leerzeile

		new data[20], zm = 0, ct		// "abgebrochenen" Daten - ZoneMode - CamperTime
		new Float:mins[3], Float:maxs[3], Float:pos[3]	// Größe & Position

		// Zone abrufen
		strbreak(input, data, 20, input, 999)
		zm = -1
		for(new i = 0; ZONEMODE:i < ZONEMODE; ZONEMODE:i++)
		{
			// Änderungen von CS:CZ zu allen Mods
			if (equal(data, "wgz_camper_te")) format(data, 19, "wgz_camper_t1")
			if (equal(data, "wgz_camper_ct")) format(data, 19, "wgz_camper_t2")
			if (equal(data, zonename[ZONEMODE:i])) zm = i;
		}
		
		if (zm == -1)
		{
			log_amx("undefined zone -> '%s' ... dropped", data)
			continue;
		}
		
		// Position holen
		strbreak(input, data, 20, input, 999);	pos[0] = str_to_float(data);
		strbreak(input, data, 20, input, 999);	pos[1] = str_to_float(data);
		strbreak(input, data, 20, input, 999);	pos[2] = str_to_float(data);
		
		// Dimensionen
		strbreak(input, data, 20, input, 999);	mins[0] = str_to_float(data);
		strbreak(input, data, 20, input, 999);	mins[1] = str_to_float(data);
		strbreak(input, data, 20, input, 999);	mins[2] = str_to_float(data);
		strbreak(input, data, 20, input, 999);	maxs[0] = str_to_float(data);
		strbreak(input, data, 20, input, 999);	maxs[1] = str_to_float(data);
		strbreak(input, data, 20, input, 999);	maxs[2] = str_to_float(data);


		// und nun noch erstellen
		CreateZone(pos, mins, maxs, zm, ct);
	}
	
	FindAllZones()
	HideAllZones()

}

public FX_Box(Float:sizemin[3], Float:sizemax[3], color[3], life) {
	// FX
	message_begin(MSG_ALL, SVC_TEMPENTITY);

	write_byte(31);
	
	write_coord( floatround( sizemin[0] ) ); // x
	write_coord( floatround( sizemin[1] ) ); // y
	write_coord( floatround( sizemin[2] ) ); // z
	
	write_coord( floatround( sizemax[0] ) ); // x
	write_coord( floatround( sizemax[1] ) ); // y
	write_coord( floatround( sizemax[2] ) ); // z

	write_short(life)	// Life
	
	write_byte(color[0])	// Color R / G / B
	write_byte(color[1])
	write_byte(color[2])
	
	message_end(); 
}

public FX_Line(start[3], stop[3], color[3], brightness) {
	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, editor) 
	
	write_byte( TE_BEAMPOINTS ) 
	
	write_coord(start[0]) 
	write_coord(start[1])
	write_coord(start[2])
	
	write_coord(stop[0])
	write_coord(stop[1])
	write_coord(stop[2])
	
	write_short( spr_dot )
	
	write_byte( 1 )	// framestart 
	write_byte( 1 )	// framerate 
	write_byte( 4 )	// life in 0.1's 
	write_byte( 5 )	// width
	write_byte( 0 ) 	// noise 
	
	write_byte( color[0])   // r, g, b 
	write_byte( color[1])   // r, g, b 
	write_byte( color[2])   // r, g, b 
	
	write_byte( brightness )  	// brightness 
	write_byte( 0 )   	// speed 
	
	message_end() 
}

public DrawLine(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, color[3]) {
	new start[3]
	new stop[3]
	
	start[0] = floatround( x1 )
	start[1] = floatround( y1 )
	start[2] = floatround( z1 )
	
	stop[0] = floatround( x2 )
	stop[1] = floatround( y2 )
	stop[2] = floatround( z2 )

	FX_Line(start, stop, color, 200)
}



public ShowAllZones() {
	FindAllZones()	// zur Sicherheit alle suchen
	
	for(new i = 0; i < maxzones; i++)
	{
		new z = zone[i]
		remove_task(TASK_BASIS_SHOWZONES + z)
		new id = pev(zone[i], ZONEID)
		set_task(0.2, "ShowZoneBox", TASK_BASIS_SHOWZONES + z, _, _, "b")
		set_pev(z, pev_solid, solidtyp[ZONEMODE:id])
	}
}

	
public ShowZoneBox(entity) {
	entity -= TASK_BASIS_SHOWZONES
	if ((!fm_is_valid_ent(entity))) return


	new Float:pos[3]
	pev(entity, pev_origin, pos)
	if (!fm_is_in_viewcone(editor, pos) && (entity != zone[index])) return	


	new Float:editorpos[3]
	pev(editor, pev_origin, editorpos)
	new Float:hitpoint[3]	// da ist der Treffer
	fm_trace_line(-1, editorpos, pos, hitpoint)
	static player;
	for(player = 1; player <= g_iMaxPlayers; player++)
	{
		if(editando[player] == true)
			if (entity == zone[index]) DrawLine(editorpos[0], editorpos[1], editorpos[2] - 16.0, pos[0], pos[1], pos[2], {255, 0, 0} )

	}
	
	new Float:dh = vector_distance(editorpos, pos) - vector_distance(editorpos, hitpoint)
	if ( (floatabs(dh) > 128.0) && (entity != zone[index])) return		


	new Float:mins[3], Float:maxs[3]
	pev(entity, pev_mins, mins)
	pev(entity, pev_maxs, maxs)


	mins[0] += pos[0]
	mins[1] += pos[1]
	mins[2] += pos[2]
	maxs[0] += pos[0]
	maxs[1] += pos[1]
	maxs[2] += pos[2]
	

	new zm = pev(entity, ZONEID)

	DrawLine(mins[0], mins[1], mins[2], maxs[0], mins[1], mins[2], zonecolor[ZONEMODE:zm])
	DrawLine(mins[0], mins[1], mins[2], mins[0], maxs[1], mins[2], zonecolor[ZONEMODE:zm])
		
	DrawLine(mins[0], maxs[1], mins[2], maxs[0], maxs[1], mins[2], zonecolor[ZONEMODE:zm])
	DrawLine(maxs[0], maxs[1], mins[2], maxs[0], mins[1], mins[2], zonecolor[ZONEMODE:zm])
	

	if (entity != zone[index]) return
}

public HideAllZones() {
	editor = 0	// Menü für den nächsten wieder frei geben ... ufnktionalität aktivieren
	for(new i = 0; i < maxzones; i++)
	{
		new id = pev(zone[i], ZONEID)
		set_pev(zone[i], pev_solid, solidtyp[ZONEMODE:id])
		remove_task(TASK_BASIS_SHOWZONES + zone[i])
	}
}

public FindAllZones() {
	new entity = -1
	maxzones = 0
	while( (entity = fm_find_ent_by_class(entity, "timerzones")) )
	{
		zone[maxzones] = entity
		maxzones++
	}
}

public InitTimerzone(player) {
	if (!(get_user_flags(player) & ADMIN_RCON))
	{
		ColorChat(player, RED, "No tenes acceso al menu de Timerszones.")
		return PLUGIN_HANDLED
	}
	editando[player] = true;
	set_task(0.1, "OpenTimerzone", player)

	return PLUGIN_HANDLED
}

public OpenTimerzone(player) {
	new trans[70]
	new menu[1024]
	new zm = -1
	new menukeys = MENU_KEY_0 + MENU_KEY_4 + MENU_KEY_9
	
	if (fm_is_valid_ent(zone[index]))
	{
		zm = pev(zone[index], ZONEID)
	}
	
	format(menu, 1023, "\dTimerZones-Menu - Ver. %s\w", VERSION)
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	format(menu, 1023, "%L", player, "WGM_ZONE_FOUND", menu, maxzones)
	
	if (zm != -1)
	{
		format(trans, 69, "%L", player, zonemode[ZONEMODE:zm])
		format(menu, 1023, "%L", player, "WGM_ZONE_CURRENT_NONE", menu, index + 1, trans)

		menukeys += MENU_KEY_2 + MENU_KEY_3 + MENU_KEY_1
		format(menu, 1023, "%s^n", menu)		// Leerzeile
		format(menu, 1023, "%s^n", menu)		// Leerzeile
		format(menu, 1023, "%L", player, "WGM_ZONE_EDIT", menu)
		format(menu, 1023, "%L", player, "WGM_ZONE_CHANGE", menu)
	}
	
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	format(menu, 1023, "%L" ,player, "WGM_ZONE_CREATE", menu)
	
	if (zm != -1)
	{
		menukeys += MENU_KEY_6
		format(menu, 1023, "%L", player, "WGM_ZONE_DELETE", menu)
	}
	format(menu, 1023, "%L", player, "WGM_ZONE_SAVE", menu)
		
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	format(menu, 1023, "%L" ,player, "WGM_ZONE_EXIT", menu)
	
	show_menu(player, menukeys, menu, -1, "MainMenu")
	client_cmd(player, "spk sound/buttons/blip1.wav")
}

public MainMenuAction(player, key) {
	key = (key == 10) ? 0 : key + 1
	switch(key) 
	{
		case 1: {
				// Zone editieren
				if (fm_is_valid_ent(zone[index])) OpenEditMenu(player); else OpenTimerzone(player);
			}
		case 2: {
				// vorherige Zone
				index = (index > 0) ? index - 1 : index;
				OpenTimerzone(player)
			}
		case 3: {
				// nächste Zone
				index = (index < maxzones - 1) ? index + 1 : index;
				OpenTimerzone(player)
			}
		case 4:	{
				// neue Zone über dem Spieler
				if (maxzones < MAXZONES - 1)
				{
					CreateZoneOnPlayer(player);
					ShowAllZones();
					MainMenuAction(player, 0);	// selber aufrufen
				} else
				{
					client_print(player, print_chat, "%L", player, "ZONE_FULL")
					client_cmd(player, "spk sound/buttons/button10.wav")
					set_task(0.5, "OpenTimerzone", player)
				}
			}
		case 6: {
				OpenKillMenu(player);
			}
		case 9: {
				// Zonen speichern
				SaveWGZ(player)
				OpenTimerzone(player)
			}
		case 10:{
				editando[player] = false;
			}
	}
}

public OpenKillMenu(player) {
	new menu[1024]
	
	format(menu, 1023, "Quieres eliminar la zona?^n[1] No^n[0] Si eliminar", menu)
	
	show_menu(player, MENU_KEY_1 + MENU_KEY_0, menu, -1, "KillMenu")
	
	client_cmd(player, "spk sound/buttons/button10.wav")
}

public KillMenuAction(player, key) {
	key = (key == 10) ? 0 : key + 1
	switch(key)
	{
		case 1: {
				ColorChat(player, RED, "^3[Tz]^1 Elegiste NO eliminar la zona.")
			}
		case 10:{
				fm_remove_entity(zone[index])
				index--;
				if (index < 0) index = 0;
				ColorChat(player, RED, "^3[Tz]^1 Elegiste SI eliminar la zona.")
				FindAllZones()
			}
	}
	OpenTimerzone(player)
}
public OpenEditMenu(player) {
	new trans[70]
	
	new menu[1024]
	new menukeys = MENU_KEY_0 + MENU_KEY_1 + MENU_KEY_4 + MENU_KEY_5 + MENU_KEY_6 + MENU_KEY_7 + MENU_KEY_8 + MENU_KEY_9
	
	format(menu, 1023, "\dEditar TimerZone\w")
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	format(menu, 1023, "%s^n", menu)		// Leerzeile

	new zm = -1

	if (fm_is_valid_ent(zone[index]))
	{
		zm = pev(zone[index], ZONEID)
	}
	
	if (zm != -1)
	{
		format(trans, 69, "%L", player, zonemode[ZONEMODE:zm])
		format(menu, 1023, "%L", player, "WGE_ZONE_CURRENT_NONE", menu, trans)
		format(menu, 1023, "%s^n", menu)		// Leerzeile
	}
	
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	
	format(trans, 49, "%L", player, koordinaten[direction])
	format(menu, 1023, "%L", player, "WGE_ZONE_SIZE_INIT", menu, trans)
	format(menu, 1023, "%L", player, "WGE_ZONE_SIZE_MINS", menu)
	format(menu, 1023, "%L", player, "WGE_ZONE_SIZE_MAXS", menu)
	format(menu, 1023, "%L", player, "WGE_ZONE_SIZE_STEP", menu, setupunits)
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	format(menu, 1023, "%s^n", menu)		// Leerzeile
	format(menu, 1023, "%L", player, "WGE_ZONE_SIZE_QUIT", menu)
	
	show_menu(player, menukeys, menu, -1, "EditMenu")
	client_cmd(player, "spk sound/buttons/blip1.wav")
}

public EditMenuAction(player, key) {
	key = (key == 10) ? 0 : key + 1
	switch(key)
	{
		case 1: {
				// nächster ZoneMode
				new zm = -1
				zm = pev(zone[index], ZONEID)
				if (ZONEMODE:zm == ZM_STOP) zm = 0; else zm++;
				set_pev(zone[index], ZONEID, zm)
				OpenEditMenu(player)
			}
		case 2: {
				
				OpenEditMenu(player)
			}
		case 3: {
				
				OpenEditMenu(player)
			}
		case 4: {
				// Editier-Richtung ändern
				direction = (direction < 2) ? direction + 1 : 0
				OpenEditMenu(player)
			}
		case 5: {
				// von "mins" / rot etwas abziehen -> schmaler
				ZuRotAddieren()
				OpenEditMenu(player)
			}
		case 6: {
				// zu "mins" / rot etwas addieren -> breiter
				VonRotAbziehen()
				OpenEditMenu(player)
			}
		case 7: {
				// von "maxs" / gelb etwas abziehen -> schmaler
				VonGelbAbziehen()
				OpenEditMenu(player)
			}
		case 8: {
				// zu "maxs" / gelb etwas addierne -> breiter
				ZuGelbAddieren()
				OpenEditMenu(player)
			}
		case 9: {
				// Schreitweite ändern
				setupunits = (setupunits < 100) ? setupunits * 10 : 1
				OpenEditMenu(player)
			}
		case 10:{
				OpenTimerzone(player)
			}
	}
}

public VonRotAbziehen() {
	new entity = zone[index]
	
	// Koordinaten holen
	new Float:pos[3]
	pev(entity, pev_origin, pos)

	// Dimensionen holen
	new Float:mins[3], Float:maxs[3]
	pev(entity, pev_mins, mins)
	pev(entity, pev_maxs, maxs)

	// könnte Probleme geben -> zu klein
	//if ((floatabs(mins[direction]) + maxs[direction]) < setupunits + 1) return
	
	mins[direction] -= float(setupunits) / 2.0
	maxs[direction] += float(setupunits) / 2.0
	pos[direction] -= float(setupunits) / 2.0
	
	set_pev(entity, pev_origin, pos)
	fm_entity_set_size(entity, mins, maxs)
}

public ZuRotAddieren() {
	new entity = zone[index]
	
	// Koordinaten holen
	new Float:pos[3]
	pev(entity, pev_origin, pos)

	// Dimensionen holen
	new Float:mins[3], Float:maxs[3]
	pev(entity, pev_mins, mins)
	pev(entity, pev_maxs, maxs)

	// könnte Probleme geben -> zu klein
	if ((floatabs(mins[direction]) + maxs[direction]) < setupunits + 1) return

	mins[direction] += float(setupunits) / 2.0
	maxs[direction] -= float(setupunits) / 2.0
	pos[direction] += float(setupunits) / 2.0
	
	set_pev(entity, pev_origin, pos)
	fm_entity_set_size(entity, mins, maxs)
}

public VonGelbAbziehen() {
	new entity = zone[index]
	
	// Koordinaten holen
	new Float:pos[3]
	pev(entity, pev_origin, pos)

	// Dimensionen holen
	new Float:mins[3], Float:maxs[3]
	pev(entity, pev_mins, mins)
	pev(entity, pev_maxs, maxs)

	// könnte Probleme geben -> zu klein
	if ((floatabs(mins[direction]) + maxs[direction]) < setupunits + 1) return

	mins[direction] += float(setupunits) / 2.0
	maxs[direction] -= float(setupunits) / 2.0
	pos[direction] -= float(setupunits) / 2.0
	
	set_pev(entity, pev_origin, pos)
	fm_entity_set_size(entity, mins, maxs)
}

public ZuGelbAddieren() {
	new entity = zone[index]
	
	// Koordinaten holen
	new Float:pos[3]
	pev(entity, pev_origin, pos)

	// Dimensionen holen
	new Float:mins[3], Float:maxs[3]
	pev(entity, pev_mins, mins)
	pev(entity, pev_maxs, maxs)

	mins[direction] -= float(setupunits) / 2.0
	maxs[direction] += float(setupunits) / 2.0
	pos[direction] += float(setupunits) / 2.0
	
	set_pev(entity, pev_origin, pos)
	fm_entity_set_size(entity, mins, maxs)
}


stock fm_DispatchSpawn(entity)
	return dllfunc(DLLFunc_Spawn, entity)

stock fm_remove_entity(index)
	return engfunc(EngFunc_RemoveEntity, index)

stock fm_find_ent_by_class(index, const classname[])
	return engfunc(EngFunc_FindEntityByString, index, "classname", classname)

stock fm_is_valid_ent(index)
	return pev_valid(index)

stock fm_entity_set_size(index, const Float:mins[3], const Float:maxs[3])
	return engfunc(EngFunc_SetSize, index, mins, maxs)

stock fm_entity_set_model(index, const model[])
	return engfunc(EngFunc_SetModel, index, model)

stock fm_create_entity(const classname[])
	return engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, classname))

stock fm_entity_set_origin(index, const Float:origin[3]) {
	new Float:mins[3], Float:maxs[3]
	pev(index, pev_mins, mins)
	pev(index, pev_maxs, maxs)
	engfunc(EngFunc_SetSize, index, mins, maxs)

	return engfunc(EngFunc_SetOrigin, index, origin)
}

stock fm_set_entity_visibility(index, visible = 1) {
	set_pev(index, pev_effects, visible == 1 ? pev(index, pev_effects) & ~EF_NODRAW : pev(index, pev_effects) | EF_NODRAW)

	return 1
}

stock bool:fm_is_in_viewcone(index, const Float:point[3]) {
	new Float:angles[3]
	pev(index, pev_angles, angles)
	engfunc(EngFunc_MakeVectors, angles)
	global_get(glb_v_forward, angles)
	angles[2] = 0.0

	new Float:origin[3], Float:diff[3], Float:norm[3]
	pev(index, pev_origin, origin)
	xs_vec_sub(point, origin, diff)
	diff[2] = 0.0
	xs_vec_normalize(diff, norm)

	new Float:dot, Float:fov
	dot = xs_vec_dot(norm, angles)
	pev(index, pev_fov, fov)
	if (dot >= floatcos(fov * M_PI / 360))
		return true

	return false
}

stock fm_trace_line(ignoreent, const Float:start[3], const Float:end[3], Float:ret[3]) {
	engfunc(EngFunc_TraceLine, start, end, ignoreent == -1 ? 1 : 0, ignoreent, 0)

	new ent = get_tr2(0, TR_pHit)
	get_tr2(0, TR_vecEndPos, ret)

	return pev_valid(ent) ? ent : 0
}
