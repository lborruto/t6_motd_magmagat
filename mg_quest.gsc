#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_hearth;
#include scripts\zm\zm_prison\mg_run;
#include scripts\zm\zm_prison\mg_forge;

// The quest state machine. States, in order: locked, ready, souls, pickup, run, forge, done (spec section 3).

mg_quest_init()
{
    level.mg_state = "locked";
    level.mg_orbs = 0;
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

// ready when the bridge has been reached once (vanilla flag set when the plane lands there). The gate waits for our
// own "mg_bridge_reached": the vanilla flag sends it in play, `!mg bridge` sends it to test the gate (setting the
// vanilla flag by hand would also open the bridge's spawn zone).
mg_bridge_gate()
{
    level endon( "end_game" );

    if ( !flag_exists( "activate_player_zone_bridge" ) )
        mg_debug_print( "MG: flag activate_player_zone_bridge missing, the fireplace opens at once" );
    else
    {
        level thread mg_bridge_flag_watch();
        level waittill( "mg_bridge_reached" );
    }

    // every "mg_bridge_reached" opens a locked fireplace (a `!mg goto locked` can be undone by `!mg bridge`)
    while ( true )
    {
        if ( mg_state_is( "locked" ) )
        {
            mg_state_set( "ready" );
            mg_debug_print( "MG: the bridge was reached, the fireplace takes a Blundergat" );
        }

        level waittill( "mg_bridge_reached" );
    }
}

mg_bridge_flag_watch()
{
    level endon( "end_game" );
    level endon( "mg_bridge_reached" );
    flag_wait( "activate_player_zone_bridge" );
    level notify( "mg_bridge_reached" );
}

// The Blundergat variant the player holds, or undefined (Sweeper counts, the Acid Gat does not).
mg_has_blundergat( player )
{
    if ( !isdefined( player ) || !is_player_valid( player ) )
        return undefined;

    if ( player hasweapon( "blundergat_upgraded_zm" ) )
        return "blundergat_upgraded_zm";

    if ( player hasweapon( "blundergat_zm" ) )
        return "blundergat_zm";

    return undefined;
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
    order = [];
    order[0] = "locked";
    order[1] = "ready";
    order[2] = "souls";
    order[3] = "pickup";
    order[4] = "run";
    order[5] = "forge";
    order[6] = "done";

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
    wait 0.05;

    if ( state == "souls" || state == "pickup" || state == "run" || state == "forge" )
    {
        if ( !isdefined( mg_has_blundergat( self ) ) && state != "souls" && state != "pickup" )
        {
            self giveweapon( "blundergat_zm" );
            self switchtoweapon( "blundergat_zm" );
        }
    }

    mg_hearth_fabricate( state );
    self mg_run_fabricate( state );
    mg_forge_fabricate( state );
    mg_state_set( state );
    self mg_out( "MG: state fabricated: " + state );
}

mg_status_lines()
{
    l = [];
    l[l.size] = "MG " + level.mg_version + " | state " + level.mg_state + " | orbs " + level.mg_orbs + "/18";

    if ( isdefined( level.mg_carrier ) && isdefined( level.mg_carrier.name ) )
        l[l.size] = "carrier " + level.mg_carrier.name + " | temper left " + mg_temper_left_str();
    else
        l[l.size] = "no carrier";

    l[l.size] = "bridge " + is_true( level.flag["activate_player_zone_bridge"] ) + " | forge open " + is_true( level.mg_forge_open );
    return l;
}

mg_temper_left_str()
{
    if ( isdefined( level.mg_carrier ) && isdefined( level.mg_carrier.mg_temper_left ) )
        return "" + int( level.mg_carrier.mg_temper_left ) + " s";

    return "-";
}
