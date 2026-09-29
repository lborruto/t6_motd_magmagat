#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_run;
#include scripts\zm\zm_prison\mg_weapon;

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
                    player.mg_forge_prompted = 0;
                }

                continue;
            }

            text = mg_forge_prompt_text( player );

            if ( !isdefined( text ) )
            {
                if ( is_true( player.mg_forge_prompted ) )
                {
                    player.mg_forge_prompted = 0;
                }

                continue;
            }

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
    open_owner = is_true( level.mg_forge_open ) && isdefined( mg_has_blundergat( player ) ) && !isdefined( mg_has_magma( player ) );

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
    level endon( "mg_goto" );

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
        mg_snd_near( "zmb_powerpanel_activate", pos, 800 );
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

    if ( is_true( level.mg_forge_open ) && isdefined( weapon ) && !isdefined( mg_has_magma( player ) ) )
        mg_forge_place( player, weapon, 0 );
}

// The gun goes on the generator, 5 s of ghosts, then it waits to be taken.
mg_forge_place( player, weapon, tempered )
{
    level endon( "end_game" );
    level endon( "mg_goto" );

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
    level.mg_forge_place_ents = [];
    level.mg_forge_place_ents[level.mg_forge_place_ents.size] = gun;
    mg_snd_near( "zmb_afterlife_shockbox_on", c.origin, 800 );

    // two ghosts circle the gun for 5 s
    g1 = mg_fx_loop( "ghost", c.origin + ( 40, 0, 20 ) );

    if ( isdefined( g1 ) )
        level.mg_forge_place_ents[level.mg_forge_place_ents.size] = g1;

    g2 = mg_fx_loop( "ghost", c.origin + ( -40, 0, 20 ) );

    if ( isdefined( g2 ) )
        level.mg_forge_place_ents[level.mg_forge_place_ents.size] = g2;

    smoke = mg_fx_loop( "smoke", c.origin );

    if ( isdefined( smoke ) )
        level.mg_forge_place_ents[level.mg_forge_place_ents.size] = smoke;

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
    mg_snd_near( "zmb_hellbox_open", c.origin, 800 );
    gun delete();
    gun = spawn_weapon_model( mg_magma_of( weapon ), undefined, c.origin - ( 0, 0, 10 ), c.angles );
    level.mg_forge_place_ents[level.mg_forge_place_ents.size] = gun;
    rise = mg_fx_loop( "forge_rise", c.origin - ( 0, 0, 6 ) );

    if ( isdefined( rise ) )
        level.mg_forge_place_ents[level.mg_forge_place_ents.size] = rise;

    mg_snd_near( "zmb_hellbox_slam_shake", c.origin, 800 );
    gun moveto( c.origin, 1.5, 0.3, 0.6 );
    gun rotateyaw( 360, 1.5, 0.3, 0.6 );
    wait 1.5;
    mg_fx_stop( rise );
    mg_fx_once( "ball_hit", c.origin );
    level.mg_forge_ready_gun = gun;
    level.mg_forge_ready_glow = mg_fx_loop( "glow", c.origin );
    level.mg_forge_busy = 0;
    level.mg_forge_place_ents = [];
}

// Take the Magmagat (the Magmus Operandi when a Sweeper was forged).
mg_forge_take( player )
{
    if ( !isdefined( level.mg_forge_ready_gun ) || !is_player_valid( player ) )
        return;

    weapon = level.mg_forge_gun_weapon;
    level.mg_forge_ready_gun delete();
    level.mg_forge_ready_gun = undefined;
    mg_fx_stop( level.mg_forge_ready_glow );
    level.mg_forge_ready_glow = undefined;
    level.mg_forge_gun_weapon = undefined;
    level.mg_forge_placer = undefined;
    player mg_weapon_grant( weapon );

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
    // a place() killed mid-ghosts by the goto notify leaves its entities to us
    if ( isdefined( level.mg_forge_place_ents ) )
    {
        foreach ( ent in level.mg_forge_place_ents )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.mg_forge_place_ents = [];

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
        level.mg_forge_ready_gun = spawn_weapon_model( "magmagat_zm", undefined, c.origin, c.angles );
        level.mg_forge_ready_glow = mg_fx_loop( "glow", c.origin );
    }
}
