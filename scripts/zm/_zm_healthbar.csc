#using scripts\codescripts\struct;

#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\system_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace zm_healthbar;

REGISTER_SYSTEM("zm_healthbar", &__init__, undefined)

function __init__()
{
    clientfield::register("clientuimodel", "player_healthbar", 1, 6, "float", undefined, 0, 0);
}