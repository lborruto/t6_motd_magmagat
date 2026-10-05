#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_hearth;
#include scripts\zm\zm_prison\mg_run;
#include scripts\zm\zm_prison\mg_forge;

// The quest state machine. States, in order: locked, ready, souls, pickup, run, forge, done. Play goes from run back
// to ready when the carrier lays the tempered gun on the powered Machine (the next player may temper his own); "forge"
// and "done" are only reached by `!mg goto`: "forge" leaves a pressed Magmagat on the open forge for the player typing it.

mg_quest_init()
{
    level.mg_state = "locked";
    level thread mg_bridge_gate();
}

mg_state_is( s )
{
    return isdefined( level.mg_state ) && level.mg_state == s;
}

mg_state_set( s )
{
    old = level.mg_state;
    level.mg_state = s;
    mg_debug_print( "MG: state " + old + " -> " + s );
    level notify( "mg_state", s );
}

// ready once the bridge's electric chair has been taken after the first plane trip (the remaster waits for
// plane_trip_to_nml_successful, MG.gsc:109; T6's zm_alcatraz_sq sets the same flag in its chairs). An older map without
// it falls back on the plane landing on the bridge. The gate waits for our own "mg_bridge_reached": the flag sends it
// in play, `!mg bridge` sends it to test the gate (setting the vanilla flag by hand would give the chair's rewards).
mg_bridge_gate()
{
    level endon( "end_game" );
    gate = mg_gate_flag();

    if ( !isdefined( gate ) )
        mg_debug_print( "MG: no bridge flag, the fireplace opens at once" );
    else
    {
        level thread mg_bridge_flag_watch( gate );
        level waittill( "mg_bridge_reached" );
    }

    // every "mg_bridge_reached" opens a locked fireplace (a `!mg goto locked` can be undone by `!mg bridge`)
    while ( true )
    {
        if ( mg_state_is( "locked" ) )
        {
            mg_state_set( "ready" );
            mg_debug_print( "MG: the bridge's chair was taken, the fireplace can burn its boards" );
        }

        level waittill( "mg_bridge_reached" );
    }
}

// the flag the gate waits for, or undefined
mg_gate_flag()
{
    if ( flag_exists( "plane_trip_to_nml_successful" ) )
        return "plane_trip_to_nml_successful";

    if ( flag_exists( "activate_player_zone_bridge" ) )
        return "activate_player_zone_bridge";

    return undefined;
}

mg_bridge_flag_watch( gate )
{
    level endon( "end_game" );
    level endon( "mg_bridge_reached" );
    flag_wait( gate );
    level notify( "mg_bridge_reached" );
}

// The Blundergat variant the player holds, or undefined. The fireplace and the forge take all four, in the remaster's
// order (MG.gsc:130-145): the Blundergat, the Sweeper, the Acid Gat, the Vitriolic Withering (a Pack-a-Punched one
// forges the Magmus Operandi).
mg_has_blundergat( player )
{
    if ( !isdefined( player ) || !is_player_valid( player ) )
        return undefined;

    foreach ( weapon in mg_blundergats() )
    {
        if ( player hasweapon( weapon ) )
            return weapon;
    }

    return undefined;
}

// The four Blundergat variants the fireplace and the forge take.
mg_blundergats()
{
    return array( "blundergat_zm", "blundergat_upgraded_zm", "blundersplat_zm", "blundersplat_upgraded_zm" );
}

mg_is_blundergat( weapon )
{
    return isdefined( weapon ) && isinarray( mg_blundergats(), weapon );
}

// The vanilla rule for "take a quest weapon" (zm_alcatraz_utility.gsc:264): the weapon in hand may be replaced only
// if it is a real gun, not a mine, equipment, the revive syringe or nothing.
mg_can_replace_current( player )
{
    current = player getcurrentweapon();

    if ( !isdefined( current ) || current == "none" )
        return 0;

    if ( is_placeable_mine( current ) || is_equipment( current ) )
        return 0;

    if ( isdefined( level.revive_tool ) && current == level.revive_tool )
        return 0;

    return 1;
}

mg_state_index( s )
{
    order = array( "locked", "ready", "souls", "pickup", "run", "forge", "done" );

    for ( i = 0; i < order.size; i++ )
    {
        if ( order[i] == s )
            return i;
    }

    return -1;
}

// self = player typing. Fabricates a state: gives a Blundergat when the state needs one, then asks each stage
// file to set up its props for that state.
mg_goto( state )
{
    if ( mg_state_index( state ) < 0 )
    {
        self mg_out( "MG: unknown state " + state + " (locked|ready|souls|pickup|run|forge|done)" );
        return;
    }

    level notify( "mg_goto" );

    // a tour in its press ends with the press on this notify (mg_press_show, mg_debug_tour), before it clears its
    // flag: cleared here, so `!mg tour` runs again
    foreach ( p in getplayers() )
        p.mg_touring = 0;

    wait 0.05;

    // run and forge carry a Blundergat's tempered gun or forge from one: one is given when the player has none
    if ( ( state == "run" || state == "forge" ) && !isdefined( mg_has_blundergat( self ) ) )
        self mg_give_weapon( "blundergat_zm" );

    mg_hearth_fabricate( state );
    self mg_run_fabricate( state );
    mg_forge_fabricate( state );
    mg_state_set( state );
    self mg_out( "MG: state fabricated: " + state );
}

mg_status_lines()
{
    l = [];
    l[l.size] = "MG " + level.mg_version + " | state " + level.mg_state + " | souls " + level.mg_souls + "/15";

    if ( isdefined( level.mg_carrier ) && isdefined( level.mg_carrier.name ) )
        l[l.size] = "carrier " + level.mg_carrier.name + " | temper left " + mg_temper_left_str();
    else
        l[l.size] = "no carrier";

    gate = mg_gate_flag();
    bridge = "-";

    if ( isdefined( gate ) )
        bridge = "" + flag( gate );

    l[l.size] = "bridge " + bridge + " | forge open " + is_true( level.mg_forge_open );
    return l;
}

mg_temper_left_str()
{
    // the clock stops as the Machine is powered (mg_run_timer)
    if ( isdefined( level.mg_carrier ) && is_true( level.mg_run_powered ) )
        return "stopped (Machine powered)";

    if ( isdefined( level.mg_carrier ) && isdefined( level.mg_carrier.mg_temper_left ) )
        return "" + int( level.mg_carrier.mg_temper_left ) + " s";

    return "-";
}
