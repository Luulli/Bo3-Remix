#using scripts\codescripts\struct;
#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_healthbar;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_bloodsplatter;



#using scripts\zm\_load;
#define RED_EYE_FX    "frost_iceforge/red_zombie_eyes"
#define ORANGE_EYE_FX    "frost_iceforge/orange_zombie_eyes"
#define GREEN_EYE_FX    "frost_iceforge/green_zombie_eyes"
#define BLUE_EYE_FX    "frost_iceforge/blue_zombie_eyes"
#define PURPLE_EYE_FX    "frost_iceforge/purple_zombie_eyes"
#define PINK_EYE_FX    "frost_iceforge/pink_zombie_eyes"
#define WHITE_EYE_FX    "frost_iceforge/white_zombie_eyes"
#define FX_POWER_ON "zombie/kj_fx_powerup_on_white"
#precache( "client_fx", RED_EYE_FX );
#precache( "client_fx", ORANGE_EYE_FX );
#precache( "client_fx", GREEN_EYE_FX );
#precache( "client_fx", BLUE_EYE_FX );
#precache( "client_fx", PURPLE_EYE_FX );
#precache( "client_fx", PINK_EYE_FX );
#precache( "client_fx", WHITE_EYE_FX );
#precache( "client_fx", FX_POWER_ON);  //change color to what you want
//*****************************************************************************
// MAIN
//*****************************************************************************


function autoexec init()
{
 set_eye_color();
 LuiLoad("UI.HUDInject.HUDInject");

}

function set_eye_color()
{
 level._override_eye_fx = RED_EYE_FX; //Change "BLUE" to any of the other colors
 level._effect["powerup_on"] = FX_POWER_ON;  //change color to what you want
}
