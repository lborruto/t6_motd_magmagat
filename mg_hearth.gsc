#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_run;

// The fireplace: temper prompt, the gun in the fire, 18 orbs, three skulls, the 30 s pickup (spec section 3).

mg_hearth_init()
{
    level.mg_orbs = 0;
    level.mg_skulls = [];
    level.mg_hearth_session = 0;

    for ( i = 1; i <= 3; i++ )
    {
        c = mg_coord( "MG_SKULL_" + i );
        skull = spawn( "script_model", c.origin );
        skull setmodel( mg_model( "skull" ) );
        skull.angles = c.angles;
        level.mg_skulls[i - 1] = skull;
    }

    level thread mg_hearth_fire();
    level thread mg_hearth_prompt_loop();
    level thread mg_hearth_state_watch();
}

// The hearth fire: normal flame in every state but pickup / run (blue) and locked (nothing extra).
mg_hearth_fire()
{
    level endon( "end_game" );
    pos = mg_coord( "MG_HEARTH" ).origin;

    while ( true )
    {
        if ( isdefined( level.mg_hearth_fx ) )
            mg_fx_stop( level.mg_hearth_fx );

        if ( mg_state_is( "pickup" ) )
            level.mg_hearth_fx = mg_fx_loop( "blue_fire", pos );
        else if ( mg_state_is( "souls" ) )
            level.mg_hearth_fx = mg_fx_loop( "fire_md", pos );
        else
            level.mg_hearth_fx = mg_fx_loop( "fire_sm", pos );

        if ( isdefined( level.mg_hearth_fx ) )
            level thread mg_fx_keepalive( level.mg_hearth_fx );

        level waittill( "mg_state" );
    }
}

// Prompt + use press at the hearth, polled: "Temper the Blundergat" (ready, holding one), "Take the souls to the
// fire" (souls, 18 orbs), "Take the tempered Blundergat" (pickup).
mg_hearth_prompt_loop()
{
    level endon( "end_game" );
    use = mg_coord( "MG_HEARTH_USE" ).origin;

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || distancesquared( player.origin, use ) > 96 * 96 )
            {
                if ( is_true( player.mg_hearth_prompted ) )
                {
                    player mg_prompt( 0, undefined );
                    player.mg_hearth_prompted = 0;
                }

                continue;
            }

            text = undefined;

            if ( mg_state_is( "ready" ) && isdefined( mg_has_blundergat( player ) ) )
                text = "Press [{+activate}] to temper the Blundergat";
            else if ( mg_state_is( "souls" ) && level.mg_orbs >= 18 )
                text = "Press [{+activate}] to give the souls to the fire";
            else if ( mg_state_is( "pickup" ) )
                text = "Press [{+activate}] to take the tempered Blundergat";

            if ( !isdefined( text ) )
            {
                if ( is_true( player.mg_hearth_prompted ) )
                {
                    player mg_prompt( 0, undefined );
                    player.mg_hearth_prompted = 0;
                }

                continue;
            }

            player mg_prompt( 1, text );
            player.mg_hearth_prompted = 1;

            if ( !player mg_press_use() )
                continue;

            if ( mg_state_is( "ready" ) )
                level thread mg_hearth_start( player );
            else if ( mg_state_is( "souls" ) )
                level thread mg_hearth_deposit( player );
            else if ( mg_state_is( "pickup" ) )
                level thread mg_hearth_take( player );
        }
    }
}

// ready -> souls: the gun leaves the hand and lies in the fire.
mg_hearth_start( player )
{
    weapon = mg_has_blundergat( player );

    if ( !isdefined( weapon ) || !mg_state_is( "ready" ) )
        return;

    player takeweapon( weapon );
    primaries = player getweaponslistprimaries();

    if ( primaries.size > 0 )
        player switchtoweapon( primaries[0] );

    level.mg_hearth_weapon = weapon;
    level.mg_hearth_owner = player;
    level.mg_orbs = 0;
    c = mg_coord( "MG_HEARTH" );
    level.mg_hearth_gun = spawn_weapon_model( weapon, undefined, c.origin, c.angles );
    player mg_snd_player( "zmb_powerpanel_activate" );
    level.mg_hearth_session++;
    mg_death_listen_add( "mg_hearth", ::mg_hearth_zombie_died );
    mg_state_set( "souls" );
    level thread mg_hearth_office_watch();
    level thread mg_hearth_round_watch();
}

// souls: a round that ends with no soul collected at all sends the gun back (spec section 3). The watcher belongs
// to ONE souls session (token): a stale instance parked on the waittill must not reset a later session.
mg_hearth_round_watch()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    my = level.mg_hearth_session;

    while ( mg_state_is( "souls" ) && level.mg_hearth_session == my )
    {
        level waittill( "end_of_round" );

        if ( level.mg_hearth_session != my )
            return;

        if ( mg_state_is( "souls" ) && level.mg_orbs == 0 )
        {
            mg_debug_print( "MG: the round ended with no soul collected: the Blundergat is lost" );
            mg_hearth_reset( 0 );
            return;
        }
    }
}

// souls: a kill by a player inside the office, of a zombie inside the office, drops an orb.
mg_hearth_zombie_died( zombie )
{
    if ( !mg_state_is( "souls" ) || level.mg_orbs >= 18 )
        return;

    if ( !isdefined( zombie ) || !isdefined( zombie.attacker ) || !isplayer( zombie.attacker ) )
        return;

    if ( !mg_ent_in_office( zombie ) || !mg_player_in_office( zombie.attacker ) )
        return;

    level thread mg_orb_spawn( zombie.origin + ( 0, 0, 30 ) );
}

// An orb: rises 30 units, lives 20 s, collected by any player within 48 units.
mg_orb_spawn( pos )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    orb = mg_fx_loop( "soul", pos );

    if ( !isdefined( orb ) )
        return;

    if ( !isdefined( level.mg_orb_ents ) )
        level.mg_orb_ents = [];

    level.mg_orb_ents[level.mg_orb_ents.size] = orb;
    orb moveto( pos + ( 0, 0, 30 ), 1 );
    start = gettime();
    taker = undefined;

    while ( gettime() - start < 20000 && mg_state_is( "souls" ) )
    {
        foreach ( player in getplayers() )
        {
            if ( is_player_valid( player ) && distancesquared( player.origin + ( 0, 0, 40 ), orb.origin ) < 48 * 48 )
            {
                taker = player;
                break;
            }
        }

        if ( isdefined( taker ) )
            break;

        wait 0.1;
    }

    // mg_orbs_clear (a reset while the orb flew) may have deleted it under us
    if ( !isdefined( orb ) )
        return;

    from = orb.origin;
    mg_fx_stop( orb );

    if ( !isdefined( taker ) || level.mg_orbs >= 18 )
        return;

    level.mg_orbs++;
    taker mg_snd_player( "zmb_powerup_grabbed_3p" );
    mg_fx_once( "soul_hit", taker.origin + ( 0, 0, 40 ) );
    level thread mg_trail( "soul_trail", from, mg_coord( "MG_HEARTH" ).origin + ( 0, 0, 20 ), 900 );
    mg_debug_print( "MG: orb " + level.mg_orbs + "/18 by " + taker.name );

    if ( level.mg_orbs == 6 || level.mg_orbs == 12 || level.mg_orbs == 18 )
        mg_skull_light( level.mg_orbs / 6 - 1 );
}

// skull index 0..2 turns blue and stays so until the hearth resets
mg_skull_light( idx )
{
    skull = level.mg_skulls[idx];

    if ( !isdefined( skull ) )
        return;

    if ( !isdefined( level.mg_skull_fx ) )
        level.mg_skull_fx = [];

    if ( isdefined( level.mg_skull_fx[idx] ) )
        mg_fx_stop( level.mg_skull_fx[idx] );

    ent = mg_fx_loop( "soul_full", skull.origin + ( 0, 0, 6 ) );
    level.mg_skull_fx[idx] = ent;

    if ( isdefined( ent ) )
        level thread mg_fx_keepalive( ent );

    mg_snd_near( "evt_wolfhead_eat", skull.origin, 600 );
}

mg_skulls_dark()
{
    if ( !isdefined( level.mg_skull_fx ) )
        return;

    foreach ( ent in level.mg_skull_fx )
        mg_fx_stop( ent );

    level.mg_skull_fx = [];
}

// souls: nobody in the office for 5 s (warning at 3 s) = the gun is lost, back to ready.
mg_hearth_office_watch()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    empty_since = undefined;
    warned = 0;

    while ( mg_state_is( "souls" ) )
    {
        wait 0.5;
        inside = 0;

        foreach ( player in getplayers() )
        {
            if ( mg_player_in_office( player ) )
                inside = 1;
        }

        if ( inside )
        {
            empty_since = undefined;
            warned = 0;
            continue;
        }

        if ( !isdefined( empty_since ) )
            empty_since = gettime();

        if ( !warned && gettime() - empty_since >= 3000 )
        {
            warned = 1;
            mg_debug_print( "MG: office empty, 2 s before the fire takes the gun" );
            mg_snd_near( "zmb_no_cha_ching", mg_coord( "MG_HEARTH" ).origin, 1500 );
        }

        if ( gettime() - empty_since >= 5000 )
        {
            mg_debug_print( "MG: office left during the souls: the Blundergat is lost" );
            mg_hearth_reset( 0 );
            return;
        }
    }
}

// souls -> pickup: 18 orbs deposited, the blue gun rises, 30 s to take it
mg_hearth_deposit( player )
{
    if ( !mg_state_is( "souls" ) || level.mg_orbs < 18 )
        return;

    mg_death_listen_remove( "mg_hearth" );
    mg_state_set( "pickup" );
    player mg_snd_player( "zmb_afterlife_panel_on" );

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun moveto( level.mg_hearth_gun.origin + ( 0, 0, 14 ), 3 );

    level thread mg_hearth_pickup_window();
}

mg_hearth_pickup_window()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    wait 30;

    if ( !mg_state_is( "pickup" ) )
        return;

    mg_debug_print( "MG: tempered Blundergat not taken in 30 s: it is gone, fireplace reset" );
    owner = level.mg_hearth_owner;
    weapon = level.mg_hearth_weapon;
    mg_hearth_reset( 0 );

    if ( isdefined( owner ) && is_player_valid( owner ) && isdefined( weapon ) && !isdefined( mg_has_blundergat( owner ) ) )
    {
        owner giveweapon( weapon );
        owner switchtoweapon( weapon );
    }
}

// pickup -> run: the taker gets the tempered gun (two-primaries rule as vanilla take_old_weapon_and_give_reward)
mg_hearth_take( player )
{
    if ( !mg_state_is( "pickup" ) || !is_player_valid( player ) )
        return;

    weapon = level.mg_hearth_weapon;

    if ( !isdefined( weapon ) )
        weapon = "blundergat_zm";

    current = player getcurrentweapon();
    primaries = player getweaponslistprimaries();

    if ( !player hasweapon( weapon ) )
    {
        if ( isdefined( primaries ) && primaries.size >= 2 && mg_can_replace_current( player ) )
            player takeweapon( current );

        player giveweapon( weapon );
    }

    player switchtoweapon( weapon );

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun delete();

    level.mg_hearth_gun = undefined;
    mg_skulls_dark();
    level.mg_orbs = 0;
    player mg_snd_player( "zmb_afterlife_trigger_activate" );
    mg_run_start( player, weapon );
}

mg_orbs_clear()
{
    if ( isdefined( level.mg_orb_ents ) )
    {
        foreach ( orb in level.mg_orb_ents )
        {
            if ( isdefined( orb ) )
                orb delete();
        }
    }

    level.mg_orb_ents = [];
}

// Back to ready. give_back 1 hands the laid gun back to its owner (used by fabrications), 0 loses it.
mg_hearth_reset( give_back )
{
    mg_orbs_clear();
    mg_death_listen_remove( "mg_hearth" );

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun delete();

    level.mg_hearth_gun = undefined;
    mg_skulls_dark();
    level.mg_orbs = 0;

    if ( give_back && isdefined( level.mg_hearth_owner ) && is_player_valid( level.mg_hearth_owner ) && isdefined( level.mg_hearth_weapon ) )
    {
        level.mg_hearth_owner giveweapon( level.mg_hearth_weapon );
        level.mg_hearth_owner switchtoweapon( level.mg_hearth_weapon );
    }

    level.mg_hearth_weapon = undefined;
    level.mg_hearth_owner = undefined;

    if ( !mg_state_is( "done" ) )
        mg_state_set( "ready" );
}

// A failed run (Task 6) or the forge (Task 7) tell the hearth what to do through the state notify.
mg_hearth_state_watch()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "mg_state", s );

        if ( s == "ready" && level.mg_orbs > 0 )
        {
            mg_skulls_dark();
            level.mg_orbs = 0;
        }
    }
}

// !mg goto support: builds what the asked state expects from the hearth.
mg_hearth_fabricate( state )
{
    mg_orbs_clear();
    mg_death_listen_remove( "mg_hearth" );

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun delete();

    level.mg_hearth_gun = undefined;
    mg_skulls_dark();
    level.mg_orbs = 0;

    if ( state == "souls" || state == "pickup" )
    {
        c = mg_coord( "MG_HEARTH" );
        level.mg_hearth_weapon = "blundergat_zm";
        level.mg_hearth_gun = spawn_weapon_model( "blundergat_zm", undefined, c.origin, c.angles );
    }

    if ( state == "souls" )
    {
        level.mg_hearth_session++;
        mg_death_listen_add( "mg_hearth", ::mg_hearth_zombie_died );
        level thread mg_hearth_office_watch_delayed();
    }

    if ( state == "pickup" )
    {
        level.mg_orbs = 18;
        mg_skull_light( 0 );
        mg_skull_light( 1 );
        mg_skull_light( 2 );
        level.mg_hearth_gun moveto( level.mg_hearth_gun.origin + ( 0, 0, 14 ), 3 );
        level thread mg_hearth_pickup_window();
    }
}

// the state is set right after fabrication; the watcher must start after that
mg_hearth_office_watch_delayed()
{
    level endon( "mg_goto" );
    wait 0.1;
    level thread mg_hearth_office_watch();
    level thread mg_hearth_round_watch();
}

