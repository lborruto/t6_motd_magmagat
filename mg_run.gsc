#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_hearth;
#include scripts\zm\zm_prison\mg_weapon;

// The temper run, as the BO3 remaster (_zm_weap_magmagat.gsc function_2ca6799): 15 s of temper counted in whole
// seconds; each of the five barrels resets it to 15 once per run (a flare, then it keeps burning until the run ends);
// from 0.5 s on (once the tempered gun first reaches his hands, 3 s at most), any weapon in hand but the tempered gun
// or a Blundergat variant ends it (firing does not). It succeeds when the carrier lays the tempered gun on the powered
// Machine at the forge (mg_forge). Powering the Machine stops the temper's clock and the barrels, as the remaster's
// power press ends its timer; the weapon rule, going down and leaving still fail the run until the gun is laid. On
// failure, silent, the carrier gets his gun back, the skulls go out and 5 s later the fireplace takes a Blundergat again.

mg_run_init()
{
    level.mg_barrels = [];
    level.mg_run_gen = 0;

    for ( i = 1; i <= 5; i++ )
    {
        c = mg_coord( "MG_BARREL_" + i );
        barrel = spawn( "script_model", c.origin );
        barrel setmodel( mg_model( "barrel" ) );
        barrel.angles = c.angles;
        level.mg_barrels[i - 1] = barrel;

        // filled 2/3 up with ash and burnt wood, as BO4's (the owner's call: nothing seen of the drum's inside)
        fill = spawn( "script_model", c.origin );
        fill setmodel( mg_model( "barrel_fill" ) );
        fill.angles = c.angles;
        barrel.mg_fill = fill;

        // players walk through a bare script_model: a collision clip stands inside the barrel (owner 2026-09-20), 128
        // high from its foot so nobody jumps onto it
        clip = spawn( "script_model", mg_barrel_base( barrel ) + ( 0, 0, 64 ) );
        clip setmodel( mg_model( "clip" ) );
        barrel.mg_clip = clip;
    }
}

// Each flame spawns in its own level thread, all five together as the remaster's: a goto killing the caller while one
// spawns leaves none burning outside barrel.mg_fx, and a run ended meanwhile lights no more.
mg_barrels_set( lit )
{
    gen = level.mg_run_gen;

    foreach ( barrel in level.mg_barrels )
    {
        mg_fx_stop( barrel.mg_fx );
        barrel.mg_fx = undefined;
        barrel.mg_spent = 0;

        if ( !lit )
            continue;

        level thread mg_barrel_light( barrel, gen );    // all five at once, as the remaster's
    }
}

// a barrel's flame still spawning when the run ends goes at once (as mg_lockdown_wall)
mg_barrel_light( barrel, gen )
{
    ent = mg_fx_loop( "barrel_fire", mg_barrel_flame( barrel ) );

    if ( gen != level.mg_run_gen )
        mg_fx_stop( ent );
    else if ( isdefined( ent ) )
    {
        level thread mg_fx_keepalive( ent );
        barrel.mg_fx = ent;
    }
}

// A barrel refilled the temper (the remaster's function_bb489f3a): a 5 s flare with its flame burst, then it gives
// no more this run, its own flame still burning.
mg_barrel_spend( barrel )
{
    barrel.mg_spent = 1;
    mg_fx_once( "drum_flare", mg_barrel_base( barrel ), 5 );    // at the foot, as the remaster's: its burst rises at the rim
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

// The flame's origin, 5 below the foot: the remaster's flame at the foot showed its bottom over our drum's rim, 12
// below sat it too deep to see.
mg_barrel_flame( barrel )
{
    return mg_barrel_base( barrel ) - ( 0, 0, 5 );
}

// pickup -> run
mg_run_start( player, weapon )
{
    if ( !isdefined( player ) || !is_player_valid( player ) )
        return;

    level.mg_carrier = player;
    level.mg_run_weapon = weapon;
    level.mg_run_failing = 0;
    level.mg_run_powered = 0;
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
// the last barrel). It stops as the carrier powers the Machine (mg_forge_power), as the remaster's ends there: the
// temper no longer runs out in front of a powered Machine. He then has 60 s to lay the gun on it (the owner's call:
// in co-op a carrier keeping it in hand would hold the quest for everyone), or the run fails.
mg_run_timer()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_run_over" );
    self endon( "disconnect" );

    while ( mg_state_is( "run" ) )
    {
        if ( is_true( level.mg_run_powered ) )
        {
            wait 60;

            if ( mg_state_is( "run" ) )
                mg_run_fail( "the gun was not laid within 60 s of powering the Machine" );

            return;
        }

        self.mg_temper_left--;
        wait 1;

        if ( self.mg_temper_left <= 0 && !is_true( level.mg_run_powered ) )    // powered in its last second: it holds
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

    // the flame spawns in a level thread (this one dies with the carrier down or gone, or a goto, maybe mid-spawn);
    // its 0.15 s spawn time is waited here, so the weapon rule starts where it always did
    level thread mg_run_flame_spawn( self, level.mg_run_gen );
    wait 0.15;

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

        // the clock stopped (the Machine powered), the barrels give nothing more, as the remaster's end there
        if ( is_player_valid( self ) && !is_true( level.mg_run_powered ) )
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

// The temper riding the gun. The remaster's flame is on the carrier's viewmodel muzzle, replayed every 0.1 s (it is
// a 1 s one-shot): the client script in mod.ff does that in first person (_zm_weap_blundersplat.csc), and this world
// flame, at the world gun's muzzle (its hand when the gun has no tag_flash), replays it the same way for the others.
mg_run_flame_on( player )
{
    tag = "tag_flash";

    if ( !isdefined( player gettagorigin( tag ) ) )
        tag = "tag_weapon_right";

    flame = mg_fx_loop( "gun_flame", player gettagorigin( tag ) );

    // the carrier may have left during the spawn
    if ( isdefined( flame ) && isdefined( player ) )
    {
        flame linkto( player, tag, ( 0, 0, 0 ), ( 0, 0, 0 ) );
        flame thread mg_run_flame_replay();
    }

    return flame;
}

// self = the world flame's carrier: the 1 s flame again every 0.1 s, as the remaster's, until it goes
mg_run_flame_replay()
{
    self endon( "death" );

    while ( true )
    {
        wait 0.1;
        playfxontag( level._effect["mg_gun_flame"], self, "tag_origin" );
    }
}

// a flame still spawning when the run ends (or its carrier gone) goes at once, as mg_lockdown_wall
mg_run_flame_spawn( player, gen )
{
    flame = mg_run_flame_on( player );

    if ( gen != level.mg_run_gen || !isdefined( player ) )
        mg_fx_stop( flame );
    else
        level.mg_run_flame = flame;
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

// The carrier's tempered gun back to the Blundergat he placed. A Mystery Box or wall gun taken with a full hand has
// replaced the tempered gun (vanilla weapon_give takes the gun in hand, the only one he could hold): the Blundergat
// comes back too, in a free slot (Mule Kick's, or one freed since), as GUIDE.md promises; with none, the new gun
// replaced it for good (the docs say so). Not while he is down or in Afterlife: the gun is then in his loadout, and
// mg_tempered_watch hands it back once he is up.
mg_run_give_back()
{
    p = level.mg_carrier;

    if ( !isdefined( p ) || !isdefined( level.mg_run_weapon ) )
        return;

    if ( p hasweapon( level.mg_run_weapon ) )
    {
        p mg_tempered_give_back( level.mg_run_weapon );
        return;
    }

    original = p.mg_tempered_from;

    if ( !isdefined( original ) || !is_player_valid( p ) || p hasweapon( original ) )
        return;

    if ( p getweaponslistprimaries().size < get_player_weapon_limit( p ) )
        p giveweapon( original );

    p.mg_tempered_from = undefined;
}

// Everything the run created, destroyed from one place (the loops may have been killed by a notify); a flame still
// spawning sees the generation change and goes (mg_run_flame_spawn, mg_barrel_light). keep_barrels: the drums stay lit
// (the caller puts them out).
mg_run_cleanup( keep_barrels )
{
    level.mg_run_gen++;

    if ( isdefined( level.mg_carrier ) )
        level.mg_carrier.mg_temper_left = undefined;

    level.mg_run_powered = 0;
    mg_fx_stop( level.mg_run_flame );
    level.mg_run_flame = undefined;
    level.mg_carrier = undefined;
    level.mg_run_weapon = undefined;

    if ( !is_true( keep_barrels ) )
        mg_barrels_set( 0 );
}

// The run's success (mg_forge, as the carrier lays the tempered gun on the Machine): it stops, the gun stays his for
// the press to take. The drums go out 1 s after the gun is laid (the owner's call).
mg_run_end_ok()
{
    level notify( "mg_run_over" );

    if ( isdefined( level.mg_carrier ) )
        level.mg_carrier.mg_tempered_from = undefined;

    mg_run_cleanup( 1 );
    level thread mg_barrels_out_later( level.mg_run_gen );
}

// The drums out 1 s on, unless a goto or a new run has taken them over meanwhile (the generation changed).
mg_barrels_out_later( gen )
{
    level endon( "end_game" );
    wait 1;

    if ( gen == level.mg_run_gen )
        mg_barrels_set( 0 );
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
