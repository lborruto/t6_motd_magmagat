#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_run;

// The forge: the dock Generator Room's large generator. Power it (one press), place the tempered gun, 5 s of
// ghosts, take the Magmagat. Once forged, any Blundergat placed converts (level.mg_forge_open).

mg_forge_init()
{
    level.mg_forge_powered = 0;
    level.mg_forge_open = 0;
    level.mg_forge_busy = 0;
    level thread mg_forge_prompt_loop();
}

mg_forge_near( player )
{
    return isdefined( player ) && distancesquared( player.origin, mg_coord( "MG_FORGE" ).origin ) < 96 * 96;
}

mg_forge_prompt_loop()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || !mg_forge_near( player ) )
            {
                if ( is_true( player.mg_forge_prompted ) )
                {
                    player mg_prompt( 0, undefined );
                    player.mg_forge_prompted = 0;
                }

                continue;
            }

            text = mg_forge_prompt_text( player );

            if ( !isdefined( text ) )
            {
                if ( is_true( player.mg_forge_prompted ) )
                {
                    player mg_prompt( 0, undefined );
                    player.mg_forge_prompted = 0;
                }

                continue;
            }

            player mg_prompt( 1, text );
            player.mg_forge_prompted = 1;

            if ( player mg_press_use() )
                level thread mg_forge_press( player );
        }
    }
}

// What the forge offers this player right now, or undefined.
mg_forge_prompt_text( player )
{
    if ( is_true( level.mg_forge_busy ) )
        return undefined;

    if ( isdefined( level.mg_forge_ready_gun ) )
        return "Press [{+activate}] to take the Magmagat";

    carrying = mg_state_is( "run" ) && isdefined( level.mg_carrier ) && level.mg_carrier == player;
    open_owner = is_true( level.mg_forge_open ) && isdefined( mg_has_blundergat( player ) ) && !is_true( player.mg_magma_any );

    if ( !carrying && !open_owner )
        return undefined;

    if ( !is_true( level.mg_forge_powered ) )
        return "Press [{+activate}] to power the forge";

    if ( carrying )
        return "Press [{+activate}] to place the tempered Blundergat";

    return "Press [{+activate}] to place the Blundergat";
}

mg_forge_press( player )
{
    if ( is_true( level.mg_forge_busy ) )
        return;

    if ( isdefined( level.mg_forge_ready_gun ) )
    {
        mg_forge_take( player );
        return;
    }

    if ( !is_true( level.mg_forge_powered ) )
    {
        level.mg_forge_busy = 1;
        level.mg_forge_powered = 1;
        pos = mg_coord( "MG_FORGE_GUN" ).origin;
        mg_fx_once( "sparks", pos );
        mg_snd_near( "zmb_quest_generator_panel_power", pos, 800 );
        wait 2;
        level.mg_forge_busy = 0;
        return;
    }

    carrying = mg_state_is( "run" ) && isdefined( level.mg_carrier ) && level.mg_carrier == player;

    if ( carrying )
    {
        mg_forge_place( player, level.mg_run_weapon, 1 );
        return;
    }

    weapon = mg_has_blundergat( player );

    if ( is_true( level.mg_forge_open ) && isdefined( weapon ) && !is_true( player.mg_magma_any ) )
        mg_forge_place( player, weapon, 0 );
}

// The gun goes on the generator, 5 s of ghosts, then it waits to be taken.
mg_forge_place( player, weapon, tempered )
{
    level endon( "end_game" );

    if ( !isdefined( weapon ) || !player hasweapon( weapon ) )
        return;

    level.mg_forge_busy = 1;
    player takeweapon( weapon );
    primaries = player getweaponslistprimaries();

    if ( primaries.size > 0 )
        player switchtoweapon( primaries[0] );

    if ( tempered )
    {
        mg_run_end_ok();
        mg_state_set( "forge" );
    }

    c = mg_coord( "MG_FORGE_GUN" );
    gun = spawn_weapon_model( weapon, undefined, c.origin, c.angles );
    level.mg_forge_gun_weapon = weapon;
    level.mg_forge_placer = player;
    mg_snd_near( "zmb_afterlife_object_apparate", c.origin, 800 );

    // two ghosts circle the gun for 5 s
    g1 = mg_fx_loop( "ghost", c.origin + ( 40, 0, 20 ) );
    g2 = mg_fx_loop( "ghost", c.origin + ( -40, 0, 20 ) );
    smoke = mg_fx_loop( "smoke", c.origin );

    for ( i = 0; i < 10; i++ )
    {
        a = i * 36;
        b = a + 180;

        if ( isdefined( g1 ) )
            g1 moveto( c.origin + ( cos( a ) * 40, sin( a ) * 40, 20 ), 0.5 );

        if ( isdefined( g2 ) )
            g2 moveto( c.origin + ( cos( b ) * 40, sin( b ) * 40, 20 ), 0.5 );

        wait 0.5;
    }

    mg_fx_stop( g1 );
    mg_fx_stop( g2 );
    mg_fx_stop( smoke );
    mg_fx_once( "explo", c.origin );
    mg_snd_near( "zmb_afterlife_object_disapparate", c.origin, 800 );
    level.mg_forge_ready_gun = gun;
    level.mg_forge_ready_glow = mg_fx_loop( "glow", c.origin );
    level.mg_forge_busy = 0;
}

// Take the Magmagat: the same weapon name, with the personality.
mg_forge_take( player )
{
    if ( !isdefined( level.mg_forge_ready_gun ) || !is_player_valid( player ) )
        return;

    weapon = level.mg_forge_gun_weapon;
    current = player getcurrentweapon();
    primaries = player getweaponslistprimaries();

    if ( !player hasweapon( weapon ) )
    {
        if ( isdefined( primaries ) && primaries.size >= 2 && isdefined( current ) && current != "none" )
            player takeweapon( current );

        player giveweapon( weapon );
    }

    player switchtoweapon( weapon );
    player givemaxammo( weapon );
    level.mg_forge_ready_gun delete();
    level.mg_forge_ready_gun = undefined;
    mg_fx_stop( level.mg_forge_ready_glow );
    level.mg_forge_ready_glow = undefined;
    level.mg_forge_gun_weapon = undefined;
    level.mg_forge_placer = undefined;
    mg_weapon_grant( player, weapon );

    if ( !mg_state_is( "done" ) )
    {
        level.mg_forge_open = 1;
        mg_state_set( "done" );
        mg_debug_print( "MG: Magmagat forged by " + player.name + "; the forge stays open for any Blundergat" );
    }
}

// self = player typing !mg goto
mg_forge_fabricate( state )
{
    if ( isdefined( level.mg_forge_ready_gun ) )
        level.mg_forge_ready_gun delete();

    level.mg_forge_ready_gun = undefined;
    mg_fx_stop( level.mg_forge_ready_glow );
    level.mg_forge_ready_glow = undefined;
    level.mg_forge_busy = 0;
    level.mg_forge_powered = ( state == "forge" || state == "done" );
    level.mg_forge_open = ( state == "done" );

    if ( state == "forge" )
    {
        c = mg_coord( "MG_FORGE_GUN" );
        level.mg_forge_gun_weapon = "blundergat_zm";
        level.mg_forge_ready_gun = spawn_weapon_model( "blundergat_zm", undefined, c.origin, c.angles );
        level.mg_forge_ready_glow = mg_fx_loop( "glow", c.origin );
    }
}

// TEMPORARY stub, replaced by mg_weapon.gsc in Task 8
mg_weapon_grant( player, weapon )
{
}
