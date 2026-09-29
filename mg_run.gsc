#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_forge;
#include scripts\zm\zm_prison\mg_weapon;

// The temper run, after BO4 and the BO3 remaster: 25 s of flame, a shot spends it all, each of the five barrels refills it to full ONCE per run
// (it burns while a tempered gun is out and goes out once spent), the flame flickers in the last 5 s, switching
// weapon or going down ends it (the player keeps the Blundergat: back to the fireplace).

mg_run_init()
{
    level.mg_barrels = [];

    for ( i = 1; i <= 5; i++ )
    {
        c = mg_coord( "MG_BARREL_" + i );
        barrel = spawn( "script_model", c.origin );
        barrel setmodel( mg_model( "barrel" ) );
        barrel.angles = c.angles;
        level.mg_barrels[i - 1] = barrel;

        // players walk through a bare script_model: a collision clip stands inside the barrel (owner 2026-09-20)
        clip = spawn( "script_model", barrel.origin + ( 0, 0, 16 ) );
        clip setmodel( mg_model( "clip" ) );
        barrel.mg_clip = clip;
    }
}

mg_barrels_set( lit )
{
    foreach ( barrel in level.mg_barrels )
    {
        mg_fx_stop( barrel.mg_fx );
        barrel.mg_fx = undefined;
        barrel.mg_spent = 0;

        if ( !lit )
            continue;

        ent = mg_fx_loop( "barrel_fire", mg_barrel_base( barrel ) );

        if ( isdefined( ent ) )
        {
            ent playloopsound( "amb_fire_sml" );
            level thread mg_fx_keepalive( ent );
            barrel.mg_fx = ent;
        }
    }
}

// A barrel refilled the temper: a flare, then it is out for the rest of the run.
mg_barrel_spend( barrel )
{
    barrel.mg_spent = 1;
    mg_fx_stop( barrel.mg_fx );
    barrel.mg_fx = undefined;
    mg_fx_once( "barrel_flare", mg_barrel_base( barrel ) );
    mg_snd_near( "zmb_plane_fire_whoosh", barrel.origin, 900 );
}

// The remaster plays its drum flame at the drum's foot (str_barrel_fire, where the drum stands; the flames rise inside
// the rim): our drum's pivot is at mid height, 22.37 units up.
mg_barrel_base( barrel )
{
    return barrel.origin - ( 0, 0, 22.37 );
}

// pickup -> run
mg_run_start( player, weapon )
{
    if ( !isdefined( player ) || !is_player_valid( player ) )
        return;

    level.mg_carrier = player;
    level.mg_run_weapon = weapon;
    player.mg_temper_left = 25.0;
    mg_barrels_set( 1 );
    mg_state_set( "run" );
    player thread mg_run_loop( weapon );
    player thread mg_run_shot_watch( weapon );
    player thread mg_run_down_watch();
}

// self = carrier. Timer, barrels, the last-5-s flicker, weapon-away rule.
mg_run_loop( weapon )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );

    away_since = undefined;
    flicker = 0;
    level.mg_run_flame = mg_run_flame_on( self );

    while ( mg_state_is( "run" ) )
    {
        wait 0.1;

        if ( !is_player_valid( self ) )
            continue;

        // a burning barrel within 64 units refills the temper to full, once per run
        foreach ( barrel in level.mg_barrels )
        {
            if ( !is_true( barrel.mg_spent ) && distancesquared( self.origin, barrel.origin ) < 64 * 64 )
            {
                self.mg_temper_left = 25.0;
                self mg_snd_player( "evt_wolfhead_depart" );
                self playrumbleonentity( "damage_heavy" );
                mg_barrel_spend( barrel );
            }
        }

        // weapon away (BO4 checks right after the change; a quarter second forgives a stray scroll)
        current = self getcurrentweapon();

        if ( current != weapon )
        {
            if ( !isdefined( away_since ) )
                away_since = gettime();

            if ( gettime() - away_since > 250 )
            {
                mg_run_fail( "weapon switched away" );
                return;
            }
        }
        else
            away_since = undefined;

        self.mg_temper_left = self.mg_temper_left - 0.1;

        if ( self.mg_temper_left <= 0 )
        {
            mg_run_fail( "the flame died" );
            return;
        }

        // the last 5 s: the flame flickers every 0.5 s, with a rumble and a tick
        flicker++;

        if ( self.mg_temper_left <= 5 && flicker % 5 == 0 )
        {
            if ( isdefined( level.mg_run_flame ) )
            {
                mg_fx_stop( level.mg_run_flame );
                level.mg_run_flame = undefined;
            }
            else
                level.mg_run_flame = mg_run_flame_on( self );

            self playrumbleonentity( "damage_light" );
            self mg_snd_player( "zmb_quest_nixie_count" );
        }
        else if ( self.mg_temper_left > 5 && !isdefined( level.mg_run_flame ) )
            level.mg_run_flame = mg_run_flame_on( self );
    }

    mg_fx_stop( level.mg_run_flame );
    level.mg_run_flame = undefined;
}

// the temper riding the gun
mg_run_flame_on( player )
{
    flame = mg_fx_loop( "gun_flame", player gettagorigin( "tag_weapon_right" ) );

    if ( isdefined( flame ) )
        flame linkto( player, "tag_weapon_right", ( 0, 0, 0 ), ( 0, 0, 0 ) );

    return flame;
}

// self = carrier. Firing the tempered gun spends its essence: the blue flame dies and it is back to the fireplace
// (the BO3 remaster; BO4 only took 6 s a shot).
mg_run_shot_watch( weapon )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );

    while ( mg_state_is( "run" ) )
    {
        self waittill( "weapon_fired", fired );

        if ( isdefined( fired ) && fired == weapon )
        {
            mg_run_fail( "the tempered gun was fired: its essence is spent" );
            return;
        }
    }
}

// self = carrier. Last stand or death ends the temper.
mg_run_down_watch()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );
    self waittill_any( "player_downed", "death", "bled_out" );

    if ( mg_state_is( "run" ) )
        mg_run_fail( "the carrier went down" );
}

// run -> ready. Threaded off the calling loop: the callers endon "mg_run_over", so the notify below would kill
// them (and this tail) if it ran inside their thread.
mg_run_fail( reason )
{
    if ( !mg_state_is( "run" ) )
        return;

    level thread mg_run_fail_do( reason );
}

mg_run_fail_do( reason )
{
    mg_debug_print( "MG: temper lost: " + reason + ". Temper the Blundergat again." );
    level notify( "mg_run_over" );

    if ( isdefined( level.mg_carrier ) && is_player_valid( level.mg_carrier ) )
    {
        level.mg_carrier mg_snd_player( "wpn_blundersplat_explode_layer" );

        if ( isdefined( level.mg_run_weapon ) && level.mg_carrier hasweapon( level.mg_run_weapon ) )
            level.mg_carrier mg_tempered_give_back( level.mg_run_weapon );
    }

    mg_run_cleanup();
    mg_state_set( "ready" );
}

// Everything the run created, destroyed from one place (the loop may have been killed by a notify).
mg_run_cleanup()
{
    if ( isdefined( level.mg_carrier ) )
    {

        level.mg_carrier.mg_temper_left = undefined;
    }

    mg_fx_stop( level.mg_run_flame );
    level.mg_run_flame = undefined;
    level.mg_carrier = undefined;
    level.mg_run_weapon = undefined;
    mg_barrels_set( 0 );
}

// run -> forge (called by mg_forge when the tempered gun is placed, after it has read what it needs from
// level.mg_carrier / the weapon passed in): stop the timer and clean up.
mg_run_end_ok()
{
    level notify( "mg_run_over" );
    mg_run_cleanup();
}

// self = player typing !mg goto
mg_run_fabricate( state )
{
    level notify( "mg_run_over" );
    mg_run_cleanup();

    if ( state == "run" )
    {
        weapon = mg_has_blundergat( self );

        if ( !isdefined( weapon ) )
            weapon = "blundergat_zm";

        // the run carries the tempered gun
        tempered = mg_tempered_of( weapon );

        if ( self hasweapon( weapon ) )
            self takeweapon( weapon );

        self giveweapon( tempered );
        self switchtoweapon( tempered );
        self.mg_tempered_from = weapon;
        level thread mg_run_start_delayed( self, tempered );
    }
}

mg_run_start_delayed( player, weapon )
{
    level endon( "mg_goto" );
    wait 0.1;
    mg_run_start( player, weapon );
}

