#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_run;

// The fireplace, after BO4 Blood of the Dead (zm_escape_weap_quest_mg.gsc): the gun in the fire, 15 souls from zombies
// that die in the Warden's Office, three skulls (5 / 10 / 15), the placer's 10 s / 30 s away rule, the deposit (the
// skulls drain, a flare, the blue fire), 30 s to take the tempered gun.

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

        if ( isdefined( level.mg_hearth_portal ) )
        {
            mg_fx_once( "hearth_close", level.mg_hearth_portal.origin );
            mg_fx_stop( level.mg_hearth_portal );
            level.mg_hearth_portal = undefined;
        }

        level.mg_hearth_fx = mg_fx_loop( "hearth_fire", pos );

        if ( isdefined( level.mg_hearth_fx ) )
        {
            level.mg_hearth_fx playloopsound( "amb_fire_med" );
            level thread mg_fx_keepalive( level.mg_hearth_fx );
        }

        // the tempered gun waits in the hell portal of the wolf heads, facing the room
        if ( mg_state_is( "pickup" ) )
        {
            out = vectortoangles( mg_coord( "MG_HEARTH_USE" ).origin - pos );
            level.mg_hearth_portal = mg_fx_loop( "hearth_blue", pos, ( 0, out[1], 0 ) );
            mg_snd_near( "evt_wolfhead_spawn", pos, 1200 );

            if ( isdefined( level.mg_hearth_portal ) )
                level.mg_hearth_portal playloopsound( "evt_wolfhead_fire_loop" );
        }

        level waittill( "mg_state" );
    }
}

// Prompt + use press at the hearth, polled: "Temper the Blundergat" (ready, holding one), "Take the souls to the
// fire" (souls, 15 orbs), "Take the tempered Blundergat" (pickup).
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
                    player.mg_hearth_prompted = 0;
                }

                continue;
            }

            text = undefined;

            if ( mg_state_is( "ready" ) && isdefined( mg_has_blundergat( player ) ) )
                text = "Press [{+activate}] to temper the Blundergat";
            else if ( mg_state_is( "souls" ) && level.mg_orbs >= 15 )
                text = "Press [{+activate}] to give the souls to the fire";
            else if ( mg_state_is( "pickup" ) )
                text = "Press [{+activate}] to take the tempered Blundergat";

            if ( !isdefined( text ) )
            {
                if ( is_true( player.mg_hearth_prompted ) )
                {
                    player.mg_hearth_prompted = 0;
                }

                continue;
            }

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
    player mg_snd_player( "zmb_hellbox_lock" );
    mg_snd_near( "mg_flame_burst", c.origin, 1500 ); // the fire takes the gun (the remaster's flame burst)
    // the lockdown's laugh (the BO3 remaster)
    mg_snd_near( "zmb_easteregg_laugh", c.origin, 2000 );
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

// souls: a zombie killed by a player that dies inside the office drops a soul (BO4: the zombie must be in the
// house, the killer may stand anywhere).
mg_hearth_zombie_died( zombie )
{
    if ( !mg_state_is( "souls" ) || level.mg_orbs >= 15 )
        return;

    if ( !isdefined( zombie ) || !isdefined( zombie.attacker ) || !isplayer( zombie.attacker ) )
    {
        mg_debug_print( "MG: kill not counted: no player attacker" );
        return;
    }

    if ( !mg_ent_in_office( zombie ) )
    {
        mg_debug_print( "MG: kill not counted: the zombie died outside zone_warden_office" );
        return;
    }

    mg_debug_print( "MG: soul released at " + mg_vec_str( zombie.origin ) );
    level thread mg_orb_spawn( zombie.origin + ( 0, 0, 22 ) );
}

// A soul (BO4): it streaks out of the body, then rises 36 units over 3 s and fades if nobody walks into it
// (32 units around, up to 96 above the feet). Taken, it flies to the skull it fills and bursts in; the skull lights
// when its fifth soul arrives.
mg_orb_spawn( pos )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    mg_fx_once( "soul_release", pos );
    mg_snd_near( "mg_soul_kill", pos, 1200 ); // the remaster's soul kill
    orb = mg_fx_loop( "soul", pos );

    if ( !isdefined( orb ) )
        return;

    orb playloopsound( "mg_soul_loop" );

    if ( !isdefined( level.mg_orb_ents ) )
        level.mg_orb_ents = [];

    level.mg_orb_ents[level.mg_orb_ents.size] = orb;
    orb moveto( pos + ( 0, 0, 36 ), 3 );
    start = gettime();
    taker = undefined;

    while ( gettime() - start < 3000 && mg_state_is( "souls" ) && isdefined( orb ) )
    {
        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) )
                continue;

            dz = orb.origin[2] - player.origin[2];

            if ( dz > -16 && dz < 96 && distance2dsquared( player.origin, orb.origin ) < 32 * 32 )
            {
                taker = player;
                break;
            }
        }

        if ( isdefined( taker ) )
            break;

        wait 0.05;
    }

    // mg_orbs_clear (a reset while the orb flew) may have deleted it under us
    if ( !isdefined( orb ) )
        return;

    from = orb.origin;
    mg_fx_stop( orb );

    if ( !isdefined( taker ) || level.mg_orbs >= 15 )
    {
        // the soul fades
        mg_snd_near( "zmb_afterlife_zombie_warp_out", from, 600 );
        return;
    }

    level.mg_orbs++;
    n = level.mg_orbs;
    taker mg_snd_player( "zmb_quest_forcefield_end" );
    mg_fx_once( "soul_hit", from );
    mg_debug_print( "MG: soul " + n + "/15 by " + taker.name );
    idx = int( ( n - 1 ) / 5 );
    target = mg_coord( "MG_HEARTH" ).origin + ( 0, 0, 20 );

    if ( isdefined( level.mg_skulls[idx] ) )
        target = level.mg_skulls[idx].origin + ( 0, 0, 4 );

    session = level.mg_hearth_session;
    mg_trail( "soul_trail", from, target, 700 );
    mg_fx_once( "soul_arrive", target );
    mg_snd_near( "evt_soulsuck_body", target, 900 );

    if ( n % 5 == 0 && mg_state_is( "souls" ) && level.mg_hearth_session == session && level.mg_orbs >= n )
        mg_skull_light( idx );
}

// skull index 0..2 lights (BO4: the skull turns into the afterlife skull, blue fire on it) until the hearth resets
mg_skull_light( idx )
{
    skull = level.mg_skulls[idx];

    if ( !isdefined( skull ) )
        return;

    if ( !isdefined( level.mg_skull_fx ) )
        level.mg_skull_fx = [];

    if ( isdefined( level.mg_skull_fx[idx] ) )
        mg_fx_stop( level.mg_skull_fx[idx] );

    skull setmodel( mg_model( "skull_lit" ) );
    ent = mg_fx_loop( "soul_full", skull.origin + ( 0, 0, 2 ) );
    level.mg_skull_fx[idx] = ent;

    if ( isdefined( ent ) )
    {
        // a full dream catcher's glow and hum
        ent playloopsound( "evt_runeglow_loop" );
        level thread mg_fx_keepalive( ent );
    }

    // the third skull has its own sound (BO4)
    if ( idx == 2 )
        mg_snd_near( "zmb_hellbox_unlock", skull.origin, 1200 );
    else
        mg_snd_near( "zmb_afterlife_zombie_warp_in", skull.origin, 900 );
}

mg_skulls_dark()
{
    foreach ( skull in level.mg_skulls )
    {
        if ( isdefined( skull ) )
            skull setmodel( mg_model( "skull" ) );
    }

    if ( !isdefined( level.mg_skull_fx ) )
        return;

    foreach ( ent in level.mg_skull_fx )
        mg_fx_stop( ent );

    level.mg_skull_fx = [];
}

// souls: the player who placed the gun is watched once a second (BO4). 10 s out of the office with souls taken:
// the souls are lost (skulls dark, count 0). 30 s out: the fire lets go and the gun is lost. Dying or leaving the
// game loses it too.
mg_hearth_office_watch()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    my = level.mg_hearth_session;
    away = 0;

    while ( mg_state_is( "souls" ) && level.mg_hearth_session == my )
    {
        wait 1;
        placer = level.mg_hearth_owner;

        if ( !isdefined( placer ) || !isalive( placer ) || is_true( placer.sessionstate == "spectator" ) )
        {
            mg_debug_print( "MG: the placer is gone: the Blundergat is lost" );
            mg_hearth_fail();
            return;
        }

        if ( mg_player_in_office( placer ) )
        {
            away = 0;
            continue;
        }

        away++;

        if ( away == 10 && level.mg_orbs > 0 )
        {
            mg_debug_print( "MG: the placer is 10 s out of the office: the souls are lost" );
            mg_orbs_clear();
            mg_skulls_dark();
            level.mg_orbs = 0;
            mg_snd_near( "zmb_quest_nixie_fail", mg_coord( "MG_HEARTH" ).origin, 1500 );
        }

        if ( away >= 30 )
        {
            mg_debug_print( "MG: the placer is 30 s out of the office: the Blundergat is lost" );
            mg_hearth_fail();
            return;
        }
    }
}

// The fire lets go: the gun is lost, the laugh, back to ready.
mg_hearth_fail()
{
    pos = mg_coord( "MG_HEARTH" ).origin;
    mg_snd_near( "zmb_quest_nixie_fail", pos, 1500 );
    mg_snd_near( "mg_brutus_laugh", pos, 2500 ); // the warden laughs at the lost gun
    mg_hearth_reset( 0 );
}

// souls -> pickup (BO4): the skulls drain one by one into the fire, 0.5 s apart; a flare-up; 1 s later the fire
// turns blue (the hell portal) and the tempered gun rises; 30 s to take it.
mg_hearth_deposit( player )
{
    if ( !mg_state_is( "souls" ) || level.mg_orbs < 15 || is_true( level.mg_hearth_depositing ) )
        return;

    level.mg_hearth_depositing = 1;
    mg_death_listen_remove( "mg_hearth" );
    pos = mg_coord( "MG_HEARTH" ).origin;
    player mg_snd_player( "zmb_hellbox_unlock" );

    for ( i = 0; i < level.mg_skulls.size; i++ )
    {
        skull = level.mg_skulls[i];

        if ( isdefined( level.mg_skull_fx ) && isdefined( level.mg_skull_fx[i] ) )
            mg_fx_stop( level.mg_skull_fx[i] );

        if ( isdefined( skull ) )
        {
            skull setmodel( mg_model( "skull" ) );
            level thread mg_trail( "soul_trail", skull.origin + ( 0, 0, 4 ), pos + ( 0, 0, 12 ), 500 );
            mg_snd_near( "evt_soulsuck_body", skull.origin, 900 );
        }

        wait 0.5;
    }

    level.mg_skull_fx = [];
    mg_fx_once( "hearth_flare", pos );
    mg_snd_near( "mg_flame_burst", pos, 1500 );
    mg_snd_near( "zmb_hellbox_slam_shake", pos, 1500 );
    wait 1;
    level.mg_hearth_depositing = 0;

    if ( !mg_state_is( "souls" ) )
        return;

    mg_state_set( "pickup" );

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun moveto( level.mg_hearth_gun.origin + ( 0, 0, 14 ), 3 );

    level thread mg_hearth_pickup_window();
}

// 30 s to take the tempered gun, or it is lost (BO4: it vanishes with a fail sound).
mg_hearth_pickup_window()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    wait 30;

    if ( !mg_state_is( "pickup" ) )
        return;

    mg_debug_print( "MG: the tempered Blundergat was not taken in 30 s: it is lost" );

    if ( isdefined( level.mg_hearth_gun ) )
        mg_fx_once( "gun_vanish", level.mg_hearth_gun.origin );

    mg_hearth_fail();
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
        level.mg_orbs = 15;
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

