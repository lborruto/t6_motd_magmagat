#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_forge;

// The temper run: 25 s of flame, five blue barrels refill it, a shot costs 5 s, switching away for more than
// 1 s or going down kills it (spec section 3, numbers approved 2026-09-18).

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
    }
}

mg_barrels_set( lit )
{
    if ( !isdefined( level.mg_barrel_fx ) )
        level.mg_barrel_fx = [];

    foreach ( ent in level.mg_barrel_fx )
        mg_fx_stop( ent );

    level.mg_barrel_fx = [];

    if ( !lit )
        return;

    foreach ( barrel in level.mg_barrels )
    {
        ent = mg_fx_loop( "barrel_fire", barrel.origin + ( 0, 0, 30 ) );

        if ( isdefined( ent ) )
        {
            level thread mg_fx_keepalive( ent );
            level.mg_barrel_fx[level.mg_barrel_fx.size] = ent;
        }
    }
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
    player thread mg_hud_title( "Tempered Blundergat", 3 );
    player thread mg_run_loop( weapon );
    player thread mg_run_shot_watch( weapon );
    player thread mg_run_down_watch();
}

// self = carrier. Timer, HUD bar, barrels, weapon-away rule.
mg_run_loop( weapon )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );

    bar = self mg_bar_create( "Temper" );
    self.mg_run_bar = bar;
    away_since = undefined;
    flame = mg_fx_loop( "gun_flame", self.origin );

    if ( isdefined( flame ) )
        flame linkto( self, "tag_weapon_right", ( 0, 0, 0 ), ( 0, 0, 0 ) );

    level.mg_run_flame = flame;

    while ( mg_state_is( "run" ) )
    {
        wait 0.1;

        if ( !is_player_valid( self ) )
            continue;

        // barrels refill
        foreach ( barrel in level.mg_barrels )
        {
            if ( distancesquared( self.origin, barrel.origin ) < 80 * 80 )
            {
                if ( self.mg_temper_left < 24.5 )
                    self mg_snd_player( "evt_wolfhead_depart" );

                self.mg_temper_left = 25.0;
            }
        }

        // weapon away for more than 1 s
        current = self getcurrentweapon();

        if ( current != weapon )
        {
            if ( !isdefined( away_since ) )
                away_since = gettime();

            if ( gettime() - away_since > 1000 )
            {
                mg_run_fail( "weapon switched away" );
                return;
            }
        }
        else
            away_since = undefined;

        self.mg_temper_left = self.mg_temper_left - 0.1;
        mg_bar_update( bar, self.mg_temper_left / 25.0 );

        if ( self.mg_temper_left <= 0 )
        {
            mg_run_fail( "the flame died" );
            return;
        }
    }

    mg_bar_destroy( self.mg_run_bar );
    self.mg_run_bar = undefined;
    mg_fx_stop( level.mg_run_flame );
    level.mg_run_flame = undefined;
}

// self = carrier. Each shot of the tempered gun costs 5 s.
mg_run_shot_watch( weapon )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );

    while ( mg_state_is( "run" ) )
    {
        self waittill( "weapon_fired", fired );

        if ( isdefined( fired ) && fired == weapon && isdefined( self.mg_temper_left ) )
        {
            self.mg_temper_left = self.mg_temper_left - 5.0;
            mg_debug_print( "MG: shot fired, temper " + int( self.mg_temper_left ) + " s" );
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
        level.mg_carrier thread mg_hud_title( "The temper is lost", 3 );
    }

    mg_run_cleanup();
    mg_state_set( "ready" );
}

// Everything the run created, destroyed from one place (the loop may have been killed by a notify).
mg_run_cleanup()
{
    if ( isdefined( level.mg_carrier ) )
    {
        if ( isdefined( level.mg_carrier.mg_run_bar ) )
            mg_bar_destroy( level.mg_carrier.mg_run_bar );

        level.mg_carrier.mg_run_bar = undefined;
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

        level thread mg_run_start_delayed( self, weapon );
    }
}

mg_run_start_delayed( player, weapon )
{
    level endon( "mg_goto" );
    wait 0.1;
    mg_run_start( player, weapon );
}

