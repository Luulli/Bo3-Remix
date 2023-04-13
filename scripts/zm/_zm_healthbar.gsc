#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace zm_healthbar;

REGISTER_SYSTEM("zm_healthbar", &__init__, undefined)

function __init__()
{

    clientfield::register("clientuimodel", "player_healthbar", 1, 6, "float");
    callback::on_connect(&on_player_connect);

}

function on_player_connect()
{

    self thread health_monitor();
}


function health_monitor()
{

    self endon("disconnect");

    for(;;)
    {
        
        if(isdefined(self.health) && isdefined(self.maxHealth) && self clientfield::get_player_uimodel("player_healthbar") != (self.health / self.maxHealth))
        {
            self clientfield::set_player_uimodel("player_healthbar", self.health / self.maxHealth);
        }
        
        WAIT_SERVER_FRAME;
    }

}