#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

// Magmagat for Mob of the Dead (Plutonium T6, zm_prison). Entry point.
init()
{
    if ( !isdefined( level.script ) || level.script != "zm_prison" )
        return;

    if ( isdefined( level.mg_active ) )
        return;

    level.mg_active = 1;
    level.mg_version = "0.1.0";
    level thread mg_boot();
}

mg_boot()
{
    level endon( "end_game" );
    flag_wait( "start_zombie_round_logic" );
    print( "[MG] Magmagat " + level.mg_version + " loaded\n" );
}
