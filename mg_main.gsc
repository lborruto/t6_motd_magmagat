#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;

// Magmagat for Mob of the Dead (Plutonium T6, zm_prison). Entry point.
init()
{
    if ( !isdefined( level.script ) || level.script != "zm_prison" )
        return;

    if ( isdefined( level.mg_active ) )
        return;

    level.mg_active = 1;
    mg_fx_init();
    mg_precache();
    level.mg_version = "0.1.0";
    level thread mg_boot();
}

mg_boot()
{
    level endon( "end_game" );
    flag_wait( "start_zombie_round_logic" );
    mg_coords_init();
    level thread mg_systems_boot();
    print( "[MG] Magmagat " + level.mg_version + " loaded\n" );
}
