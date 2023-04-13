#using scripts\codescripts\struct;

#using scripts\shared\audio_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;//DO NOT REMOVE - needed for system registration
#using scripts\shared\flag_shared;
#using scripts\shared\array_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\hud_message_shared;
#using scripts\shared\load_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\music_shared;
#using scripts\shared\_oob;
#using scripts\shared\scene_shared;
#using scripts\shared\serverfaceanim_shared;
#using scripts\shared\system_shared;
#using scripts\shared\turret_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\archetype_shared\archetype_shared;
#using scripts\shared\callbacks_shared;

//Abilities
#using scripts\shared\abilities\_ability_player;	//DO NOT REMOVE - needed for system registration

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm;
#using scripts\zm\gametypes\_spawnlogic;

#using scripts\zm\_destructible;
#using scripts\zm\_util;

//REGISTRATION - These scripts are initialized here
//Do not remove unless you are removing the script from the game

//Gametypes Registration
#using scripts\zm\gametypes\_clientids;
#using scripts\zm\gametypes\_scoreboard;
#using scripts\zm\gametypes\_serversettings;
#using scripts\zm\gametypes\_shellshock;
#using scripts\zm\gametypes\_spawnlogic;
#using scripts\zm\gametypes\_spectating;
#using scripts\zm\gametypes\_weaponobjects;

//Systems registration
#using scripts\zm\_art;
#using scripts\zm\_callbacks;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_behavior;
#using scripts\zm\_zm_blockers;
#using scripts\zm\_zm_bot;
#using scripts\zm\_zm_clone;
#using scripts\zm\_zm_devgui;
#using scripts\zm\_zm_magicbox;
#using scripts\zm\_zm_playerhealth;
#using scripts\zm\_zm_power;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_traps;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_zonemgr;

//Weapon registration
#using scripts\zm\gametypes\_weaponobjects;

#precache( "fx", "_t6/bio/player/fx_footstep_dust" );
#precache( "fx", "_t6/bio/player/fx_footstep_sand" );
#precache( "fx", "_t6/bio/player/fx_footstep_mud" );
#precache( "fx", "_t6/bio/player/fx_footstep_water" );

#namespace load;

function main()
{
    _INIT_ZCOUNTER();
    
	level thread OnPlayerConnect();
    level thread new_zombie_speed();
	zm::init();

	level._loadStarted = true;
	
	register_clientfields();

	level.aiTriggerSpawnFlags = getaitriggerflags();
	level.vehicleTriggerSpawnFlags = getvehicletriggerflags();
		
	level thread start_intro_screen_zm();

	//thread _spawning::init();
	//thread _deployable_weapons::init();
	//thread _minefields::init();
	//thread _rotating_object::init();
	//thread _shutter::main();
	//thread _flare::init();
	//thread _pipes::main();
	//thread _vehicles::init();
	//thread _dogs::init();
	//thread _tutorial::init();
	
	setup_traversals();

 	footsteps();
 	
	system::wait_till( "all" );

	level thread load::art_review();
	
	level flagsys::set( "load_main_complete" );
}

function footsteps()
{
	if ( IS_TRUE( level.FX_exclude_footsteps ) ) 
	{
		return;
	}

	zombie_utility::setFootstepEffect( "asphalt",  "_t6/bio/player/fx_footstep_dust" ); 
	zombie_utility::setFootstepEffect( "brick",    "_t6/bio/player/fx_footstep_dust" );
	zombie_utility::setFootstepEffect( "carpet",   "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "cloth",    "_t6/bio/player/fx_footstep_dust" );
	zombie_utility::setFootstepEffect( "concrete", "_t6/bio/player/fx_footstep_dust" ); 
	zombie_utility::setFootstepEffect( "dirt",     "_t6/bio/player/fx_footstep_sand" );
	zombie_utility::setFootstepEffect( "foliage",  "_t6/bio/player/fx_footstep_sand" );  
	zombie_utility::setFootstepEffect( "gravel",   "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "grass",    "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "metal",    "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "mud",      "_t6/bio/player/fx_footstep_mud" ); 
	zombie_utility::setFootstepEffect( "paper",    "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "plaster",  "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "rock",     "_t6/bio/player/fx_footstep_dust" );  
	zombie_utility::setFootstepEffect( "sand",     "_t6/bio/player/fx_footstep_sand" );  
	zombie_utility::setFootstepEffect( "water",    "_t6/bio/player/fx_footstep_water" );
	zombie_utility::setFootstepEffect( "wood",     "_t6/bio/player/fx_footstep_dust" ); 
}

function setup_traversals()
{
	/*
	potential_traverse_nodes = GetAllNodes();
	for (i = 0; i < potential_traverse_nodes.size; i++)
	{
		node = potential_traverse_nodes[i];
		if (node.type == "Begin")
		{
			node zombie_shared::init_traverse();
		}
	}
	*/
}

function start_intro_screen_zm( )
{
	players = GetPlayers();
	for(i = 0; i < players.size; i++)
	{
		players[i] lui::screen_fade_out( 0, undefined );
		players[i] freezecontrols(true);
	}
	wait 1;
}

function register_clientfields()
{
	//clientfield::register( "missile", "cf_m_proximity", VERSION_SHIP, 1, "int" );
	//clientfield::register( "missile", "cf_m_emp", VERSION_SHIP, 1, "int" );
	//clientfield::register( "missile", "cf_m_stun", VERSION_SHIP, 1, "int" );
	
	//clientfield::register( "scriptmover", "cf_s_emp", VERSION_SHIP, 1, "int" );
	//clientfield::register( "scriptmover", "cf_s_stun", VERSION_SHIP, 1, "int" );
	
	//clientfield::register( "world", "sndPrematch", VERSION_SHIP, 1, "int" );
	//clientfield::register( "toplayer", "sndMelee", VERSION_SHIP, 1, "int" );
	//clientfield::register( "toplayer", "sndEMP", VERSION_SHIP, 1, "int" );	
	
	clientfield::register( "allplayers", "zmbLastStand", VERSION_SHIP, 1, "int" );
	//clientfield::register( "toplayer", "zmbLastStand", VERSION_SHIP, 1, "int" );

	clientfield::register( "clientuimodel", "zmhud.swordEnergy", VERSION_SHIP, 7, "float" ); // energy: 0 to 1
	clientfield::register( "clientuimodel", "zmhud.swordState", VERSION_SHIP, 4, "int" ); // state: 0 = hidden, 1 = charging, 2 = ready, 3 = inuse, 4 = unavailable (grey), 5 = ele-charging, 6 = ele-ready, 7 = ele-inuse,
	clientfield::register( "clientuimodel", "zmhud.swordChargeUpdate", VERSION_SHIP, 1, "counter" );
}

function OnPlayerConnect()
{
	while(true)
	{
		level waittill("connecting", player);
		player thread OnPlayerSpawned();
		timer_hud();
	}
}

function OnPlayerSpawned()
{
	level endon( "game_ended" );
	self endon( "disconnect" );

	self.initialspawn = true;

	level thread timer_hud();
}

function timer_hud()
{
	self endon("disconnect");
	self endon("end_game");

	level waittill("all_players_spawned");
	wait 5.25;

	level.isTimedGameplay = true;

	level.timer = NewHudElem();
	level.timer.horzAlign = "right";
	level.timer.vertAlign = "top";
	level.timer.alignX = "right";
	level.timer.alignY = "top";
	level.timer.y = 2;
	level.timer.x = 0;
	level.timer.foreground = 0;
	level.timer.hideWhenInMenu = 1;
	level.timer.fontScale = 1.5;
	level.timer.alpha = 1;
	level.timer.color = ( 1, 1, 1 );
	
	level.timer SetTimerUp(0);

	level.total_time = 0;
	start_time = int((getTime() / 1000));


	level thread destroy_hud_end_game();
	level thread round_timer_hud_text();
	level thread round_timer_hud();
}

function destroy_hud_end_game()
{	
	level waittill( "end_game" );

	level.timer FadeOverTime( 0.5 );
	level.timer.alpha = 0;
	wait 0.5;
	level.timer destroy();
}

function round_timer_hud_text()
{	
	level endon("disconnect");
	level endon("end_game");

	level.round_timer_hud_text = NewHudElem();
	level.round_timer_hud_text SetText("Round Time: ");
	level.round_timer_hud_text.horzAlign = "left";
	level.round_timer_hud_text.vertAlign = "top";
	level.round_timer_hud_text.alignX = "left";
	level.round_timer_hud_text.alignY = "top";
	level.round_timer_hud_text.y = 17;
	level.round_timer_hud_text.x = 5;
	level.round_timer_hud_text.fontScale = 1.5;
	level.round_timer_hud_text.alpha = 0;
	level.round_timer_hud_text.color = ( 1, 1, 1 );

	for(;;)
	{
		level waittill( "end_of_round" );
		if(getDvarInt( "round_timer" ) == 0)
    	{
        	if(level.round_timer_hud_text.alpha != 0)
        	{
            	level.round_timer_hud_text.alpha = 0;
        	}
    	}
    	else if(getDvarInt( "round_timer" ) == 1)
    	{
        	level.round_timer_hud_text fadeOverTime(0.15);
			level.round_timer_hud_text.alpha = 1;
			wait 6;
			level.round_timer_hud_text fadeOverTime(0.15);
			level.round_timer_hud_text.alpha = 0;
    	}
	}
}

function round_timer_hud()
{	
	level endon("disconnect");
	level endon("end_game");

	level.round_timer_hud = NewHudElem();
	level.round_timer_hud.horzAlign = "right";
	level.round_timer_hud.vertAlign = "top";
	level.round_timer_hud.alignX = "right";
	level.round_timer_hud.alignY = "top";
	level.round_timer_hud.y = 17;
	level.round_timer_hud.x = 64;
	level.round_timer_hud.fontScale = 1.5;
	level.round_timer_hud.alpha = 0;
	level.round_timer_hud.color = ( 1, 1, 1 );

	level.total_time = 0;

	for(;;)
	{
		start_time = int(getTime() / 1000);
		level waittill( "end_of_round" );
		if(getDvarInt( "round_timer" ) == 0)
    	{
        	if(level.round_timer_hud.alpha != 0)
        	{
            	level.round_timer_hud.alpha = 0;
        	}
    	}
    	else if(getDvarInt( "round_timer" ) == 1)
    	{
        	end_time = int(getTime() / 1000);

			round_time = end_time - start_time - 0.1;
			level thread display_times(level.round_timer_hud, round_time);
    	}
	}
}

function display_times( hud, time )
{
	level endon("start_of_round");

	hud_fade(hud, 1, 0.15);
	for(i = 0; i < 12; i++)
	{
		hud setTimer(time);
		wait 0.5;
	}
	hud_fade(hud, 0, 0.15);
}

function hud_fade( hud, alpha, duration )
{
	hud fadeOverTime(duration);
	hud.alpha = alpha;
}
function new_zombie_speed()
{
    //Health  
    zombie_utility::set_zombie_var( "zombie_health_increase",             150,    false);    //    cumulatively add this to the zombies&#39; starting health each round (up to round 10)
    zombie_utility::set_zombie_var( "zombie_health_increase_multiplier",        0.1,     true );    //    after round 10 multiply the zombies&#39; starting health by this amount
    zombie_utility::set_zombie_var( "zombie_health_start",                 150,    false);    //    starting health of a zombie at round 1
    zombie_utility::set_zombie_var( "zombie_spawn_delay",                    0,    true );    // Time to wait between spawning zombies.  This is modified based on the round number.
    zombie_utility::set_zombie_var( "zombie_new_runner_interval",              35,    false);    //    Interval between changing walkers who are too far away into runners

    zombie_utility::set_zombie_var( "zombie_max_ai",                 24,        false );    //    CAP IS 64
    zombie_utility::set_zombie_var( "zombie_ai_per_player",             6,        false     );    //    additional zombie modifier for each player in the game
    zombie_utility::set_zombie_var( "below_world_check",                 -1000 );                    //    Check height to see if a zombie has fallen through the world.

    // Round  
    zombie_utility::set_zombie_var( "spectators_respawn",                 true );        // Respawn in the spectators in between rounds
    zombie_utility::set_zombie_var( "zombie_use_failsafe",                 true );        // Will slowly kill zombies who are stuck

    //Speed
    zombie_utility::set_zombie_var( "zombie_move_speed_multiplier",       99,   false );    //  Multiply by the round number to give the base speed value.  0-40 = walk, 41-70 = run, 71+ = sprint
    zombie_utility::set_zombie_var( "zombie_move_speed_multiplier_easy",  99,   false );    //  CAP IS 99
    level.zombie_move_speed         = level.round_number * level.zombie_vars["zombie_move_speed_multiplier"];
}

function _INIT_ZCOUNTER()
{
	ZombieCounterHuds = [];
	ZombieCounterHuds["LastZombieText"] 	= "Remaining:";
	ZombieCounterHuds["ZombieText"]			= "Remaining:";
	ZombieCounterHuds["LastDogText"]		= "Remaining:";
	ZombieCounterHuds["DogText"]			= "Remaining:";
	ZombieCounterHuds["DefaultColor"]		= (1,1,1);
	ZombieCounterHuds["HighlightColor"]		= (1, 0.55, 0);
	ZombieCounterHuds["FontScale"]			= 1.5;
	ZombieCounterHuds["DisplayType"]		= 0; // 0 = Shows Total Zombies and Counts down, 1 = Shows Currently spawned zombie count

	ZombieCounterHuds["counter"] = createNewHudElement("left", "top", 57, 2, 1, 1.5);
	ZombieCounterHuds["text"] = createNewHudElement("left", "top", 3, 2, 1, 1.5);

	ZombieCounterHuds["counter"] hudRGBA(ZombieCounterHuds["DefaultColor"], 0);
	ZombieCounterHuds["text"] hudRGBA(ZombieCounterHuds["DefaultColor"], 0);

	level thread _THINK_ZCOUNTER(ZombieCounterHuds);
}

function _THINK_ZCOUNTER(hudArray)
{
	level endon("end_game");
	for(;;)
	{
		level waittill("start_of_round");
		level _ROUND_COUNTER(hudArray);
		hudArray["counter"] SetValue(0);
		hudArray["text"] thread hudMoveTo((3, 2, 0), 4);
		
		hudArray["counter"] thread hudRGBA(hudArray["DefaultColor"], 0, 1);
	}
}

function _ROUND_COUNTER(hudArray)
{
	level endon("end_of_round");
	lastCount = 0;
	numberToString = "";

	hudArray["counter"] thread hudRGBA(hudArray["DefaultColor"], 1.0, 1);
	hudArray["text"] thread hudRGBA(hudArray["DefaultColor"], 1.0, 1);
	hudArray["text"] SetText(hudArray["ZombieText"]);
	if(level flag::get("dog_round"))
		hudArray["text"] SetText(hudArray["DogText"]);

	for(;;)
	{
		zm_count = (zombie_utility::get_current_zombie_count() + level.zombie_total);
		if(hudArray["DisplayType"] == 1) zm_count = zombie_utility::get_current_zombie_count();
		if(zm_count == 0) {wait(1); continue;}
		hudArray["counter"] SetValue(zm_count);
		wait(0.1);
	}
}

function createNewHudElement(xAlign, yAlign, posX, posY, foreground, fontScale)
{
	hud = newHudElem();
	hud.horzAlign = xAlign; hud.alignX = xAlign;
	hud.vertAlign = yAlign; hug.alignY = yAlign;
	hud.x = posX; hud.y = posY;
	hud.foreground = foreground;
	hud.fontscale = fontScale;
	return hud;
}

function hudRGBA(newColor, newAlpha, fadeTime)
{
	if(isDefined(fadeTime))
		self FadeOverTime(fadeTime);

	self.color = newColor;
	self.alpha = newAlpha;
}

function hudFontScale(newScale, fadeTime)
{
	if(isDefined(fadeTime))
		self ChangeFontScaleOverTime(fadeTime);

	self.fontscale = newScale;
}

function hudMoveTo(posVector, fadeTime) // Just because MoveOverTime doesn't always work as wanted
{
	initTime = GetTime();
	hudX = self.x;
	hudY = self.y;
	hudVector = (hudX, hudY, 0);
	while(hudVector != posVector)
	{
		time = GetTime();
		hudVector = VectorLerp(hudVector, posVector, (time - initTime) / (fadeTime * 1000));
		self.x = hudVector[0];
		self.y = hudVector[1];
		wait(0.0001);
	}
}