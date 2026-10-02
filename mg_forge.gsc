#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_hearth;
#include scripts\zm\zm_prison\mg_run;
#include scripts\zm\zm_prison\mg_weapon;

// The forge: the remaster's Machine (mg_upgrade_machine) in the dock Generator Room. The owner's rule, BO4's: only a
// Tempered Blundergat still burning (its run not expired) is pressed. The first carrier to reach it powers it (the
// remaster's power cue; the run and its timer go on, the gun stays his), and it stays powered; then the carrier lays
// the tempered gun on its bed: the run ends in success and the press works it (5.65 s: the ram down, the press fire,
// the Magmagat on the bed as the ram lifts); the placer alone takes the Magmagat within 15 s or it is lost, and a
// guardian comes for it. The fireplace then takes a Blundergat again, for the next player's Magmagat.

mg_forge_init()
{
    level.mg_forge_open = 0;
    level.mg_forge_busy = 0;
    mg_press_spawn();
    level thread mg_forge_prompt_loop();
}

// The remaster's press (p8_zm_esc_machinery_01, mg_upgrade_machine) at its anchor MG_PRESS (mg_coords.gsc: by
// default where the remaster places it around the gun on its bed).
mg_press_spawn()
{
    c = mg_coord( "MG_PRESS" );
    yaw = c.angles[1];
    fwd = anglestoforward( ( 0, yaw, 0 ) );
    left = anglestoright( ( 0, yaw, 0 ) ) * -1;
    origin = c.origin;
    level.mg_press = [];
    level.mg_press_clips = [];

    foreach ( part in array( "press_body", "press_ram" ) )
    {
        m = spawn( "script_model", origin );
        m.angles = ( 0, yaw, 0 );
        m setmodel( mg_model( part ) );
        level.mg_press[part] = m;
    }

    // a script_model stops no player: four clip boxes 64 x 64 x 128, two along the machine's length and two across,
    // overlapping so their outer faces meet its sides (77 x 134, 116 high), sunk 12 into the floor so they top out with
    // it (bullets pass through: a script_model of a mod.ff prop has no bullet collision)
    foreach ( dy in array( -3, 3 ) )
    {
        foreach ( dx in array( -4, 9 ) )
        {
            clip = spawn( "script_model", origin + fwd * dx + left * ( dy * 11 + 2 ) + ( 0, 0, 52 ) );
            clip.angles = ( 0, yaw, 0 );
            clip setmodel( mg_model( "press_clip" ) );
            clip ghost();
            level.mg_press_clips[level.mg_press_clips.size] = clip;
        }
    }

    level.mg_press_rest = origin;
}

// The press's own animations, played on its ram: fxanim_zom_magmagat_press_start_anim brings it down 74.5 cm onto the
// bed from frame 9 to 19 (30 fps, eased), _end_anim lifts it back the same way. Each lasts 0.8 s.
mg_press_down()
{
    level endon( "mg_goto" );
    wait 0.3;
    level.mg_press["press_ram"] moveto( level.mg_press_rest - ( 0, 0, 29.33 ), 0.333, 0.15, 0.15 );
}

mg_press_up()
{
    level endon( "mg_goto" );
    wait 0.3;
    level.mg_press["press_ram"] moveto( level.mg_press_rest, 0.333, 0.15, 0.15 );
}

mg_forge_near( player )
{
    return isdefined( player ) && distancesquared( player.origin, mg_coord( "MG_FORGE" ).origin ) < 96 * 96;
}

mg_forge_carrying( player )
{
    return mg_state_is( "run" ) && isdefined( level.mg_carrier ) && level.mg_carrier == player;
}

mg_forge_prompt_loop()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            text = undefined;

            if ( is_player_valid( player ) && mg_forge_near( player ) )
                text = mg_forge_prompt_text( player );

            if ( !isdefined( text ) )
            {
                if ( is_true( player.mg_forge_prompted ) )
                {
                    player.mg_forge_prompted = 0;
                    player mg_prompt( 0, undefined );
                }

                continue;
            }

            player.mg_forge_prompted = 1;
            player mg_prompt( 1, text );

            if ( player mg_press_use() )
                level thread mg_forge_press( player );
        }
    }
}

// What the forge offers this player right now, or undefined: the remaster's tr_forge hints in plain text, as the other
// polled prompts (power the Machine; lay the tempered gun on it, shown only while it is in his hands; take the Magmagat).
mg_forge_prompt_text( player )
{
    if ( is_true( level.mg_forge_busy ) )
        return undefined;

    // the pressed gun waits for its placer only (the remaster shows the trigger to him alone)
    if ( isdefined( level.mg_forge_ready_gun ) )
    {
        if ( isdefined( level.mg_forge_placer ) && level.mg_forge_placer == player )
            return "Hold ^3[{+activate}]^7 to take the Magmagat";

        return undefined;
    }

    if ( !mg_forge_carrying( player ) )
        return undefined;

    if ( !is_true( level.mg_forge_open ) )
        return "Hold ^3[{+activate}]^7 to power the Machine";

    // the owner's rule: offered only with the tempered gun in hand
    if ( player getcurrentweapon() != level.mg_run_weapon )
        return undefined;

    return "Hold ^3[{+activate}]^7 to place the Tempered Blundergat";
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

    // only the carrier, his temper still burning, uses the Machine
    if ( !mg_forge_carrying( player ) )
        return;

    if ( !is_true( level.mg_forge_open ) )
    {
        mg_forge_power( player );
        return;
    }

    weapon = level.mg_run_weapon;

    if ( !isdefined( weapon ) || !player hasweapon( weapon ) )
        return;

    // the owner's rule: laid on the bed from the hands
    if ( player getcurrentweapon() != weapon )
        return;

    // the run won: the skulls go out and the fireplace takes a Blundergat again, for the next Magmagat
    mg_run_end_ok();
    mg_skulls_dark();
    mg_state_set( "ready" );
    mg_forge_place( player, weapon );
}

// The carrier powers the Machine (the remaster's function_b09dee70): the power panel sound and the power effect on
// the machine, 1 s later the Warden's line to him. The run goes on (the owner's rule: the tempered gun is what the
// forge takes); the Machine stays powered for good.
mg_forge_power( player )
{
    level endon( "mg_goto" );
    level.mg_forge_busy = 1;
    level.mg_press["press_body"] playsound( "zmb_powerpanel_activate" );
    mg_fx_once( "sparks", level.mg_press_rest, undefined, level.mg_press["press_body"].angles );
    wait 1;

    if ( isdefined( player ) )
        player playsoundtoplayer( "mg_brutus_mgu", player );

    level.mg_forge_open = 1;
    level.mg_forge_busy = 0;
    mg_debug_print( "MG: the Machine is powered: lay the Tempered Blundergat on it" );
}

// The gun goes on the bed and the press works it, on the remaster's timeline (function_fb635f94; t from the use).
mg_forge_place( player, weapon )
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

    level.mg_forge_gun_weapon = weapon;
    level.mg_forge_placer = player;
    gun = mg_press_show( weapon );
    wait 1.3;
    level.mg_forge_ready_gun = gun;
    level.mg_forge_place_ents = [];
    level.mg_forge_busy = 0;
    level thread mg_forge_pickup_window( gun );
}

// The press at work on weapon, on the remaster's timeline (function_fb635f94; t from the use); the gun on the bed is
// held in level.mg_forge_place_ents for a goto's cleanup. Returns the Magmagat lying on the bed at t 4.35, as the ram
// lifts. Also played by `!mg tour`.
mg_press_show( weapon )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    c = mg_coord( "MG_FORGE_GUN" );
    gun = spawn_weapon_model( weapon, undefined, c.origin, c.angles );
    level.mg_forge_place_ents = [];
    level.mg_forge_place_ents[0] = gun;

    // the owner's wish over the remaster's single fire: the temper flares up as the gun is laid down, the ram strikes
    // in sparks, the fire roars through the press, the Magmagat comes out in a burst
    body = level.mg_press["press_body"];
    mg_fx_once( "barrel_flare", c.origin, 3 );
    body playsound( "mg_flame_burst" );

    level thread mg_forge_ghosts();

    // t 0.5: the start anim (the ram comes down 0.3 s in); t 0.55: the press sound at the machine
    wait 0.5;
    level thread mg_press_down();
    wait 0.05;
    body playsound( "mg_press" );
    body playloopsound( "zmb_fire_loop", 0.5 );

    // t 0.85: the ram strikes the gun
    wait 0.3;
    mg_fx_once( "sparks", c.origin, undefined, body.angles );
    body playsound( "zmb_hellbox_slam_shake" );

    // t 1.35, the start anim over: the press fire once at the machine, the gun under the ram gone
    wait 0.5;
    mg_fx_once( "forge_rise", level.mg_press_rest, 6, body.angles );
    body playsound( "mg_flame_burst" );
    gun delete();

    // t 4.35: the Magmagat lies on the bed in a burst as the end anim lifts the ram; ready 0.8 + 0.5 s later
    wait 3;
    gun = spawn_weapon_model( mg_magma_of( weapon ), undefined, c.origin, c.angles );
    level.mg_forge_place_ents[0] = gun;
    mg_fx_once( "explo", c.origin );
    body stoploopsound( 0.5 );
    body playsound( "mg_flame_burst" );
    body playsound( "zmb_buildable_complete" );
    level thread mg_press_up();
    return gun;
}

// 15 s to take the Magmagat, or it is lost without a sign (the remaster's function_369019ca). The forge stays open.
mg_forge_pickup_window( gun )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    wait 15;

    if ( !isdefined( level.mg_forge_ready_gun ) || level.mg_forge_ready_gun != gun )
        return;

    mg_debug_print( "MG: the Magmagat was not taken in 15 s: it is lost" );
    mg_forge_ready_clear();
    mg_forge_rest();
}

// The machine and its collision gone (`!mg grab MG_PRESS` holds a copy of it meanwhile).
mg_press_remove()
{
    foreach ( m in level.mg_press )
    {
        if ( isdefined( m ) )
            m delete();
    }

    foreach ( clip in level.mg_press_clips )
    {
        if ( isdefined( clip ) )
            clip delete();
    }

    level.mg_press = [];
    level.mg_press_clips = [];
}

// BO4's ghosts working the forge, as Afterlife bodies (vanilla's c_zom_hero_ghost_fb in its blue glow): at the press's
// start one rises out of the floor at each end of the machine, turned to it, and they stand by it through the press;
// as the Magmagat comes out (t 4.35) they vanish. Held in level.mg_forge_place_ents for a goto's cleanup.
mg_forge_ghosts()
{
    body = level.mg_press["press_body"];
    left = anglestoright( body.angles ) * -1;
    ghosts = [];

    foreach ( side in array( -1, 1 ) )
    {
        spot = level.mg_press_rest + left * side * 82;
        ghost = spawn( "script_model", spot - ( 0, 0, 72 ) );
        ghost.angles = ( 0, vectortoangles( level.mg_press_rest - spot )[1], 0 );
        ghost setmodel( mg_model( "ghost" ) );
        ghost.mg_spot = spot;
        ghosts[ghosts.size] = ghost;
        level.mg_forge_place_ents[level.mg_forge_place_ents.size] = ghost;
    }

    wait 0.05;    // an effect played in the frame an entity appears is dropped by the clients

    foreach ( ghost in ghosts )
    {
        if ( !isdefined( ghost ) )
            return;

        mg_fx_add_tag( ghost, "ghost_body", "J_SpineUpper" );
        mg_fx_add_tag( ghost, "ghost_head", "J_Head" );
        mg_fx_once( "ghost_tport", ghost.mg_spot );
        playsoundatposition( "zmb_afterlife_object_apparate", ghost.mg_spot );
        ghost playloopsound( "zmb_afterlife_ghost_loop", 0.5 );
        ghost moveto( ghost.mg_spot, 0.8, 0.1, 0.4 );
    }

    wait 4.3;

    foreach ( ghost in ghosts )
    {
        if ( !isdefined( ghost ) )
            continue;

        mg_fx_once( "ghost_tport", ghost.origin + ( 0, 0, 36 ) );
        playsoundatposition( "zmb_afterlife_object_disapparate", ghost.origin );
        ghost delete();
    }
}

// The placer takes the Magmagat (the Magmus Operandi when a Pack-a-Punched gun was pressed). One who already owns a
// Magmagat only gets its ammo refilled, as the remaster, or the Magmus for a plain one (mg_weapon_grant).
mg_forge_take( player )
{
    if ( !isdefined( level.mg_forge_ready_gun ) || !is_player_valid( player ) )
        return;

    if ( !isdefined( level.mg_forge_placer ) || level.mg_forge_placer != player )
        return;

    // as the fireplace's take (the remaster ignores the press while drinking, or with a mine, equipment or nothing in hand)
    if ( is_true( player.is_drinking ) || !mg_can_replace_current( player ) )
        return;

    weapon = level.mg_forge_gun_weapon;
    mg_forge_ready_clear();
    player mg_weapon_grant( weapon );

    level thread mg_forge_guardian();
    mg_forge_rest();
}

// The Magmagat taken calls its guardian, as BO4: a Brutus, through vanilla's own spawning (brutus_spawning_logic picks
// a zone and a spot near the players; a zone named by hand may have none and leave a removed entity behind).
mg_forge_guardian()
{
    level endon( "end_game" );
    wait 1;
    level notify( "spawn_brutus", 1 );
}

mg_forge_ready_clear()
{
    if ( isdefined( level.mg_forge_ready_gun ) )
        level.mg_forge_ready_gun delete();

    level.mg_forge_ready_gun = undefined;
    level.mg_forge_gun_weapon = undefined;
    level.mg_forge_placer = undefined;
}

// The remaster shows the forge again 0.5 s after the Magmagat is taken or lost.
mg_forge_rest()
{
    level endon( "mg_goto" );
    level.mg_forge_busy = 1;
    wait 0.5;
    level.mg_forge_busy = 0;
}

// self = player typing !mg goto. "forge" fabricates a Magmagat on the bed waiting for him.
mg_forge_fabricate( state )
{
    // a place() killed mid-press by the goto notify leaves its entities to us
    if ( isdefined( level.mg_forge_place_ents ) )
    {
        foreach ( ent in level.mg_forge_place_ents )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.mg_forge_place_ents = [];
    mg_forge_ready_clear();
    level.mg_press["press_ram"] moveto( level.mg_press_rest, 0.1 );
    level.mg_forge_busy = 0;
    level.mg_forge_open = ( state == "forge" || state == "done" );

    if ( state == "forge" && isdefined( self ) && isplayer( self ) )
    {
        c = mg_coord( "MG_FORGE_GUN" );
        level.mg_forge_gun_weapon = "blundergat_zm";
        level.mg_forge_placer = self;
        level.mg_forge_ready_gun = spawn_weapon_model( "magmagat_zm", undefined, c.origin, c.angles );
        level thread mg_forge_pickup_window( level.mg_forge_ready_gun );
    }
}
