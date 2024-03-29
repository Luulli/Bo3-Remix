#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\archetype_shared\archetype_shared.gsh;
#using scripts\shared\array_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\ai\zombie_shared;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\systems\gib;

#using scripts\shared\ai\systems\behavior_tree_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\zombie.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;

#using scripts\codescripts\struct;

#namespace zombie_utility;
	
function zombieSpawnSetup()
{
	self.zombie_move_speed = "walk";

	if ( !isdefined( self.zombie_arms_position ) )
	{
		if(randomint( 2 ) == 0)
			self.zombie_arms_position = "up";
		else
			self.zombie_arms_position = "down";
	}

	self.missingLegs = false;
	self setAvoidanceMask( "avoid none" );	
	self PushActors( true );

	clientfield::set( ZOMBIE_CLIENTFIELD, true );

	self.ignorePathEnemyFightDist = true;	// prevent sight tracing in Actor_ShouldFaceMotion
}

function get_closest_valid_player( origin, ignore_player, ignore_laststand_players = false )
{
	PixBeginEvent( "get_closest_valid_player" );
	
	valid_player_found = false; 
	
	targets = GetPlayers();

	if( isdefined( level.closest_player_targets_override ) )
	{
		targets = [[ level.closest_player_targets_override ]]();
	}
	
	if( IsDefined( ignore_player ) )
	{
		for(i = 0; i < ignore_player.size; i++ )
		{
			ArrayRemoveValue( targets, ignore_player[i] );
		}
	}

	done = true;	
	while ( targets.size && !done )
	{
		done = true;
		for(i = 0; i < targets.size; i++ )
		{
			target = targets[i];
			if( !is_player_valid( target, true, ignore_laststand_players ) )
			{
				ArrayRemoveValue( targets, target ); 
				done = false;
				break;
			}
		}
	}
	
	if( targets.size == 0 )
	{
		pixendevent();
		return undefined; 
	}
	
	if( IsDefined( self.closest_player_override ) )
	{
		target = [[ self.closest_player_override ]]( origin, targets );
	}
	else if( IsDefined( level.closest_player_override ) )
	{
		target = [[ level.closest_player_override ]]( origin, targets );
	} 

	if( IsDefined( target ) )
	{
		pixendevent();
		return target;
	}
		
	sortedPotentialTargets = ArraySortClosest( targets, self.origin );
		
	while(sortedPotentialTargets.size)
	{
		if( is_player_valid( sortedPotentialTargets[0], true , ignore_laststand_players) )
		{
			pixendevent();
			return sortedPotentialTargets[0];
		}
	
		ArrayRemoveValue( sortedPotentialTargets, sortedPotentialTargets[0] );
	}
		
	pixendevent();		
	return undefined; 		
}

function is_player_valid( player, checkIgnoreMeFlag, ignore_laststand_players )
{
	if( !IsDefined( player ) ) 
	{
		return false; 
	}

	if( !IsAlive( player ) )
	{
		return false; 
	} 

	if( !IsPlayer( player ) )
	{
		return false;
	}

	if( IsDefined(player.is_zombie) && player.is_zombie == true )
	{
		return false; 
	}

	if( player.sessionstate == "spectator" )
	{
		return false; 
	}

	if( player.sessionstate == "intermission" )
	{
		return false; 
	}
	
	if( IS_TRUE(player.intermission) )
	{
		return false;
	}
	
	if(!IS_TRUE(ignore_laststand_players))
	{
		if(  player laststand::player_is_in_laststand() )
		{
			return false; 
		}
	}

	if ( player IsNoTarget() )
	{
		return false;
	}
	
	//We only want to check this from the zombie attack script
	if( IS_TRUE(checkIgnoreMeFlag) && player.ignoreme )
	{
		return false;
	}
	
	//for additional level specific checks
	if( IsDefined( level.is_player_valid_override ) )
	{
		return [[ level.is_player_valid_override ]]( player );
	}
	
	return true; 
}


function append_missing_legs_suffix( animstate )
{
	if ( self.missingLegs && self HasAnimStateFromASD( animstate + "_crawl" ) )
	{
		return animstate + "_crawl";
	}

	return animstate;
}


// Every script calls initAnimTree to ensure a clean, fresh, known animtree state.  
// ClearAnim should never be called directly, and this should never occur other than
// at the start of an animscript
// This function now also does any initialization for the scripts that needs to happen 
// at the beginning of every main script.
function initAnimTree(animscript)
{
	if ( animscript != "pain" && animscript != "death" )
	{
		self.a.special = "none";
	}
	
	assert( IsDefined( animscript ), "Animscript not specified in initAnimTree" );
	self.a.script = animscript;
}

// UpdateAnimPose does housekeeping at the start of every script's main function. 
function UpdateAnimPose()
{
	assert( self.a.movement=="stop" || self.a.movement=="walk" || self.a.movement=="run", "UpdateAnimPose "+self.a.pose+" "+self.a.movement );
	
	self.desired_anim_pose = undefined;
}

function initialize( animscript )
{
	if ( IsDefined( self.longDeathStarting ) )
	{
		if ( animscript != "pain" && animscript != "death" )
		{
			// we probably just came out of an animcustom.
			// just die, it's not safe to do anything else
			self DoDamage( self.health + 100, self.origin );
		}
		if ( animscript != "pain" )
		{
			self.longDeathStarting = undefined;
			self notify( "kill_long_death" );
		}
	}
	if ( IsDefined( self.a.mayOnlyDie ) && animscript != "death" )
	{
		// we probably just came out of an animcustom.
		// just die, it's not safe to do anything else
		self DoDamage( self.health + 100, self.origin );
	}

	// scripts can define this to allow cleanup before moving on
	if ( IsDefined( self.a.postScriptFunc ) )
	{
		scriptFunc = self.a.postScriptFunc;
		self.a.postScriptFunc = undefined;

		[[scriptFunc]]( animscript );
	}

	if ( animscript != "death" )
	{
		self.a.nodeath = false;
	}
	
	self.isHoldingGrenade = undefined;

	self.coverNode = undefined;
	self.changingCoverPos = false;
	self.a.scriptStartTime = GetTime();
	
	self.a.atConcealmentNode = false;
	if ( IsDefined( self.node ) && (self.node.type == "Conceal Crouch" || self.node.type == "Conceal Stand") )
	{
		self.a.atConcealmentNode = true;
	}
	
	initAnimTree( animscript );

	UpdateAnimPose();
}

function GetNodeYawToOrigin(pos)
{
	if (IsDefined (self.node))
	{
		yaw = self.node.angles[1] - GetYaw(pos);
	}
	else
	{
		yaw = self.angles[1] - GetYaw(pos);
	}
	
	yaw = AngleClamp180( yaw );
	return yaw;
}

function GetNodeYawToEnemy()
{
	pos = undefined;
	if ( isValidEnemy( self.enemy ) )
	{
		pos = self.enemy.origin;
	}
	else
	{
		if (IsDefined (self.node))
		{
			forward = AnglesToForward(self.node.angles);
		}
		else
		{
			forward = AnglesToForward(self.angles);
		}

		forward = VectorScale (forward, 150);
		pos = self.origin + forward;
	}
	
	if (IsDefined (self.node))
	{
		yaw = self.node.angles[1] - GetYaw(pos);
	}
	else
	{
		yaw = self.angles[1] - GetYaw(pos);
	}

	yaw = AngleClamp180( yaw );
	return yaw;
}

function GetCoverNodeYawToEnemy()
{
	pos = undefined;
	if ( isValidEnemy( self.enemy ) )
	{
		pos = self.enemy.origin;
	}
	else
	{
		forward = AnglesToForward(self.coverNode.angles + self.animarray["angle_step_out"][self.a.cornerMode]);
		forward = VectorScale (forward, 150);
		pos = self.origin + forward;
	}
	
	yaw = self.CoverNode.angles[1] + self.animarray["angle_step_out"][self.a.cornerMode] - GetYaw(pos);
	yaw = AngleClamp180( yaw );
	return yaw;
}

function GetYawToSpot(spot)
{
	pos = spot;
	yaw = self.angles[1] - GetYaw(pos);
	yaw = AngleClamp180( yaw );
	return yaw;
}
// warning! returns (my yaw - yaw to enemy) instead of (yaw to enemy - my yaw)
function GetYawToEnemy()
{
	pos = undefined;
	if ( isValidEnemy( self.enemy ) )
	{
		pos = self.enemy.origin;
	}
	else
	{
		forward = AnglesToForward(self.angles);
		forward = VectorScale (forward, 150);
		pos = self.origin + forward;
	}
	
	yaw = self.angles[1] - GetYaw(pos);
	yaw = AngleClamp180( yaw );
	return yaw;
}

function GetYaw(org)
{
	angles = VectorToAngles(org-self.origin);
	return angles[1];
}

function GetYaw2d(org)
{
	angles = VectorToAngles((org[0], org[1], 0)-(self.origin[0], self.origin[1], 0));
	return angles[1];
}

// 0 if I'm facing my enemy, 90 if I'm side on, 180 if I'm facing away.
function AbsYawToEnemy()
{
	assert( isValidEnemy( self.enemy ) );
	
	yaw = self.angles[1] - GetYaw(self.enemy.origin);
	yaw = AngleClamp180( yaw );
	
	if (yaw < 0)
	{
		yaw = -1 * yaw;
	}

	return yaw;
}

// 0 if I'm facing my enemy, 90 if I'm side on, 180 if I'm facing away.
function AbsYawToEnemy2d()
{
	assert( isValidEnemy( self.enemy ) );

	yaw = self.angles[1] - GetYaw2d(self.enemy.origin);
	yaw = AngleClamp180( yaw );

	if (yaw < 0)
	{
		yaw = -1 * yaw;
	}

	return yaw;
}

// 0 if I'm facing my enemy, 90 if I'm side on, 180 if I'm facing away.
function AbsYawToOrigin(org)
{
	yaw = self.angles[1] - GetYaw(org);
	yaw = AngleClamp180( yaw );

	if (yaw < 0)
	{
		yaw = -1 * yaw;
	}

	return yaw;
}

function AbsYawToAngles(angles)
{
	yaw = self.angles[1] - angles;
	yaw = AngleClamp180( yaw );

	if (yaw < 0)
	{
		yaw = -1 * yaw;
	}

	return yaw;
}

function GetYawFromOrigin(org, start)
{
	angles = VectorToAngles(org-start);
	return angles[1];
}

function GetYawToTag(tag, org)
{
	yaw = self GetTagAngles( tag )[1] - GetYawFromOrigin(org, self GetTagOrigin(tag));
	yaw = AngleClamp180( yaw );
	return yaw;
}

function GetYawToOrigin(org)
{
	yaw = self.angles[1] - GetYaw(org);
	yaw = AngleClamp180( yaw );
	return yaw;
}

function GetEyeYawToOrigin(org)
{
	yaw = self GetTagAngles("TAG_EYE")[1] - GetYaw(org);
	yaw = AngleClamp180( yaw );
	return yaw;
}

function GetCoverNodeYawToOrigin(org)
{
	yaw = self.coverNode.angles[1] + self.animarray["angle_step_out"][self.a.cornerMode] - GetYaw(org);
	yaw = AngleClamp180( yaw );
	return yaw;
}


function isStanceAllowedWrapper( stance )
{
	if ( IsDefined( self.coverNode ) )
	{
		return self.coverNode doesNodeAllowStance( stance );
	}

	return self IsStanceAllowed( stance );
}


function GetClaimedNode()
{
	myNode = self.node;
	if ( IsDefined(myNode) && (self nearNode(myNode) || (IsDefined( self.coverNode ) && myNode == self.coverNode)) )
	{
		return myNode;
	}

	return undefined;
}

function GetNodeType()
{
	myNode = GetClaimedNode();
	if (IsDefined(myNode))
	{
		return myNode.type;
	}

	return "none";
}

function GetNodeDirection()
{
	myNode = GetClaimedNode();
	if (IsDefined(myNode))
	{
		//thread [[anim.println]]("GetNodeDirection found node, returned: "+myNode.angles[1]);#/
		return myNode.angles[1];
	}
	//thread [[anim.println]]("GetNodeDirection didn't find node, returned: "+self.desiredAngle);#/
	return self.desiredAngle;
}

function GetNodeForward()
{
	myNode = GetClaimedNode();
	if (IsDefined(myNode))
	{
		return AnglesToForward ( myNode.angles );
	}

	return AnglesToForward( self.angles );
}

function GetNodeOrigin()
{
	myNode = GetClaimedNode();
	if (IsDefined(myNode))
	{
		return myNode.origin;
	}

	return self.origin;
}

function safemod(a,b)
{
	/*
	Here are some modulus results from in-game:
	10 % 3 = 1
	10 % -3 = 1
	-10 % 3 = -1
	-10 % -3 = -1
	however, we never want a negative result.
	*/
	result = int(a) % b;
	result += b;
	return result % b;
}

// Gives the result as an angle between 0 and 360
function AngleClamp( angle )
{
	angleFrac = angle / 360.0;
	angle = (angleFrac - floor( angleFrac )) * 360.0;
	return angle;
}

// Returns an array of 4 weights (2 of which are guaranteed to be 0), which should be applied to forward, 
// right, back and left animations to get the angle specified.
//           front
//        /----|----\
//       /    180    \
//      /\     |     /\
//     / -135  |  135  \
//     |     \ | /     |
// left|-90----+----90-|right
//     |     / | \     |
//     \  -45  |  45   /
//      \/     |     \/
//       \     0     / 
//        \----|----/
//           back

function QuadrantAnimWeights( yaw )
{
	// ALEXP 6/26/09: I don't understand why they'd want trig interpolation between angles instead of linear
	//forwardWeight = cos( yaw );
	//leftWeight    = sin( yaw );

	forwardWeight	= (90 - abs(yaw)) / 90;
	leftWeight		= (90 - AbsAngleClamp180(abs(yaw-90))) / 90;

	result["front"]	= 0;
	result["right"]	= 0;
	result["back"]	= 0;
	result["left"]	= 0;
	
	if ( IsDefined( self.alwaysRunForward ) )
	{
		assert( self.alwaysRunForward ); // always set alwaysRunForward to either true or undefined.
		
		result["front"] = 1;
		return result;
	}

	useLeans = GetDvarInt( "ai_useLeanRunAnimations");

	if (forwardWeight > 0)
	{
		result["front"] = forwardWeight;
		
		if (leftWeight > 0)
		{
			result["left"] = leftWeight;
		}
		else
		{
			result["right"] = -1 * leftWeight;
		}
	}
	else if( useLeans )
	{
		result["back"] = -1 * forwardWeight;
		if (leftWeight > 0)
		{
			result["left"] = leftWeight;
		}
		else
		{
			result["right"] = -1 * leftWeight;
		}
	}
	else //cod4 back strafe
	{
		// if moving backwards, don't blend.
		// it looks horrible because the feet cycle in the opposite direction.
		// either way, feet slide, but this looks better.
		backWeight = -1 * forwardWeight;
		if ( leftWeight > backWeight )
		{
			result["left"] = 1;
		}
		else if ( leftWeight < forwardWeight )
		{
			result["right"] = 1;
		}
		else
		{
			result["back"] = 1;
		}
	}


	return result;
}

function getQuadrant(angle)
{
	angle = AngleClamp(angle);

	if (angle<45 || angle>315)
	{
		quadrant = "front";
	}
	else if (angle<135)
	{
		quadrant = "left";
	}
	else if (angle<225)
	{
		quadrant = "back";
	}
	else
	{
		quadrant = "right";
	}
	return quadrant;
}


// Checks to see if the input is equal to any of up to ten other inputs.
function IsInSet(input, set)
{
	for (i = set.size - 1; i >= 0; i--)
	{
		if (input == set[i])
		{
			return true;
		}
	}

	return false;
}

function NotifyAfterTime(notifyString, killmestring, time)
{
	self endon("death");
	self endon(killmestring);
	wait time;
	self notify (notifyString);
}

function drawStringTime(msg, org, color, timer)
{	
	/#
	maxtime = timer*20;
	for (i=0;i<maxtime;i++)
	{
		Print3d (org, msg, color, 1, 1);
		wait .05;
	}
	#/
}

function showLastEnemySightPos(string)
{
	/#
	self notify ("got known enemy2");
	self endon ("got known enemy2");
	self endon ("death");

	if ( !isValidEnemy( self.enemy ) )
	{
		return;
	}
		
	if (self.enemy.team == "allies")
	{
		color = (0.4, 0.7, 1);
	}
	else
	{
		color = (1, 0.7, 0.4);
	}
		
	while (1)
	{
		WAIT_SERVER_FRAME;
		
		if (!IsDefined (self.lastEnemySightPos))
		{
			continue;
		}
			
		Print3d (self.lastEnemySightPos, string, color, 1, 2.15);	// origin, text, RGB, alpha, scale
	}
	#/
}

function debugTimeout()
{
	wait(5);
	self notify ("timeout");
}

function debugPosInternal( org, string, size )
{
	/#
	self endon ("death");
	self notify ("stop debug " + org);
	self endon ("stop debug " + org);
	
	ent = SpawnStruct();
	ent thread debugTimeout();
	ent endon ("timeout");
	
	if (self.enemy.team == "allies")
	{
		color = (0.4, 0.7, 1);
	}
	else
	{
		color = (1, 0.7, 0.4);
	}
		
	while (1)
	{
		WAIT_SERVER_FRAME;
		Print3d (org, string, color, 1, size);	// origin, text, RGB, alpha, scale
	}
	#/
}

function debugPos( org, string )
{
	thread debugPosInternal( org, string, 2.15 );
}

function debugPosSize( org, string, size )
{
	thread debugPosInternal( org, string, size );
}

function showDebugProc(fromPoint, toPoint, color, printTime)
{
	/#
	self endon ("death");
//	self notify ("stop debugline " + self.export);
//	self endon ("stop debugline " + self.export);

	timer = printTime*20;
	for (i=0;i<timer;i+=1)
	{
		WAIT_SERVER_FRAME;
		line (fromPoint, toPoint, color);
	}
	#/
}

function showDebugLine( fromPoint, toPoint, color, printTime )
{
	self thread showDebugProc( fromPoint, toPoint +( 0, 0, -5 ), color, printTime );
}

function getNodeOffset(node)
{
	if ( IsDefined( node.offset ) )
	{
		return node.offset;
	}

	//(right offset, forward offset, vertical offset)
	// you can get an actor's current eye offset by setting scr_eyeoffset to his entnum.
	// this should be redone whenever animations change significantly.
	cover_left_crouch_offset = 	(-26, .4, 36);
	cover_left_stand_offset = 	(-32, 7, 63);
	cover_right_crouch_offset = (43.5, 11, 36);
	cover_right_stand_offset = 	(36, 8.3, 63);
	cover_crouch_offset = 		(3.5, -12.5, 45); // maybe we could account for the fact that in cover crouch he can stand if he needs to?
	cover_stand_offset = 		(-3.7, -22, 63);

	cornernode = false;
	nodeOffset = (0,0,0);
	
	right = AnglesToRight(node.angles);
	forward = AnglesToForward(node.angles);

	switch(node.type)
	{
	case "Cover Left":
	case "Cover Left Wide":
		if ( node isNodeDontStand() && !node isNodeDontCrouch() )
		{
			nodeOffset = calculateNodeOffset( right, forward, cover_left_crouch_offset );
		}
		else
		{
			nodeOffset = calculateNodeOffset( right, forward, cover_left_stand_offset );
		}
		break;

	case "Cover Right":
	case "Cover Right Wide":
		if ( node isNodeDontStand() && !node isNodeDontCrouch() )
		{
			nodeOffset = calculateNodeOffset( right, forward, cover_right_crouch_offset );
		}
		else
		{
			nodeOffset = calculateNodeOffset( right, forward, cover_right_stand_offset );
		}
		break;

	case "Cover Stand":
	case "Conceal Stand":
	case "Turret":
		nodeOffset = calculateNodeOffset( right, forward, cover_stand_offset );
		break;

	case "Cover Crouch":
	case "Cover Crouch Window":
	case "Conceal Crouch":
		nodeOffset = calculateNodeOffset( right, forward, cover_crouch_offset );
		break;
	}

	node.offset = nodeOffset;
	return node.offset;
}

function calculateNodeOffset( right, forward, baseoffset )
{
	return VectorScale( right, baseoffset[0] ) + VectorScale( forward, baseoffset[1] ) + (0, 0, baseoffset[2]);
}

function checkPitchVisibility( fromPoint, toPoint, atNode )
{
	// check vertical angle is within our aiming abilities
	
	pitch = AngleClamp180( VectorToAngles( toPoint - fromPoint )[0] );
	if ( abs( pitch ) > 45 )
	{
		if ( IsDefined( atNode ) && atNode.type != "Cover Crouch" && atNode.type != "Conceal Crouch" )
		{
			return false;
		}

		if ( pitch > 45 || pitch < anim.coverCrouchLeanPitch - 45 )
		{
			return false;
		}
	}
	return true;
}

function showLines(start, end, end2)
{
	/#
	for (;;)
	{
		line(start, end, (1,0,0), 1);
		WAIT_SERVER_FRAME;
		line(start, end2, (0,0,1), 1);
		WAIT_SERVER_FRAME;
	}
	#/
}

// Returns an animation from an array of animations with a corresponding array of weights.
function anim_array(animArray, animWeights)
{
	total_anims = animArray.size;
	idleanim = RandomInt(total_anims);
	
	assert (total_anims);
	assert (animArray.size == animWeights.size);
	
	if (total_anims == 1)
	{
		return animArray[0];
	}
		
	weights = 0;
	total_weight = 0;
	
	for (i = 0; i < total_anims; i++)
	{
		total_weight += animWeights[i];
	}
	
	anim_play = RandomFloat(total_weight);
	current_weight	= 0;
	
	for (i = 0; i < total_anims; i++)
	{
		current_weight += animWeights[i];
		if (anim_play >= current_weight)
		{
			continue;
		}

		idleanim = i;
		break;
	}
	
	return animArray[idleanim];
}		

function notForcedCover()
{
	return ((self.a.forced_cover == "none") || (self.a.forced_cover == "Show"));
} 

function forcedCover(msg)
{
	return IsDefined(self.a.forced_cover) && (self.a.forced_cover == msg);
} 

function print3dtime(timer, org, msg, color, alpha, scale)
{
	/#
	newtime = timer / 0.05;
	for (i=0;i<newtime;i++)
	{
		Print3d (org, msg, color, alpha, scale);
		WAIT_SERVER_FRAME;
	}
	#/
}

function print3drise (org, msg, color, alpha, scale)
{
	/#
	newtime = 5 / 0.05;
	up = 0;
	org = org;

	for (i=0;i<newtime;i++)
	{
		up+=0.5;
		Print3d (org + (0,0,up), msg, color, alpha, scale);
		WAIT_SERVER_FRAME;
	}
	#/
}

function crossproduct (vec1, vec2)
{
	return (vec1[0]*vec2[1] - vec1[1]*vec2[0] > 0);
}

function scriptChange()
{
	self.a.current_script = "none";
	self notify (anim.scriptChange);
}

function delayedScriptChange()
{
	WAIT_SERVER_FRAME;
	scriptChange();
}

function sawEnemyMove(timer)
{
	if (!IsDefined(timer))
	{
		timer = 500;
	}

	return (GetTime() - self.personalSightTime < timer);
}

function canThrowGrenade()
{
	if (!self.grenadeAmmo)
	{
		return false;
	}
	
	if (self.script_forceGrenade)
	{
		return true;
	}
		
	return (IsPlayer(self.enemy));
}

function random_weight (array)
{
	idleanim = RandomInt (array.size);
	if (array.size > 1)
	{
		anim_weight = 0;
		for (i=0;i<array.size;i++)
		{
			anim_weight += array[i];
		}
		
		anim_play = RandomFloat (anim_weight);
		
		anim_weight = 0;
		for (i=0;i<array.size;i++)
		{
			anim_weight += array[i];
			if (anim_play < anim_weight)
			{
				idleanim = i;
				break;
			}
		}
	}
	
	return idleanim;
}		

function setFootstepEffect(name, fx)
{
	assert(IsDefined(name), "Need to define the footstep surface type.");
	assert(IsDefined(fx), "Need to define the mud footstep effect.");

	if (!IsDefined(anim.optionalStepEffects))
	{
		anim.optionalStepEffects = [];
	}

	anim.optionalStepEffects[anim.optionalStepEffects.size] = name;
	level._effect["step_" + name] = fx;
	anim.optionalStepEffectFunction = &zombie_shared::playFootStepEffect;
}

function persistentDebugLine(start, end)
{
	/#
	self endon ("death");
	level notify ("newdebugline");
	level endon ("newdebugline");
	
	for (;;)
	{
		line (start,end, (0.3,1,0), 1);
		WAIT_SERVER_FRAME;
	}
	#/
}

function isNodeDontStand()
{
	return (self.spawnflags & 4) == 4;
}
function isNodeDontCrouch()
{
	return (self.spawnflags & 8) == 8;
}

function doesNodeAllowStance( stance )
{
	if ( stance == "stand" )
	{
		return !self isNodeDontStand();
	}
	else
	{
		Assert( stance == "crouch" );
		return !self isNodeDontCrouch();
	}
}

function animArray( animname ) /* string */ 
{
	//println( "playing anim: ", animname );

	assert( IsDefined(self.a.array) );

	/#
	if ( !IsDefined(self.a.array[animname]) )
	{
		dumpAnimArray();
		assert( IsDefined(self.a.array[animname]), "self.a.array[ \"" + animname + "\" ] is undefined" );
	}
	#/

	return self.a.array[animname];
}

function animArrayAnyExist( animname )
{
	assert( IsDefined( self.a.array ) );

	/#
	if ( !IsDefined(self.a.array[animname]) )
	{
		dumpAnimArray();
		assert( IsDefined(self.a.array[animname]), "self.a.array[ \"" + animname + "\" ] is undefined"  );
	}
	#/
	
	return self.a.array[animname].size > 0;
}

function animArrayPickRandom( animname )
{
	assert( IsDefined( self.a.array ) );

	/#
	if ( !IsDefined(self.a.array[animname]) )
	{
		dumpAnimArray();
		assert( IsDefined(self.a.array[animname]), "self.a.array[ \"" + animname + "\" ] is undefined"  );
	}
	#/

	assert( self.a.array[animname].size > 0 );
	
	if ( self.a.array[animname].size > 1 )
	{
		index = RandomInt( self.a.array[animname].size );
	}
	else
	{
		index = 0;
	}

	return self.a.array[animname][index];
}

/#
function dumpAnimArray()
{
	println("self.a.array:");
	keys = getArrayKeys( self.a.array );

	for ( i=0; i < keys.size; i++ )
	{
		if ( isarray( self.a.array[ keys[i] ] ) )
		{
			println( " array[ \"" + keys[i] + "\" ] = {array of size " + self.a.array[ keys[i] ].size + "}" );
		}
		else
		{
			println( " array[ \"" + keys[i] + "\" ] = ", self.a.array[ keys[i] ] );
		}
	}
}
#/

function getAnimEndPos( theanim )
{
	moveDelta = getMoveDelta( theanim, 0, 1, self );
	return self localToWorldCoords( moveDelta );
}

function isValidEnemy( enemy )
{
	if ( !IsDefined( enemy ) )
	{
		return false;
	}
	
	return true;
}


function damageLocationIsAny( a, b, c, d, e, f, g, h, i, j, k, ovr )
{
	/* possibile self.damageLocation's:
		"torso_upper"
		"torso_lower"
		"helmet"
		"head"
		"neck"
		"left_arm_upper"
		"left_arm_lower"
		"left_hand"
		"right_arm_upper"
		"right_arm_lower"
		"right_hand"
		"gun"
		"none"
		"left_leg_upper"
		"left_leg_lower"
		"left_foot"
		"right_leg_upper"
		"right_leg_lower"
		"right_foot"
	*/
	if(!isDefined(self.damageLocation))
		return false;
	
	if ( !IsDefined( a ) ) return false; if ( self.damageLocation == a ) return true;
	if ( !IsDefined( b ) ) return false; if ( self.damageLocation == b ) return true;
	if ( !IsDefined( c ) ) return false; if ( self.damageLocation == c ) return true;
	if ( !IsDefined( d ) ) return false; if ( self.damageLocation == d ) return true;
	if ( !IsDefined( e ) ) return false; if ( self.damageLocation == e ) return true;
	if ( !IsDefined( f ) ) return false; if ( self.damageLocation == f ) return true;
	if ( !IsDefined( g ) ) return false; if ( self.damageLocation == g ) return true;
	if( !IsDefined( h ) ) return false; if( self.damageLocation == h ) return true;
	if( !IsDefined( i ) ) return false; if( self.damageLocation == i ) return true;
	if( !IsDefined( j ) ) return false; if( self.damageLocation == j ) return true;
	if( !IsDefined( k ) ) return false; if( self.damageLocation == k ) return true;
	assert(!IsDefined(ovr));
	return false;
}

function ragdollDeath( moveAnim )
{
	self endon ( "killanimscript" );
	
	lastOrg = self.origin;
	moveVec = (0,0,0);

	for ( ;; )
	{
		WAIT_SERVER_FRAME;
		force = distance( self.origin, lastOrg );
		lastOrg = self.origin;

		if ( self.health == 1 )
		{
			self.a.nodeath = true;
			self startRagdoll();

			WAIT_SERVER_FRAME;
			physicsExplosionSphere( lastOrg, 600, 0, force * 0.1 );
			self notify ( "killanimscript" );
			return;
		}
	}
}

function isCQBWalking()
{
	return IsDefined( self.cqbwalking ) && self.cqbwalking;
}

function squared( value )
{
	return value * value;
}

function randomizeIdleSet()
{
	self.a.idleSet = RandomInt( 2 );
}

// meant to be used with any integer seed, for a small integer maximum (ideally one that divides anim.randomIntTableSize)
function getRandomIntFromSeed( intSeed, intMax )
{
	assert( intMax > 0 );

	index = intSeed % anim.randomIntTableSize;
	return anim.randomIntTable[ index ] % intMax;
}

// MikeD (1/24/2008): Added Banzai Feature.
function is_banzai()
{
	return IsDefined( self.banzai ) && self.banzai;
}

// SCRIPTER_MOD: JesseS (4/16/2008): HMG guys have their own anims
function is_heavy_machine_gun()
{
	return IsDefined( self.heavy_machine_gunner ) && self.heavy_machine_gunner;
}

function is_zombie()
{
	if (IsDefined(self.is_zombie) && self.is_zombie)
	{
		return true;
	}

	return false;
}


function is_civilian()
{
	if (IsDefined(self.is_civilian) && self.is_civilian)
	{
		return true;
	}

	return false;
}

function is_skeleton(skeleton)
{
	if ((skeleton == "base") && IsSubStr(get_skeleton(), "scaled"))
	{
		// Scaled skeletons should identify as "base" as well
		return true;
	}

	return (get_skeleton() == skeleton);
}

function get_skeleton()
{
	if (IsDefined(self.skeleton))
	{
		return self.skeleton;
	}
	else
	{
		return "base";
	}
}

function set_orient_mode( mode, val1 )
{
/#
	if ( level.dog_debug_orient == self getentnum() )
	{
		if ( IsDefined( val1 ) )
			println( "DOG:  Setting orient mode: " + mode + " " + val1 + " " + getTime() );
		else
			println( "DOG:  Setting orient mode: " + mode + " " + getTime() );
	}
#/
	
	if ( IsDefined( val1 ) )
		self OrientMode( mode, val1 );
	else
		self OrientMode( mode );
}

function debug_anim_print( text )
{
/#		
	if ( IsDefined( level.dog_debug_anims ) && level.dog_debug_anims  )
		println( text+ " " + getTime() );

	if ( IsDefined( level.dog_debug_anims_ent ) && level.dog_debug_anims_ent == self getentnum() )
		println( text+ " " + getTime() );
#/
}

function debug_turn_print( text, line )
{
/#		
	if ( IsDefined( level.dog_debug_turns ) && level.dog_debug_turns == self getentnum() )
	{
		duration = 200;
		currentYawColor = (1,1,1);
		lookaheadYawColor = (1,0,0);
		desiredYawColor = (1,1,0);
	
		currentYaw = AngleClamp180(self.angles[1]);
		desiredYaw = AngleClamp180(self.desiredangle);
		lookaheadDir = self.lookaheaddir;
		lookaheadAngles = vectortoangles(lookaheadDir);
		lookaheadYaw = AngleClamp180(lookaheadAngles[1]);
			println( text+ " " + getTime() + " cur: " + currentYaw + " look: " + lookaheadYaw + " desired: " + desiredYaw );
	}
#/
}

function debug_allow_combat()
{
/#
	return ( anim_get_dvar_int( "debug_dog_allow_combat", "1" ) );
#/

	return true;
}

function debug_allow_movement()
{
/#
	return ( anim_get_dvar_int( "debug_dog_allow_movement", "1" ) );
#/

	return true;
}

//--------------------------------------------------------------------------------------------------
//		FUNCTIONS MOVED TO SHARED UTILITY FROM CP (_ZM_UTILITY)
//--------------------------------------------------------------------------------------------------
function set_zombie_var( zvar, value, is_float = false, column = 1, is_team_based = false )
{
	DEFAULT(level.zombie_vars,[]);
	
	if ( is_team_based )
	{
		foreach( team in level.teams )
		{
			DEFAULT(level.zombie_vars[team],[]);
			level.zombie_vars[ team ][ zvar ] = value;
		}
	}
	else
	{
		level.zombie_vars[zvar] = value;
	}
	
	return value;
}

function spawn_zombie( spawner,target_name,spawn_point,round_number) 
{ 
	if( !IsDefined( spawner ) )
	{
	/#	println( "ZM >> spawn_zombie - NO SPAWNER DEFINED" );	#/
		return undefined; 
	}
	
	while ( GetFreeActorCount() < 1 )
	{
		WAIT_SERVER_FRAME;
	}

	spawner.script_moveoverride = true; 

	if( IS_TRUE(spawner.script_forcespawn )) 
	{  
		if(IS_BONUSZM)
			guy = spawner spawner::spawn( true );
		else if( IsActorSpawner( spawner ) && IsDefined( level.overrideZombieSpawn ) )
		{
			guy = [[level.overrideZombieSpawn]]();
		}
		else
		{
			guy = spawner SpawnFromSpawner( 0, true );
		}
		
		if( !zombie_spawn_failed( guy ) ) 
		{ 

			guy.spawn_time = GetTime();	//	Time at spawning

			if ( isdefined( level.giveExtraZombies ) )
			{
				guy [[level.giveExtraZombies]]();
			}
	
			guy EnableAimAssist();		
			
			if(IsDefined(round_number))
			{
				guy._starting_round_number = round_number;
			}
					
			//guy.type = "zombie";
			guy.team = level.zombie_team;
			if( IsActor( guy ) )
				guy ClearEntityOwner();
			level.zombieMeleePlayerCounter = 0;
	
			if( IsActor( guy ) )
				guy forceteleport( spawner.origin );
			
			
			guy show();
			
			spawner.count = 666; 

			if( IsDefined( target_name ) ) 
			{ 
				guy.targetname = target_name; 
			}
			
			if(IsDefined(spawn_point) && IsDefined(level.move_spawn_func))
			{
				guy thread [[level.move_spawn_func]](spawn_point);
			}	
			
			/#
				if( IsDefined( spawner.zm_variant_type ) )
				{
					guy.variant_type = spawner.zm_variant_type;
				}
			#/
			 
			return guy;  
		}
		else
		{
		/#	println( "ZM >> spawn_zombie - FAILED TO SPAWN A ZOMBIE FROM SPAWNER AT ", spawner.origin );	#/
			return undefined; 
		}				
	}
	else
	{
	/#	println( "ZM >> spawn_zombie - ZOMBIE SPAWNER MUST BE SET FORCESPAWN", spawner.origin );	#/
		return undefined; 
	}		 

	return undefined;  
}

/@
"Name: zombie_spawn_failed( <spawn> )"
"Summary: Checks to see if the spawned AI spawned correctly or had errors. Also waits until all spawn initialization is complete. Returns true or false."
"MandatoryArg: <spawn> : The actor that just spawned"
@/ 
function zombie_spawn_failed( spawn )
{
	if ( IsDefined(spawn) && IsAlive(spawn) )
	{
		if ( IsAlive(spawn) )
		{
			return false; 
		}
	}

	return true; 
}


//--------------------------------------------------------------------------------------------------
//		FUNCTIONS MOVED TO SHARED UTILITY FROM CP (_ZM_SPAWNER)
//--------------------------------------------------------------------------------------------------
function get_desired_origin()
{
	if( IsDefined( self.target ) )
	{
		ent = GetEnt( self.target, "targetname" );
		if( !IsDefined( ent ) )
		{
			ent = struct::get( self.target, "targetname" );
		}
	
		if( !IsDefined( ent ) )
		{
			ent = GetNode( self.target, "targetname" );
		}
	
		assert( IsDefined( ent ), "Cannot find the targeted ent/node/struct, \"" + self.target + "\" at " + self.origin );
	
		return ent.origin;
	}

	return undefined;
}

function hide_pop()
{
	self endon( "death" );
	
	self Ghost();
	
	wait( 0.5 );
	if ( IsDefined( self ) )
	{
		self Show();
		util::wait_network_frame();
		if(IsDefined(self))
		{
			self.create_eyes = true;
		}
	}
}

function handle_rise_notetracks(note, spot)
{
	self thread finish_rise_notetracks(note, spot);
}

function finish_rise_notetracks(note, spot)
{
	// the anim notetracks control which death anim to play
	// default to "deathin" (still in the ground)

	if (note == "deathout" || note == "deathhigh")
	{
		self.zombie_rise_death_out = true;
		self notify("zombie_rise_death_out");

		wait 2;
		spot notify("stop_zombie_rise_fx");
	}
}

/*
function zombie_rise_death:
function Track when the zombie should die, set the death anim, and stop the animscripted so he can die
*/
function zombie_rise_death(zombie, spot)
{
	//self.nodeathragdoll = true;
	zombie.zombie_rise_death_out = false;

	zombie endon("rise_anim_finished");

	while ( IsDefined( zombie ) && IsDefined( zombie.health ) && zombie.health > 1)	// health will only go down to 1 when playing animation with AnimScripted()
	{
		zombie waittill("damage", amount);
	}

	if( IsDefined(spot) )
	{
		spot notify("stop_zombie_rise_fx");
	}

	if ( IsDefined( zombie ) )
	{
		zombie.deathanim = zombie get_rise_death_anim();
		zombie StopAnimScripted();	// stop the anim so the zombie can die.  death anim is handled by the anim scripts.
	}
}

function get_rise_death_anim()
{
	if ( self.zombie_rise_death_out )
	{
		return "zm_rise_death_out";
	}

	self.noragdoll = true;
	self.nodeathragdoll = true;
	return "zm_rise_death_in";
}

function reset_attack_spot()
{
	if( IsDefined( self.attacking_node ) )
	{
		node = self.attacking_node;
		index = self.attacking_spot_index;
		node.attack_spots_taken[index] = false;

		self.attacking_node = undefined;
		self.attacking_spot_index = undefined;
	}
}

function zombie_gut_explosion()
{
	self.guts_explosion=1;
	
	GibServerUtils::Annihilate( self );
}

//--------------------------------------------------------------------------------------------------
//		ZOMBIE EYE GLOWS
//--------------------------------------------------------------------------------------------------
/*
function delayed_zombie_eye_glow:
function Fixes problem where zombies that climb out of the ground are warped to their start positions
function and their eyes glowed above the ground for a split second before their animation started even
function though the zombie model is hidden. and applying this delay to all the zombies doesn't really matter.
*/
function delayed_zombie_eye_glow()
{
	self endon("zombie_delete");
	self endon("death");

	if ( IS_TRUE( self.in_the_ground ) || IS_TRUE( self.in_the_ceiling ) )
	{
		while(!IsDefined(self.create_eyes))
		{
			wait(0.1);
		}
	}
	else
	{
		wait .5;
	}
	self zombie_eye_glow();
}

// When a Zombie spawns, set his eyes to glowing.
function zombie_eye_glow()
{
	if(!IsDefined(self) || !IsActor( self ))
	{
		return;
	}	
	if ( !IsDefined( self.no_eye_glow ) || !self.no_eye_glow )
	{
		self clientfield::set("zombie_has_eyes", 1);
	}
}

// Called when either the Zombie dies or if his head gets blown off
function zombie_eye_glow_stop()
{
	if(!IsDefined(self) || !IsActor( self ))
	{
		return;
	}		
	if ( !IsDefined( self.no_eye_glow ) || !self.no_eye_glow )
	{
		self clientfield::set("zombie_has_eyes", 0);
	}
}




//--------------------------------------------------------------------------------------------------
//		ZOMBIE ROUND FUNCTIONALITY
//--------------------------------------------------------------------------------------------------
//put the conditions in here which should
//cause the failsafe to reset
function round_spawn_failsafe_debug_draw()
{
	self endon("death");//guy just died

	//////////////////////////////////////////////////////////////
	//FAILSAFE "hack shit"  DT#33203
	//////////////////////////////////////////////////////////////
	prevorigin = self.origin;
	while(1)
	{
		if( IS_TRUE(level.toggle_keyline_always) )
		{
			self clientfield::set("zombie_keyline_render", 1);
			wait( 1.0 );
			continue;
		}

		wait( 4.0 );


		//if i've torn a board down in the last 5 seconds, just 
		//wait again.
		if ( IsDefined(self.lastchunk_destroy_time) )
		{
			if ( (GetTime() - self.lastchunk_destroy_time) < 8000 )
				continue; 
		}
		
		//hasnt moved 24 inches in 10 seconds - draw outline	
		if ( DistanceSquared( self.origin, prevorigin ) < 576 ) 
		{
			self clientfield::set("zombie_keyline_render", 1);
		}
		else
		{
			self clientfield::set("zombie_keyline_render", 0);
		}

		prevorigin = self.origin;
	}
	//////////////////////////////////////////////////////////////
	//END OF FAILSAFE "hack"
	//////////////////////////////////////////////////////////////
}




//--------------------------------------------------------------------------------------------------
//		ZOMBIE ROUND FUNCTIONALITY
//--------------------------------------------------------------------------------------------------
//put the conditions in here which should
//cause the failsafe to reset
function round_spawn_failsafe()
{
	self endon("death");//guy just died

	if( IS_TRUE(level.debug_keyline_zombies) )
	{
		self thread round_spawn_failsafe_debug_draw();
	}
	
	//////////////////////////////////////////////////////////////
	//FAILSAFE "hack shit"  DT#33203
	//////////////////////////////////////////////////////////////
	prevorigin = self.origin;
	while(1)
	{
		if( !level.zombie_vars["zombie_use_failsafe"] )
		{
			return;
		}

		if ( IS_TRUE( self.ignore_round_spawn_failsafe ) )
		{
			return;
		}
		
		if(!IsDefined(level.failsafe_waittime))
		{
			level.failsafe_waittime = 30;	
		}
		
		wait( level.failsafe_waittime );

		if( self.missingLegs )
		{
			wait( 10.0 );
		}

		//inert zombies can ignore this
		if ( IS_TRUE( self.is_inert ) )
		{
			continue;
		}

		//if i've torn a board down in the last 5 seconds, just 
		//wait 30 again.
		if ( IsDefined(self.lastchunk_destroy_time) )
		{
			if ( (GetTime() - self.lastchunk_destroy_time) < 8000 )
				continue; 
		}

		//fell out of world
		if ( self.origin[2] < level.zombie_vars["below_world_check"] )
		{
			if(IS_TRUE(level.put_timed_out_zombies_back_in_queue ) && !level flag::get("special_round") && !IS_TRUE( self.isscreecher ) )
			{
				level.zombie_total++;
				level.zombie_total_subtract++;				
			}			
			
			self dodamage( self.health + 100, (0,0,0) );				
			break;
		}

		//hasnt moved 24 inches in 30 seconds?	
		if ( DistanceSquared( self.origin, prevorigin ) < 576 ) 
		{
			if( IsDefined( level.move_failsafe_override ) )
			{
				self thread [[level.move_failsafe_override]]( prevorigin );
			}
			else
			{
				//add this zombie back into the spawner queue to be re-spawned
				if(IS_TRUE(level.put_timed_out_zombies_back_in_queue ) && !level flag::get("special_round"))
				{
					//only if they have crawled thru a window and then timed out
					if ( !self.ignoreall && !IS_TRUE(self.nuked) && !IS_TRUE(self.marked_for_death) && !IS_TRUE( self.isscreecher ) && !self.missingLegs )
					{
						level.zombie_total++;
						level.zombie_total_subtract++;					
					}
				}
			
				//add this to the stats even tho he really didn't 'die' 
				level.zombies_timeout_playspace++;
			
				// DEBUG HACK
				self dodamage( self.health + 100, (0,0,0) );
			}
			break;
		}

		prevorigin = self.origin;
	}
	//////////////////////////////////////////////////////////////
	//END OF FAILSAFE "hack"
	//////////////////////////////////////////////////////////////
}


function ai_calculate_health( round_number )
{
	level.zombie_health = level.zombie_vars["zombie_health_start"]; 
	for ( i=2; i <= round_number; i++ )
	{
		// After round 10, get exponentially harder
		if ( i >= 10 )
		{
			old_health = level.zombie_health;
			level.zombie_health += Int( level.zombie_health * level.zombie_vars["zombie_health_increase_multiplier"] );

			if ( level.zombie_health < old_health )
			{
				// we must have overflowed the signed integer space, just use the last good health, it'll give some headroom to the capped value to account for extra damage applications
				level.zombie_health = old_health;
				return;
			}
		}
		else
		{
			level.zombie_health = Int( level.zombie_health + level.zombie_vars["zombie_health_increase"] ); 
		}
	}
}


function default_max_zombie_func( max_num, n_round )
{
	/#
		count = GetDvarInt( "zombie_default_max", -1 );
		if ( count > -1 )
		{
			return count;
		}
	#/

	max = max_num;

	if( n_round < 2 )
	{
		max = int( max_num * 0.25 );
	}
	else if( n_round < 3 )
	{
		max = int( max_num * 0.3 );
	}
	else if( n_round < 4 )
	{
		max = int( max_num * 0.5 );
	}
	else if( n_round < 5 )
	{
		max = int( max_num * 0.7 );
	}
	else if( n_round < 6 )
	{
		max = int( max_num * 0.9 );
	}
	
	return max;
}

function zombie_speed_up()
{
	if( level.round_number <= 3 )
	{
		return;
	}

	level endon( "intermission" );
	level endon( "end_of_round" );
	level endon( "restart_round" );
	level endon( "kill_round" );

	// Wait until we've finished spawning
	while ( level.zombie_total > 4 )
	{
		wait( 3.0 );
	}

	//	Keep checking as long as there's a zombie left.
	a_ai_zombies = get_round_enemy_array();
	while( a_ai_zombies.size > 0 || level.zombie_total > 0 )
	{
		if( a_ai_zombies.size == 1 )
		{
			ai_zombie = a_ai_zombies[0];
			
			if( IsAlive( ai_zombie ) )
			{
				if ( IsDefined( level.zombie_speed_up ) )
				{
					ai_zombie thread [[ level.zombie_speed_up ]]();
				}
				else
				{
					//set_zombie_run_cycle to sprint
					if( !IS_EQUAL(ai_zombie.zombie_move_speed, "sprint") )
					{
						ai_zombie zombie_utility::set_zombie_run_cycle( "sprint" );
						ai_zombie.zombie_move_speed_original = ai_zombie.zombie_move_speed;
					}
				}
			}
		}
		wait(0.5);
		
		a_ai_zombies = get_round_enemy_array();
	}
}

function get_current_zombie_count()
{
	enemies = get_round_enemy_array();
	return enemies.size;
}

function get_round_enemy_array()
{
	a_ai_enemies = [];
	a_ai_valid_enemies = [];
	a_ai_enemies = GetAITeamArray( level.zombie_team );

	for( i = 0; i < a_ai_enemies.size; i++ )
	{
		if ( IS_TRUE( a_ai_enemies[i].ignore_enemy_count ) )
		{
			continue;
		}
		ARRAY_ADD( a_ai_valid_enemies, a_ai_enemies[i] );
	}
	
	return a_ai_valid_enemies;
}

// Returns an array of all zombies
function get_zombie_array()
{
	enemies = [];
	valid_enemies = [];
	enemies = GetAiSpeciesArray( level.zombie_team, "all" );

	for( i = 0; i < enemies.size; i++ )
	{
		if ( enemies[i].archetype == ARCHETYPE_ZOMBIE )
		{
			ARRAY_ADD( valid_enemies, enemies[i] );
		}
	}
	
	return valid_enemies;
}

// self = zombie
function set_zombie_run_cycle_override_value( new_move_speed )
{
	set_zombie_run_cycle( new_move_speed );
	self.zombie_move_speed_override = new_move_speed;
}

// self = zombie
function set_zombie_run_cycle_restore_from_override()
{
	str_restore_move_speed = self.zombie_move_speed_restore;
	
	self.zombie_move_speed_override = undefined; // turn off the override, so set_zombie_run_cycle will accept our change
	set_zombie_run_cycle( str_restore_move_speed );
}

function set_zombie_run_cycle( new_move_speed )
{
	// if we're currently overriding the zombie speed, store off any attempted changes and we can restore them later
	if( isdefined( self.zombie_move_speed_override ) )
	{
		self.zombie_move_speed_restore = new_move_speed;
		return;
	}
	
	self.zombie_move_speed_original = self.zombie_move_speed;

	if ( IsDefined( new_move_speed ) )
	{
		self.zombie_move_speed = new_move_speed;				
	}
	else
	{
		if( level.gamedifficulty == 0 )	//no sprinters on easy
			//self set_run_speed_easy();
		else
			self set_run_speed();
	}
	if( IsDefined( level.zm_variant_type_max ) )
	{
		/#
		// sjakatdar TU3 (11/12/2015) 
		// Removed the debugging here to make sure that we have same behavior as ship as this lead to some ship only problems
		// If you need to test variations, just change the script locally
		if(0)
		{
			debug_variant_type = GetDvarInt( "scr_zombie_variant_type", -1 );
			
			if( debug_variant_type != -1 )
			{
				if(debug_variant_type <= level.zm_variant_type_max[self.zombie_move_speed][self.zombie_arms_position] )
				{
					self.variant_type = debug_variant_type;
				}
				else
				{
					self.variant_type = level.zm_variant_type_max[self.zombie_move_speed][self.zombie_arms_position] - 1;
				}
			}
			else
			{
				self.variant_type = RandomInt( level.zm_variant_type_max[self.zombie_move_speed][self.zombie_arms_position] );				
			}
		}
		#/
		
		if( self.archetype === ARCHETYPE_ZOMBIE )
		{
			if ( isdefined( self.zm_variant_type_max ) )
			{
				self.variant_type = RandomInt( self.zm_variant_type_max[self.zombie_move_speed][self.zombie_arms_position] );
			}
			else
			{
				if ( isdefined( level.zm_variant_type_max[self.zombie_move_speed] ) )
				{
					self.variant_type = RandomInt( level.zm_variant_type_max[self.zombie_move_speed][self.zombie_arms_position] );
				}
				else
				{
					/#
					ErrorMsg( "No variants set up for move speed " + self.zombie_move_speed );
					#/
					self.variant_type = 0;
				}
			}
		}
	}

	self.needs_run_update = true;
	self notify( "needs_run_update" );
	
	self.deathanim = self zombie_utility::append_missing_legs_suffix( "zm_death" );
}

function set_run_speed()
{
	// We may want to force running zombies at the start of a round, to get zombies in to the arena quickly
	if( isdefined(level.zombie_force_run) )
	{
		self.zombie_move_speed = "run"; 
		level.zombie_force_run--;
		if( level.zombie_force_run <= 0 )
		{
			level.zombie_force_run = undefined;
		}
		
		return;
	}
		
	rand = 99 //randomintrange( level.zombie_move_speed, level.zombie_move_speed + 35 ); 

//	self thread print_run_speed( rand );
	if( rand <= 35 )
	{
		self.zombie_move_speed = "walk"; 
	}
	else if( rand <= 70 )
	{
		self.zombie_move_speed = "run"; 
	}
	else
	{	
		self.zombie_move_speed = "sprint"; 
	}
}

function set_run_speed_easy()
{
	rand = randomintrange( level.zombie_move_speed, level.zombie_move_speed + 25 ); 

//	self thread print_run_speed( rand );
	if( rand <= 35 )
	{
		self.zombie_move_speed = "walk"; 
	}
	else
	{
		self.zombie_move_speed = "run"; 
	}
}

//self = zombie being knocked down
//entity = entity knocking zombie down
function setup_zombie_knockdown( entity )
{
	self.knockdown = true;
	zombie_to_entity = entity.origin - self.origin;
	zombie_to_entity_2d = VectorNormalize( ( zombie_to_entity[0], zombie_to_entity[1], 0 ) );
	
	zombie_forward = AnglesToForward( self.angles );
	zombie_forward_2d = VectorNormalize( ( zombie_forward[0], zombie_forward[1], 0 ) );
	
	zombie_right = AnglesToRight( self.angles );
	zombie_right_2d = VectorNormalize( ( zombie_right[0], zombie_right[1], 0 ) );
	
	dot = VectorDot( zombie_to_entity_2d, zombie_forward_2d );
	
	if( dot >= 0.5 )
	{
		self.knockdown_direction = "front";
		self.getup_direction = GETUP_BACK;
	}
	else if ( dot < 0.5 && dot > -0.5 )
	{
		dot = VectorDot( zombie_to_entity_2d, zombie_right_2d );
		if( dot > 0 )
		{
			self.knockdown_direction = "right";

			if ( math::cointoss() )
			{
				self.getup_direction = GETUP_BACK;
			}
			else
			{
				self.getup_direction = GETUP_BELLY;
			}
		}
		else
		{
			self.knockdown_direction = "left";
			self.getup_direction = GETUP_BELLY;
		}
	}
	else
	{
		self.knockdown_direction = "back";
		self.getup_direction = GETUP_BELLY;
	}
}

function clear_all_corpses()
{
	corpse_array = GetCorpseArray();
	
	for ( i = 0; i < corpse_array.size; i++ )
	{
		if ( IsDefined( corpse_array[ i ] ) )
		{
			corpse_array[ i ] Delete();
		}
	}
}

function get_current_actor_count()
{
	count = 0;
	actors = GetAiSpeciesArray( level.zombie_team, "all" );
	if (IsDefined(actors))
		count += actors.size;
	count += get_current_corpse_count();
	return count;
}

function get_current_corpse_count()
{
	corpse_array = GetCorpseArray();
	if (IsDefined(corpse_array))
		return corpse_array.size;
	return 0;
}

//--------------------------------------------------------------------------------------------------
//		ZOMBIE GIBBING
//--------------------------------------------------------------------------------------------------
// gib limbs if enough firepower occurs
function zombie_gib_on_damage()
{
//	self endon( "death" ); 

	while( 1 )
	{
		self waittill( "damage", amount, attacker, direction_vec, point, type, tagName, ModelName, Partname, weapon ); 	

		if( !IsDefined( self ) )
		{
			return;
		}

		if( !self zombie_should_gib( amount, attacker, type ) )
		{
			continue; 
		}

		if( self head_should_gib( attacker, type, point ) && type != "MOD_BURNED" )
		{
			self zombie_head_gib( attacker, type );
			continue;
		}

		if( !IS_TRUE(self.gibbed) && isDefined(self.damageLocation) )
		{
			// The head_should_gib() above checks for this, so we should not randomly gib if shot in the head
			if ( self damagelocationisany( "head", "helmet", "neck" ) )
			{
				continue;
			}
			
			//Zombie is about to stumble, so don't gib.
			self.stumble = undefined;


			switch( self.damageLocation )
			{
				case "torso_upper":
				case "torso_lower":
					// HACK the torso that gets swapped for guts also removes the left arm
					//  so we need to sometimes do another ref

					if ( !GibServerUtils::IsGibbed( self, GIB_TORSO_LEFT_ARM_FLAG ) )
						GibServerUtils::GibRightArm( self );
					break; 
	
				case "right_arm_upper":
				case "right_arm_lower":
				case "right_hand":

					if ( !GibServerUtils::IsGibbed( self, GIB_TORSO_LEFT_ARM_FLAG ) )
						GibServerUtils::GibRightArm( self );
					break; 
	
				case "left_arm_upper":
				case "left_arm_lower":
				case "left_hand":

					if ( !GibServerUtils::IsGibbed( self, GIB_TORSO_RIGHT_ARM_FLAG ) )
						GibServerUtils::GibLeftArm( self );
					break; 
	
				case "right_leg_upper":
				case "right_leg_lower":
				case "right_foot":
					if( self.health <= 0 )
					{
						
						GibServerUtils::GibRightLeg( self );
						
						if( randomint( 100 ) > 75 )
							GibServerUtils::GibLeftLeg( self );
							
						self.missingLegs = true;
					}
					break; 
	
				case "left_leg_upper":
				case "left_leg_lower":
				case "left_foot":
					if( self.health <= 0 )
					{
						GibServerUtils::GibLeftLeg( self );
						if( randomint( 100 ) > 75 )
							GibServerUtils::GibRightLeg( self );
				
						self.missingLegs = true;
						
					}
					break; 
			default:
				
				if( self.damageLocation == "none" )
				{
					// SRS 9/7/2008: might be a nade or a projectile
					if( type == "MOD_GRENADE" || type == "MOD_GRENADE_SPLASH" || type == "MOD_PROJECTILE" || type == "MOD_PROJECTILE_SPLASH" )
					{
						// ... in which case we have to derive the ref ourselves
						self derive_damage_refs( point );
						break;
					}
				}

			}
			
			if( IsDefined( level.custom_derive_damage_refs ) )
			{
				//refs = self [[ level.custom_derive_damage_refs ]](refs, point, weapon);
			}

			// Don't stand if a leg is gone
			if( IS_TRUE(self.missingLegs) && self.health > 0 )//( self.a.gib_ref == "no_legs" || self.a.gib_ref == "right_leg" || self.a.gib_ref == "left_leg" ) && self.health > 0 ) //( GibServerUtils::IsGibbed(self, GIB_LEGS_LEFT_LEG_FLAG) || GibServerUtils::IsGibbed(self, GIB_LEGS_RIGHT_LEG_FLAG) ) && self.health > 0)
			{

				self AllowedStances( "crouch" ); 
									
				// reduce collbox so player can jump over
				self setPhysParams( 15, 0, 24 );

				self AllowPitchAngle( 1 );
				self setPitchOrient();
				
				health = self.health;
				health = health * 0.1;

				if ( IsDefined( self.crawl_anim_override ) )
				{
					self [[ self.crawl_anim_override ]]();
				}			
			}
			

			if( self.health > 0 )
			{

				if ( IsDefined( level.gib_on_damage ) )
				{
					self thread [[ level.gib_on_damage ]]();
				}
			}
		}
	}
}

function add_zombie_gib_weapon_callback( weapon_name, gib_callback, gib_head_callback )
{
	DEFAULT(level.zombie_gib_weapons,[]);
	DEFAULT(level.zombie_gib_head_weapons,[]);
	level.zombie_gib_weapons[weapon_name] = gib_callback;
	level.zombie_gib_head_weapons[weapon_name] = gib_head_callback;
}

function have_zombie_weapon_gib_callback( weapon )
{
	DEFAULT(level.zombie_gib_weapons,[]);
	DEFAULT(level.zombie_gib_head_weapons,[]);
	if ( IsWeapon( weapon ) )
		weapon = weapon.name;
	if ( IsDefined(level.zombie_gib_weapons[weapon] ) )
		return true;
	return false;
}

function get_zombie_weapon_gib_callback( weapon, damage_percent )
{
	DEFAULT(level.zombie_gib_weapons,[]);
	DEFAULT(level.zombie_gib_head_weapons,[]);
	if ( IsWeapon( weapon ) )
		weapon = weapon.name;
	if ( IsDefined(level.zombie_gib_weapons[weapon] ) )
	{
		return self [[level.zombie_gib_weapons[weapon]]]( damage_percent );
	}
	return false;
}

function have_zombie_weapon_gib_head_callback( weapon )
{
	DEFAULT(level.zombie_gib_weapons,[]);
	DEFAULT(level.zombie_gib_head_weapons,[]);
	if ( IsWeapon( weapon ) )
		weapon = weapon.name;
	if ( IsDefined(level.zombie_gib_head_weapons[weapon] ) )
		return true;
	return false;
}

function get_zombie_weapon_gib_head_callback( weapon, damage_location )
{
	DEFAULT(level.zombie_gib_weapons,[]);
	DEFAULT(level.zombie_gib_head_weapons,[]);
	if ( IsWeapon( weapon ) )
		weapon = weapon.name;
	if ( IsDefined(level.zombie_gib_head_weapons[weapon] ) )
	{
		return self [[level.zombie_gib_head_weapons[weapon]]]( damage_location );
	}
	return false;
}

function zombie_should_gib( amount, attacker, type )
{
	if( !IsDefined( type ) )
	{
		return false; 
	}

	if ( IS_TRUE( self.is_on_fire ) )
	{
		return false;
	}

	if ( IsDefined( self.no_gib ) && ( self.no_gib == 1 ) )
	{
		return false;
	}

	prev_health = amount + self.health;
	if( prev_health <= 0 )
	{
		prev_health = 1;
	}

	damage_percent = ( amount / prev_health ) * 100; 

	weapon = undefined; 
	if( IsDefined( attacker ) )
	{
		if( IsPlayer( attacker ) || IS_TRUE(attacker.can_gib_zombies) )
		{
			if( IsPlayer( attacker ) )
	{
		weapon = attacker GetCurrentWeapon(); 
			}
			else
			{
				weapon = attacker.weapon;
			}
	
		if ( have_zombie_weapon_gib_callback( weapon ) )
		{
			if ( self get_zombie_weapon_gib_callback( weapon, damage_percent ) )
			{
				return true;
			}
			return false;
		}
	}
	}
	
	switch( type )
	{
		case "MOD_UNKNOWN":
		case "MOD_TELEFRAG":
		case "MOD_FALLING": 
		case "MOD_SUICIDE": 
		case "MOD_TRIGGER_HURT":
		case "MOD_BURNED":	
			return false; 
		case "MOD_MELEE":	
//Z2	HasPerk( "specialty_altmelee" ) is returning undefined
// 			if( isPlayer( attacker ) && randomFloat( 1 ) > 0.25 && attacker HasPerk( "specialty_altmelee" ) )
// 			{
// 				return true;
// 			}
// 			else 
			{
				return false;
			}
	}

	if( type == "MOD_PISTOL_BULLET" || type == "MOD_RIFLE_BULLET" )
	{
		if( !IsDefined( attacker ) || !IsPlayer( attacker ) )
		{
			return false; 
		}

		if( weapon == level.weaponNone || (IsDefined(level.start_weapon) && weapon == level.start_weapon) || weapon.isGasWeapon )
		{
			return false; 
		}
	}

//	println( "**DEBUG amount = ", amount );
//	println( "**DEBUG self.head_gibbed = ", self.head_gibbed );
//	println( "**DEBUG self.health = ", self.health );

	if( damage_percent < 10 /*|| damage_percent >= 100*/ )
	{
		return false; 
	}

	return true; 
}

function head_should_gib( attacker, type, point )
{
	if( IS_TRUE(self.head_gibbed) )
	{
		return false;
	}
	
	if( !isdefined( attacker ) )
	{
		return false;
	}
	
	if( !IsPlayer( attacker ) )
	{
		if( !IS_TRUE( attacker.can_gib_zombies)  )//allow non player types to gib (robot)
		{
			return false; 
		}
	}	

	// check if the attacker was a player
	if( IsPlayer(attacker ))
	{
		weapon = attacker GetCurrentWeapon(); 
	}
	else
	{
		weapon = attacker.weapon;
	}

	if ( have_zombie_weapon_gib_head_callback( weapon ) )
	{
		if ( self get_zombie_weapon_gib_head_callback( weapon, self.damagelocation ) )
		{
			return true;
		}
		return false;
	}
	
	// SRS 9/2/2008: check for damage type
	//  - most SMGs use pistol bullets
	//  - projectiles = rockets, raygun
	if( type != "MOD_RIFLE_BULLET" && type != "MOD_PISTOL_BULLET" )
	{
		// maybe it's ok, let's see if it's a grenade
		if( type == "MOD_GRENADE" || type == "MOD_GRENADE_SPLASH" )
		{
			if( Distance( point, self GetTagOrigin( "j_head" ) ) > 55 )
			{
				return false;
			}
			else
			{
				// the grenade airburst close to the head so return true
				return true;
			}
		}
		else if( type == "MOD_PROJECTILE" )
		{
			if( Distance( point, self GetTagOrigin( "j_head" ) ) > 10 )
			{
				return false;
			}
			else
			{
				return true;
			}
		}
		// shottys don't give a testable damage type but should still gib heads
		else if( weapon.weapClass != "spread" )
		{
			return false; 
		}
	}

	// check location now that we've checked for grenade damage (which reports "none" as a location)
	if ( !self damagelocationisany( "head", "helmet", "neck" ) )
	{
		return false; 
	}

	// check weapon - don't want "none", base pistol, or flamethrower
	if( ( type == "MOD_PISTOL_BULLET" && weapon.weapClass != "smg" && weapon.weapClass != "spread" ) || 
	    weapon == level.weaponNone || 
	    (IsDefined(level.start_weapon) && weapon == level.start_weapon) || 
	    weapon.isGasWeapon )
	{
		return false; 
	}

	//DCS: temporarily added for cp zombie gibbing until can check a weapon gdt "do gibbing" availability.
	if( SessionModeIsCampaignGame() && (type == "MOD_PISTOL_BULLET" && weapon.weapClass != "smg"))
	{
		return false; 
	}	
	// check the enemy's health
	low_health_percent = ( self.health / self.maxhealth ) * 100; 
	if( low_health_percent > 10 )
	{
		// TOOD(David Young 9-15-14): Commenting out because gibbing anything
		// should not happen here.  Will remove completely once hat gibbing is supported.
		// self zombie_hat_gib( attacker, type );
		return false; 
	}

	return true; 
}

function zombie_hat_gib( attacker, means_of_death )
{
	self endon( "death" );

	if ( IS_TRUE( self.hat_gibbed ) )
	{
		return;
	}
	
	if ( !IsDefined( self.gibSpawn5 ) || !IsDefined( self.gibSpawnTag5 ) )
	{
		return;
	}

	self.hat_gibbed = true;

	if ( IsDefined( self.hatmodel ) )
	{
		self detach( self.hatModel, "" ); 
	}

	temp_array = [];
	temp_array[0] = level._ZOMBIE_GIB_PIECE_INDEX_HAT;

	self gib( "normal", temp_array );
	
	//stat tracking
	if ( IsDefined( level.track_gibs ) )
	{
		level [[ level.track_gibs ]]( self, temp_array );
	}
}

function head_gib_damage_over_time( dmg, delay, attacker, means_of_death )
{
	self endon( "death" );
	self endon( "exploding" );

	if( !IsAlive( self ) )
	{
		return;
	}

	if( !IsPlayer( attacker ) )
	{
		attacker = self;
	}
	
	if ( !IsDefined( means_of_death ) )
	{
		means_of_death = "MOD_UNKNOWN";
	}

	dot_location = self.damageLocation;
	dot_weapon = self.damageweapon; 
	
	while( 1 )
	{
		if( IsDefined( delay ) )
		{
			wait( delay );
		}
		if (IsDefined(self))
		{
			if( IS_TRUE( self.no_gib ) )
			{
				return;
			}
			if(IsDefined(attacker))
			{
				self DoDamage( dmg, self GetTagOrigin( "j_neck" ), attacker, self, dot_location, means_of_death, 0, dot_weapon );//player can drop out
			}
			else
			{
				self DoDamage( dmg, self GetTagOrigin( "j_neck" ));
			}
		}
	}
}

// SRS 9/7/2008: need to derive damage location for types that return location of "none"
function derive_damage_refs( point )
{
	if( !IsDefined( level.gib_tags ) )
	{
		init_gib_tags();
	}
	
	closestTag = undefined;
	
	for( i = 0; i < level.gib_tags.size; i++ )
	{
		if( !IsDefined( closestTag ) )
		{
			closestTag = level.gib_tags[i];
		}
		else
		{
			if( DistanceSquared( point, self GetTagOrigin( level.gib_tags[i] ) ) < DistanceSquared( point, self GetTagOrigin( closestTag ) ) )
			{
				closestTag = level.gib_tags[i];
			}
		}
	}
	
	// figure out the refs based on the tag returned
	if( closestTag == "J_SpineLower" || closestTag == "J_SpineUpper" || closestTag == "J_Spine4" )
	{
		// HACK the torso that gets swapped for guts also removes the left arm
		//  so we need to sometimes do another ref
		//GibServerUtils::GibEntity( self, GIB_TORSO_GUTS_FLAG );
		GibServerUtils::GibRightArm( self );

	}
	else if( closestTag == "J_Shoulder_LE" || closestTag == "J_Elbow_LE" || closestTag == "J_Wrist_LE" )
	{
		if ( !GibServerUtils::IsGibbed( self, GIB_TORSO_RIGHT_ARM_FLAG ) )
			GibServerUtils::GibLeftArm( self );
	}
	else if( closestTag == "J_Shoulder_RI" || closestTag == "J_Elbow_RI" || closestTag == "J_Wrist_RI" )
	{
		if ( !GibServerUtils::IsGibbed( self, GIB_TORSO_LEFT_ARM_FLAG ) )
			GibServerUtils::GibRightArm( self );
	}
	else if( closestTag == "J_Hip_LE" || closestTag == "J_Knee_LE" || closestTag == "J_Ankle_LE" )
	{
		if ( IS_TRUE( self.noCrawler ) )
		{
			return;
		}

		GibServerUtils::GibLeftLeg( self );
		if( randomint(100) > 75)
			GibServerUtils::GibRightLeg( self );
		self.missingLegs = true;
	}
	else if( closestTag == "J_Hip_RI" || closestTag == "J_Knee_RI" || closestTag == "J_Ankle_RI" )
	{
		if ( IS_TRUE( self.noCrawler ) )
		{
			return;
		}

		GibServerUtils::GibRightLeg( self );
		if( randomint(100) > 75)
			GibServerUtils::GibLeftLeg( self );
		self.missingLegs = true;
	}
	
	
	//return refs;
}

function init_gib_tags()
{
	tags = [];
					
	// "guts", "right_arm", "left_arm", "right_leg", "left_leg", "no_legs"
	
	// "guts"
	tags[tags.size] = "J_SpineLower";
	tags[tags.size] = "J_SpineUpper";
	tags[tags.size] = "J_Spine4";
	
	// "left_arm"
	tags[tags.size] = "J_Shoulder_LE";
	tags[tags.size] = "J_Elbow_LE";
	tags[tags.size] = "J_Wrist_LE";
	
	// "right_arm"
	tags[tags.size] = "J_Shoulder_RI";
	tags[tags.size] = "J_Elbow_RI";
	tags[tags.size] = "J_Wrist_RI";
	
	// "left_leg"/"no_legs"
	tags[tags.size] = "J_Hip_LE";
	tags[tags.size] = "J_Knee_LE";
	tags[tags.size] = "J_Ankle_LE";
	
	// "right_leg"/"no_legs"
	tags[tags.size] = "J_Hip_RI";
	tags[tags.size] = "J_Knee_RI";
	tags[tags.size] = "J_Ankle_RI";
	
	level.gib_tags = tags;
}

//--------------------------------------------------------------------------------------------------
function getAnimDirection( damageyaw )
{
	if( ( damageyaw > 135 ) ||( damageyaw <= -135 ) )	// Front quadrant
	{
		return "front";
	}
	else if( ( damageyaw > 45 ) &&( damageyaw <= 135 ) )		// Right quadrant
	{
		return "right";
	}
	else if( ( damageyaw > -45 ) &&( damageyaw <= 45 ) )		// Back quadrant
	{
		return "back";
	}
	else
	{															// Left quadrant
		return "left";
	}
	return "front";
}

function anim_get_dvar_int( dvar, def )
{
	return int( anim_get_dvar( dvar, def ) );
}

// dvar set/fetch/check
function anim_get_dvar( dvar, def )
{
	if ( GetDvarString( dvar ) != "" )
		return getdvarfloat( dvar );
	else
	{
		SetDvar( dvar, def );
		return def;
	}
}

function makeZombieCrawler( b_both_legs )
{
	if( IS_TRUE( b_both_legs ) )
	{
		val = 100;	
	}
	else
	{
		val = randomint( 100 );	
	}
	
	if( val > 75 )
	{
		GibServerUtils::GibRightLeg( self );
		GibServerUtils::GibLeftLeg( self );
	}
	else if ( val > 37 )
		GibServerUtils::GibRightLeg( self );
	else
		GibServerUtils::GibLeftLeg( self );
	
	self.missingLegs = true;
	self AllowedStances( "crouch" ); 
									
	// reduce collbox so player can jump over
	self setPhysParams( 15, 0, 24 );

	self AllowPitchAngle( 1 );
	self setPitchOrient();
				
	health = self.health;
	health = health * 0.1;
} 

function zombie_head_gib( attacker, means_of_death )
{
	self endon( "death" );

	if ( IS_TRUE( self.head_gibbed ) )
	{
		return;
	}
	
	if( IS_TRUE( self.no_gib ) )
	{
		return;
	}
	
	self.head_gibbed = true;

	self zombie_eye_glow_stop();
	

	if( !IS_TRUE( self.disable_head_gib ) )
	{
		GibServerUtils::GibHead( self );
	}

	self thread head_gib_damage_over_time( ceil( self.health * 0.2 ), 1, attacker, means_of_death );
}

function gib_random_parts()
{
	if( IS_TRUE( self.no_gib ) )
	{
		return;
	}
	
	val = randomint( 100 );
	if( val > 50 )
	{
		self zombie_utility::zombie_head_gib();
	}
	val = randomint( 100 );
	if( val > 50 )
	{
		GibServerUtils::GibRightLeg( self );
	}
	val = randomint( 100 );
	if( val > 50 )
	{
		GibServerUtils::GibLeftLeg( self );
	}
	val = randomint( 100 );
	if( val > 50 )
	{
		if ( !GibServerUtils::IsGibbed( self, GIB_TORSO_LEFT_ARM_FLAG ) )
			GibServerUtils::GibRightArm( self );
	}
	val = randomint( 100 );
	if( val > 50 )
	{
		if ( !GibServerUtils::IsGibbed( self, GIB_TORSO_RIGHT_ARM_FLAG ) )
			GibServerUtils::GibLeftArm( self );
	}	
}

// ------------- ignore player utility ----------- //
function autoexec init_ignore_player_handler()
{
	level._IGNORE_PLAYER_HANDLER = [];
}

function register_ignore_player_handler( archetype, ignore_player_func )
{
	Assert( IsDefined( archetype ), "IgnorePlayerHandler undefined archetype." );

	Assert( !IsDefined( level._IGNORE_PLAYER_HANDLER[ archetype ] ), "IgnorePlayerHandler for " + archetype + " is already registered." );

	level._IGNORE_PLAYER_HANDLER[ archetype ] = ignore_player_func;
}

function run_ignore_player_handler()
{
	if ( IsDefined( level._IGNORE_PLAYER_HANDLER[ self.archetype ] ) )
	{
		self [[ level._IGNORE_PLAYER_HANDLER[ self.archetype ] ]]();
	}
}

// hit marker on player, call this in the damage callback for AI on the player attacker to show crosshair
function show_hit_marker()  // self = player
{
	if ( IsDefined( self ) && IsDefined( self.hud_damagefeedback ) )
	{
		self.hud_damagefeedback SetShader( "damage_feedback", 24, 48 );
		self.hud_damagefeedback.alpha = 1;
		self.hud_damagefeedback FadeOverTime(1);
		self.hud_damagefeedback.alpha = 0;
	}	
}