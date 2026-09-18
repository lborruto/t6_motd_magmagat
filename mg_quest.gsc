#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;

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

// ready when the bridge has been visited once (vanilla flag set when the plane lands there)
mg_bridge_gate()
{
    level endon( "end_game" );

    if ( !flag_exists( "activate_player_zone_bridge" ) )
    {
        mg_debug_print( "MG: flag activate_player_zone_bridge missing, the fireplace opens at once" );
    }
    else
        flag_wait( "activate_player_zone_bridge" );

    if ( mg_state_is( "locked" ) )
        mg_state_set( "ready" );
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

// TEMPORARY stubs, each replaced by its stage file
mg_hearth_fabricate( state )
{
}

mg_run_fabricate( state )
{
}

mg_forge_fabricate( state )
{
}
