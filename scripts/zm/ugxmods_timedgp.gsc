/*
	Created by Andy King (treminaor) for UGX-Mods.com. © UGX-Mods 2016
	Please include credit if you use this script and do not distribute edited versions of it without my permission.
	Contact: twitter.com/treminaor
	Instructions: https://confluence.ugx-mods.com/display/UGXMODS/BO3+%7C+Adding+Timed+Gameplay+to+Zombiemode

	Version: 1.0 10/13/2016 8:59PM
*/

#using scripts\shared\flag_shared;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_utility;

#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\shared.gsh;

//default round_wait func but without a check for zero zombies alive, which allows for continuous spawning
function round_wait_override()
{
	level endon("restart_round");
	level endon( "kill_round" );

	wait( 1 );

	while( 1 )
	{
		should_wait = ( level.zombie_total > 0 || level.intermission );	
		if( !should_wait )
		{
			return;
		}			
			
		if( level flag::get( "end_round_wait" ) )
		{
			return;
		}
		wait( 1.0 );
	}
}

function timed_gameplay() //If you want to call this yourself based on some user input or whatever, remove 'autoexec' and call this function externally from somewhere else.
{
	level.round_wait_func = &round_wait_override; //this has to happen before zm::round_start() runs!

	wait 0.5; 

	level.next_dog_round = 9999; //cheap way to disable dogs after zm_usermap::main() runs.
	level.zombie_vars["zombie_between_round_time"] = 0; //remove the delay at the end of each round 
	level.zombie_round_start_delay = 0; //remove the delay before zombies start to spawn

	level.ugxm_settings = [];
	if(isDefined(level.tgTimer)) level.tgTimer Destroy();
	level.tgTimer = NewHudElem();

	level.isTimedGameplay = true;
}


function timed()
{
  while(1)
  {
      amount = 0;
        if(GetDvarInt("timed") != amount)
        {
            if(isdefined("between_round_over"))
            {
                wait 0.05;
            }

            thread timed_gameplay();

            //IPrintLnBold("Set speed to: " + GetDvarInt("sprint"));
        } 
        WAIT_SERVER_FRAME;
  }
}