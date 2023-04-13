#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\spawner_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_healthbar;
#insert scripts\shared\shared.gsh;
#insert scripts\zm\_zm_utility.gsh;
#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\ugxmods_timedgp;
#using scripts\zm\_zm_bloodsplatter;
#using scripts\zm\_zm_zonemgr;
#using scripts\shared\visionset_mgr_shared;


//#using scripts\Sphynx\commands;
//*****************************************************************************
// MAIN - This is my first project using GSC if you find anyway to improve this code contact me on discord at Zach#5262
//*****************************************************************************

function init()
{
    //dvars
  thread point();
  thread change_round();
  thread Zombiemovement();
  thread spawndelay();
  thread zombiecap();
  thread userhealth();
  thread fog();
  thread Perk();
  thread ugxmods_timedgp::timed();
  level thread disable_cheats();
  //level thread Rezoned();

  SetDvar("r_dof_enable", "0");
  SetDvar("r_lodbiasrigid", "-1000");
  //level.giveCustomLoadout =&giveCustomLoadout; // Initiates the custom loadout (Spawn weapons, as certain maps use a certian function that you can't replace without a loadout)
  level flag::wait_till( "initial_blackscreen_passed" );
  //thread Debug();
  //thread MapCheck();
  //level.player_starting_points = 500;
  level.perk_purchase_limit = 5;
  level.pack_a_punch_camo_index = 134;
  level.pack_a_punch_camo_index_number_variants = 1;
  level.func_get_zombie_spawn_delay = &spawn_delay;
  thread spawn_delay();
  level.zombie_total = get_zombie_count_for_round( level.round_number, level.players.size );
  thread get_zombie_count_for_round();
}

function disable_cheats()
{
    ModVar( "god", 0 );
    ModVar( "demigod", 0 );
    ModVar( "noclip", 0 );
    ModVar( "ufo", 0 ); 
    ModVar( "give", 0 );
    ModVar( "notarget", 0 );
}

function Debug()
{
 // This is Debug stuff, you can comment this function and its thread call if wanted	
 wait 0.5;
 level flag::wait_till( "initial_blackscreen_passed" );
 IPrintLnBold("^1DEBUG: GSC Loading Successful");
}

function MapCheck()
{
 //Gets the map name for any functions that need it
 mapname = GetDvarString("ui_mapname"); // Cut and Paste this line to any function that requires a to know the current map
 // when checking the map name, do a function like if(mapname == "zm_mapname")
 wait 0.5;
 level flag::wait_till( "initial_blackscreen_passed" );
 IPrintLnBold("^1DEBUG: mapname = " + mapname); // If you do put the mapcheck line in a seperate function, make sure to copy and paste this line too!
}

function giveCustomLoadout( takeAllWeapons )
{
   level.weaponNameToGivePlayer = "ray_gun"; //Change smg_fastfire to the weapon you want to start with
   self GiveWeapon( level.weaponBaseMelee ); //This gives the player the ability to melee
    self GiveWeapon( GetWeapon(level.weaponNameToGivePlayer) ); //Gives the player the weapon
   self SwitchToWeapon(GetWeapon(level.weaponNameToGivePlayer) ); //Switches to the weapon the server gave the player
    // Thanks to alexbegt and IamMicheal AND InsaneMembrane on BO3 MT discord for helping with this function!
}

function spawn_delay(n_round)
{
    thread sprinters();
    n_multiplier = 0.95;
    n_delay = 1;

    for(i = 1; i < n_round; i++)
    {
        n_delay *= n_multiplier;
        
        if(n_delay <= 0.08)
        {
            n_delay = 0.08;
            break;            
        }
    }

    if(n_round >= 50)
    {
        n_delay = 0.08;
    }
    
    return n_delay;
}

function sprinters()
{
    if( level.round_number == 1 )
    {
        level.zombie_move_speed = 1;
    }
    else
     level.zombie_move_speed = level.round_number * 8;      
}

function get_zombie_count_for_round( n_round, n_player_count )
{
    start_at_round = 55;
    healthcap = 40;
while(1)
    {
    level waittill("zombie_total_set");

    max = level.zombie_vars["zombie_max_ai"];

    multiplier = level.round_number / 5;
    if( multiplier < 1 )
    {
        multiplier = 1;
    }
        // After round 10, exponentially have more AI attack the player
   if( level.round_number >= 10 )
    {
        multiplier *= level.round_number * 0.15;
         max += int( ( 0.5 * 6 ) * multiplier );
        level.zombie_total = max;
    }


    if( level.round_number < 6 )
    {
        max_num = max;

    if( level.round_number < 2 )
    {
        max = int( max_num * 0.25 );
        max = max - 1;
    }
    else if( level.round_number < 3 )
    {
        max = int( max_num * 0.3 );
    }
    else if( level.round_number < 4 )
    {
        max = int( max_num * 0.5 );
    }
    else if( level.round_number < 5 )
    {
        max = int( max_num * 0.7 );
        max = max + 1;
    }
    else if( level.round_number < 6 )
    {
        max = int( max_num * 0.9 );
        max = max + 2;
    }
    }

    if ( level.round_number >= healthcap )
    {
        level.zombie_health = 18151;
        //IPrintLnBold("healthcap");
    }

    if (level.round_number % 2 == 1)
    {
        if (level.round_number >= 69)       
        {
            level.zombie_health = 150;
        }
    }

    if( GetPlayers().size == 1 && level.round_number > 5)
    {
        if(level.round_number < 10)
        {
         max = max - 1;
         max += int( ( 0.5 * 6 ) * multiplier );
        }
        
        level.zombie_total = max;
    }

     if( level.round_number >= start_at_round )
    {
        level.zombie_total = 296;
    }

     
     
}
}

//DVARs

function change_round()
{

    amount = 0;
    while(1)
    {
        if(GetDvarInt("change_round") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            thread goto_round( GetDvarInt("change_round") );

            IPrintLnBold("Set round to: " + GetDvarInt("change_round"));

            SetDvar("change_round", 0);
        } 
        WAIT_SERVER_FRAME;
    }

}

function goto_round(round_number = undefined)
{
    if(!isdefined(round_number))
        round_number = zm::get_round_number();
    if(round_number == zm::get_round_number())
        return;
    if(round_number < 0)
        return;

    // kill_round by default only exists in debug mode
    /#
    level notify("kill_round");
    #/
    // level notify("restart_round");
    level notify("end_of_round");
    level.zombie_total = 0;
    zm::set_round_number(round_number);
    round_number = zm::get_round_number(); // get the clamped round number (max 255)

    
    SetRoundsPlayed(round_number);

    foreach(zombie in level.zombie_total)
    {
        zombie Kill();
    }

    if(level.gamedifficulty == 0)
        level.zombie_move_speed = round_number * level.zombie_vars["zombie_move_speed_multiplier_easy"];
    else
        level.zombie_move_speed = round_number * level.zombie_vars["zombie_move_speed_multiplier"];

    level.zombie_vars["zombie_spawn_delay"] = [[level.func_get_zombie_spawn_delay]](round_number);

    level.sndGotoRoundOccurred = true;
    level waittill("between_round_over");
}

function Zombiemovement()
{

    amount = 0;
    while(1)
    {
        if(GetDvarInt("speed") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            thread zombiesmovespeed( GetDvarInt("speed"));

            //IPrintLnBold("Set speed to: " + GetDvarInt("sprint"));
        } 
        WAIT_SERVER_FRAME;
    }

}

function zombiesmovespeed(speed)
{
    if(level.gamedifficulty == 0)
        level.zombie_move_speed = level.round_number * speed;
    else
        level.zombie_move_speed = level.round_number * speed;
}

function spawndelay()
{
  while(1)
  {
      amount = 0;
        if(GetDvarInt("delay") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            level.zombie_vars["zombie_spawn_delay"] = 0;

            //IPrintLnBold("Set speed to: " + GetDvarInt("sprint"));
        } 
        WAIT_SERVER_FRAME;
  }
}

function getdelay(delay)
{
    level.zombie_vars["zombie_spawn_delay"] = delay;
}

function zombiecap()
{
  while(1)
  {
      amount = 0;
        if(GetDvarInt("zcap") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            thread zcapped( GetDvarInt("zcap"));

            //IPrintLnBold("Set speed to: " + GetDvarInt("sprint"));
        } 
        WAIT_SERVER_FRAME;
  }
}

function zcapped(zcapp)
{
    if (zcapp < 65 && zcapp > 0)
    {
        level.zombie_ai_limit = zcapp;
        level.zombie_actor_limit = zcapp + 7;         
    }   

    if (zcapp > 64 && zcapp < 1)
    {
        level.zombie_ai_limit = 64;
        level.zombie_actor_limit = 64 + 7;
    }
}   


function userhealth()
{
  while(1)
  {
      amount = 0;
        if(GetDvarInt("health") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            level thread player_health( GetDvarInt("health"));

            //IPrintLnBold("Set healyj to: " + GetDvarInt("health"));
        } 
        WAIT_SERVER_FRAME;
  }
}

function player_health(health)
{
  if (health == 1)
   {
        level.zombie_vars["player_base_health"] = 33;           // 4 hit = 133, 3 hit = 100, 2 hit = 66, 1 hit = 33 
   } 

  if (health == 2)
   {
     level.zombie_vars["player_base_health"] = 66;    // 4 hit = 133, 3 hit = 100, 2 hit = 66, 1 hit = 33 
   } 
}

//level.player_starting_points = 500;

function point()
{
  while(1)
  {
      amount = 0;
        if(GetDvarInt("points") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            level.player_starting_points = GetDvarInt("points");

            //IPrintLnBold("Set speed to: " + GetDvarInt("sprint"));
        } 
        WAIT_SERVER_FRAME;
  }
}

function fog()
{
  while(1)
  {
      amount = 0;
        if(GetDvarInt("fog") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            level thread r_fog( GetDvarInt("fog"));

            //IPrintLnBold("Set speed to: " + GetDvarInt("sprint"));
        } 
        WAIT_SERVER_FRAME;
  }
}

function r_fog(rfog)
{
 SetDvar("r_fog", "0");
}  
    
function Perk()
{
  while(1)
  {
      amount = 0;
        if(GetDvarInt("perk") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            level thread limit( GetDvarInt("perk"));

            //IPrintLnBold("Set speed to: " + GetDvarInt("sprint"));
        } 
        WAIT_SERVER_FRAME;
  }
}

function limit(N)
{
 level.perk_purchase_limit = N;
}  

function Rezoned()
{
    if (level.script == "zm_theater")
    {
        level.zone_manager_init_func = &theater_zone;
    }
}
function theater_zone()
{
    level flag::init("always_on");
    level flag::set("always_on");
    zm_zonemgr::add_adjacent_zone("foyer_zone", "foyer2_zone", "always_on");
    zm_zonemgr::add_adjacent_zone("foyer_zone", "vip_zone", "magic_box_foyer1",true);
    zm_zonemgr::add_adjacent_zone("foyer2_zone", "crematorium_zone", "magic_box_crematorium1",true);
    zm_zonemgr::add_adjacent_zone("foyer_zone", "crematorium_zone", "magic_box_crematorium1",true);
    zm_zonemgr::add_adjacent_zone("vip_zone", "dining_zone", "vip_to_dining");
    zm_zonemgr::add_adjacent_zone("crematorium_zone", "alleyway_zone", "magic_box_alleyway1");
    zm_zonemgr::add_adjacent_zone("dining_zone", "dressing_zone", "dining_to_dressing");
    zm_zonemgr::add_adjacent_zone("dressing_zone", "stage_zone", "magic_box_dressing1");
    zm_zonemgr::add_adjacent_zone("stage_zone", "west_balcony_zone", "magic_box_west_balcony2");
    zm_zonemgr::add_adjacent_zone("theater_zone", "foyer2_zone", "power_on");
    zm_zonemgr::add_adjacent_zone("theater_zone", "stage_zone", "power_on");
    zm_zonemgr::add_adjacent_zone("west_balcony_zone", "alleyway_zone", "magic_box_west_balcony1");
}