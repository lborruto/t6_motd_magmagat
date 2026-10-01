#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_hearth;
#include scripts\zm\zm_prison\mg_forge;
#include scripts\zm\zm_prison\mg_weapon;

// The temper run, as the BO3 remaster (_zm_weap_magmagat.gsc function_2ca6799): 15 s of temper counted in whole
// seconds; each of the five barrels resets it to 15 once per run (a flare, then it keeps burning until the run ends);
// from 0.5 s on (once the tempered gun first reaches his hands, 3 s at most), any weapon in hand but the tempered gun
// or a Blundergat variant ends it (firing does not). It succeeds when the carrier lays the tempered gun on the powered
// Machine at the forge (mg_forge; powering it does not end it); on failure, silent, the carrier gets his gun back, the
// skulls go out and 5 s later the fireplace takes a Blundergat again.

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

        // players walk through a bare script_model: a collision clip stands inside the barrel (owner 2026-09-20), 128
        // high from its foot so nobody jumps onto it
        clip = spawn( "script_model", mg_barrel_base( barrel ) + ( 0, 0, 64 ) );
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

        ent = mg_fx_loop( "barrel_fire", mg_barrel_flame( barrel ) );

        if ( isdefined( ent ) )
        {
            level thread mg_fx_keepalive( ent );
            barrel.mg_fx = ent;
        }
    }
}

// A barrel refilled the temper (the remaster's function_bb489f3a): a 5 s flare with its flame burst, then it gives
// no more this run, its own flame still burning.
mg_barrel_spend( barrel )
{
    barrel.mg_spent = 1;
    mg_fx_once( "barrel_flare", mg_barrel_flame( barrel ), 5 );
    barrel playsound( "mg_flame_burst" );
}

// The remaster plays its drum flame at the drum's foot (str_barrel_fire, where the drum stands; the flames rise inside
// the rim): our drum's pivot is at mid height, 22.37 units up.
mg_barrel_base( barrel )
{
    return barrel.origin - ( 0, 0, 22.37 );
}

// The remaster's barrel trigger: a trigger_radius of 64 and 64 high standing on the drum's foot. Our drums stand where
// the owner placed them, some a little above the floor, so feet up to 24 below the foot count too (they did not).
mg_barrel_touch( player, barrel )
{
    if ( distance2dsquared( player.origin, barrel.origin ) >= 64 * 64 )
        return 0;

    dz = player.origin[2] - mg_barrel_base( barrel )[2];
    return dz >= -24 && dz <= 64;
}

// The flame's origin, 12 below the foot: the remaster's flame at the foot showed its bottom over our drum's rim.
mg_barrel_flame( barrel )
{
    return mg_barrel_base( barrel ) - ( 0, 0, 12 );
}

// pickup -> run
mg_run_start( player, weapon )
{
    if ( !isdefined( player ) || !is_player_valid( player ) )
        return;

    level.mg_carrier = player;
    level.mg_run_weapon = weapon;
    level.mg_run_failing = 0;
    player.mg_temper_left = 15;
    // the state first: lighting the barrels takes 0.75 s, and outside a run mg_tempered_watch takes the gun back
    mg_state_set( "run" );
    player thread mg_run_timer();
    player thread mg_run_loop( weapon );
    player thread mg_run_down_watch();
    level thread mg_run_carrier_watch( player );
    mg_barrels_set( 1 );
}

// The carrier leaving the game fails the run (his own threads die with him).
mg_run_carrier_watch( player )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    player waittill( "disconnect" );

    if ( mg_state_is( "run" ) )
        mg_run_fail( "the carrier left" );
}

// self = carrier. The remaster's function_7f32cc1f: a second off, a second's wait, out at 0 (15 s after the start or
// the last barrel).
mg_run_timer()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );

    while ( mg_state_is( "run" ) )
    {
        self.mg_temper_left--;
        wait 1;

        if ( self.mg_temper_left <= 0 )
        {
            mg_run_fail( "the flame died" );
            return;
        }
    }
}

// self = carrier. Barrels and the weapon rule, polled every 0.1 s as the remaster's function_2bfa6391.
mg_run_loop( weapon )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );

    level.mg_run_flame = mg_run_flame_on( self );

    // the remaster starts checking the weapon 0.5 s after the start, with no grace after that. Its player keeps his
    // gun; ours was just handed the tempered one (mg_switch_to raises it), so until it first reaches his hands, for
    // 3 s at most, the gun in hand is not a switch away.
    start = gettime();
    wait 0.5;
    in_hand = 0;

    while ( mg_state_is( "run" ) )
    {
        current = self getcurrentweapon();

        if ( isdefined( current ) && current == weapon )
            in_hand = 1;

        if ( is_player_valid( self ) )
        {
            // a barrel within reach resets the temper to full, once per run
            foreach ( barrel in level.mg_barrels )
            {
                if ( !is_true( barrel.mg_spent ) && mg_barrel_touch( self, barrel ) )
                {
                    self.mg_temper_left = 15;
                    mg_barrel_spend( barrel );
                }
            }
        }

        if ( ( in_hand || gettime() - start > 3000 ) && !mg_run_weapon_ok( current, weapon ) )
        {
            mg_run_fail( "weapon switched away" );
            return;
        }

        wait 0.1;
    }
}

// The run's gun, or any of the four Blundergat variants (the remaster lets the Blundergat and the Acid Gat swap).
mg_run_weapon_ok( current, weapon )
{
    // "none" is T6's hands on a ladder or a mantle, not a switch
    if ( !isdefined( current ) || current == "none" )
        return 1;

    return current == weapon || mg_is_tempered( current ) || mg_is_blundergat( current );
}

// The temper riding the gun. The remaster's flame is on the carrier's viewmodel muzzle only; T6 has no server-side
// viewmodel fx, so the tempered gun's own model shows it in first person and this world flame, at the world gun's muzzle
// (its hand when the gun has no tag_flash), shows it to the others.
mg_run_flame_on( player )
{
    tag = "tag_flash";

    if ( !isdefined( player gettagorigin( tag ) ) )
        tag = "tag_weapon_right";

    flame = mg_fx_loop( "gun_flame", player gettagorigin( tag ) );

    if ( isdefined( flame ) )
        flame linkto( player, tag, ( 0, 0, 0 ), ( 0, 0, 0 ) );

    return flame;
}

// self = carrier. Last stand or death ends the temper (the remaster gets there through the weapon rule: the pistol,
// the afterlife hands).
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
    if ( !mg_state_is( "run" ) || is_true( level.mg_run_failing ) )
        return;

    level.mg_run_failing = 1;
    level thread mg_run_fail_do( reason );
}

// The remaster's failure: no sound, no fx, the lit skulls go out; 5 s later the fireplace takes a Blundergat again
// and the whole step (place, 15 souls, deposit, take) is to redo. The state stays "run" meanwhile, with no carrier.
mg_run_fail_do( reason )
{
    level endon( "mg_goto" );
    mg_debug_print( "MG: temper lost: " + reason + ". Temper the Blundergat again." );
    level notify( "mg_run_over" );
    mg_run_give_back();
    mg_run_cleanup();
    mg_skulls_dark();
    level.mg_souls = 0;
    level.mg_souls_taken = 0;
    wait 5;
    level.mg_run_failing = 0;
    mg_state_set( "ready" );
}

// The carrier's tempered gun back to the Blundergat he placed.
mg_run_give_back()
{
    if ( !isdefined( level.mg_carrier ) || !isdefined( level.mg_run_weapon ) )
        return;

    if ( level.mg_carrier hasweapon( level.mg_run_weapon ) )
        level.mg_carrier mg_tempered_give_back( level.mg_run_weapon );
}

// Everything the run created, destroyed from one place (the loops may have been killed by a notify).
mg_run_cleanup()
{
    if ( isdefined( level.mg_carrier ) )
        level.mg_carrier.mg_temper_left = undefined;

    mg_fx_stop( level.mg_run_flame );
    level.mg_run_flame = undefined;
    level.mg_carrier = undefined;
    level.mg_run_weapon = undefined;
    mg_barrels_set( 0 );
}

// The run's success (mg_forge, as the carrier lays the tempered gun on the Machine): it stops, the gun stays his for
// the press to take.
mg_run_end_ok()
{
    level notify( "mg_run_over" );

    if ( isdefined( level.mg_carrier ) )
        level.mg_carrier.mg_tempered_from = undefined;

    mg_run_cleanup();
}

// self = player typing !mg goto
mg_run_fabricate( state )
{
    level notify( "mg_run_over" );
    mg_run_cleanup();
    level.mg_run_failing = 0;

    if ( state == "run" )
    {
        weapon = mg_has_blundergat( self );

        if ( !isdefined( weapon ) )
            weapon = "blundergat_zm";

        // the run carries the tempered gun
        tempered = mg_tempered_of( weapon );

        if ( self hasweapon( weapon ) )
            self takeweapon( weapon );

        self mg_give_weapon( tempered );
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
