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
// the tempered gun on its bed: the run ends in success and the press works it (11.6 s, BO4's: the ghouls pull the
// lever, the ram down, the press fire, the Magmagat on the bed as the ram lifts); the placer alone takes the Magmagat within 15 s or it is lost, and a
// guardian comes for it. The fireplace then takes a Blundergat again, for the next player's Magmagat.

mg_forge_init()
{
    level.mg_forge_open = 0;
    level.mg_forge_busy = 0;
    mg_press_spawn();
    level thread mg_forge_prompt_loop();
}

// The remaster's press (p8_zm_esc_machinery_01, mg_upgrade_machine) at its anchor MG_PRESS (mg_coords.gsc: pinned where
// BO4's own fits).
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

    // BO4's lever (tools/import_all.pl) at its anchor, turned about its pivot by mg_press_show
    l = mg_coord( "MG_LEVER" );
    lever = spawn( "script_model", l.origin );
    lever.angles = l.angles;
    lever setmodel( mg_model( "press_lever" ) );
    level.mg_press["press_lever"] = lever;

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
    level.mg_press["press_ram"].origin = mg_press_ram_rest();
}

// The press's own animations, played on its ram: fxanim_zom_magmagat_press_start_anim brings it down 74.5 cm onto the
// bed from frame 9 to 19 (30 fps, eased), _end_anim lifts it back the same way. Each lasts 0.8 s.
mg_press_down()
{
    level endon( "mg_goto" );
    wait 0.3;
    level.mg_press["press_ram"] moveto( mg_press_ram_closed(), 0.333, 0.15, 0.15 );
}

// The ram down on the bed: 74.5 cm (29.33 units) under its rest.
mg_press_ram_closed()
{
    return level.mg_press_rest - ( 0, 0, 29.33 );
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

// The carrier powers the Machine (the remaster's function_b09dee70, its power sound and effect, then the Warden's line
// to him). The press stands closed until then and opens as it wakes (mg_forge_power_fx); the run goes on (the owner's
// rule: the tempered gun is what the forge takes); the Machine stays powered for good.
mg_forge_power( player )
{
    level endon( "mg_goto" );
    level.mg_forge_busy = 1;
    level thread mg_forge_power_fx();
    wait 2.5;

    if ( isdefined( player ) )
        player playsoundtoplayer( "mg_brutus_mgu", player );

    level.mg_forge_open = 1;
    level.mg_forge_busy = 0;
    mg_debug_print( "MG: the Machine is powered: lay the Tempered Blundergat on it" );
}

// The Machine waking (the owner's wish: more than electricity, and the closed press opening): a surge and the
// remaster's power effect, the lever twitching; the closed ram shudders three times on the bed, then a slam in sparks
// and a flare of fire; the ram lifts open (t 1.4) with fire through the machine and embers on the bed. Also `!mg tour`.
mg_forge_power_fx()
{
    level endon( "mg_goto" );
    body = level.mg_press["press_body"];
    ram = level.mg_press["press_ram"];
    lever = level.mg_press["press_lever"];
    bed = mg_coord( "MG_FORGE_GUN" ).origin;
    closed = mg_press_ram_closed();
    body playsound( "zmb_powerpanel_activate" );
    body playsound( "evt_electrical_surge" );
    fx = mg_coord( "MG_FORGE_FX" );
    mg_fx_once( "sparks", fx.origin, undefined, fx.angles );
    lever rotatepitch( 8, 0.12 );
    wait 0.12;
    lever rotatepitch( -8, 0.25, 0, 0.2 );
    wait 0.18;

    // t 0.3: the closed ram shudders, straining against the bed
    for ( i = 0; i < 3; i++ )
    {
        ram moveto( closed + ( 0, 0, 3 ), 0.1 );
        body playsound( "amb_metal_hits" );
        wait 0.1;
        ram moveto( closed, 0.1 );
        wait 0.15;
    }

    // t 1.1: a slam in sparks, the fire flaring on the bed
    mg_fx_once( "sparks", fx.origin, undefined, fx.angles );
    mg_fx_once( "barrel_flare", bed, 3 );
    body playsound( "zmb_hellbox_slam_shake" );
    body playsound( "mg_flame_burst" );
    wait 0.3;

    // t 1.4: the press opens, fire roaring through it
    ram moveto( level.mg_press_rest, 0.9, 0.2, 0.4 );
    body playsound( "mg_press" );
    mg_fx_once( "forge_rise", fx.origin, 2, fx.angles );
    mg_fx_once( "embers", bed, 4 );
    wait 0.9;
    body playsound( "mg_flame_burst" );
}

// The ram's rest: up when the Machine is powered, down on the bed until then (the press stands closed).
mg_press_ram_rest()
{
    if ( is_true( level.mg_forge_open ) )
        return level.mg_press_rest;

    return mg_press_ram_closed();
}

// The gun goes on the bed and the press works it (mg_press_show, BO4's timeline); 1.3 s after the Magmagat appears it
// can be taken.
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

// The press at work on weapon, on BO4's timeline (its scene aib_vign_zm_mob_smelter_ghost: the smelter's start anim,
// 11.4 s, then its finish; t from the gun laid down): two ghouls come out of the gun and pull the lever (t 3.4), the
// ram comes down on the gun (t 4.0, the smelter_press notetrack) and works it 7.4 s in fire and sparks, then lifts on
// the Magmagat (t 11.6, smelter_show), which floats over tiny flames on the bed until taken. The gun on the bed is held
// in level.mg_forge_place_ents for a goto's cleanup. Returns the Magmagat on the bed. Also played by `!mg tour`.
mg_press_show( weapon )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    c = mg_coord( "MG_FORGE_GUN" );
    gun = spawn_weapon_model( weapon, undefined, c.origin, c.angles );
    level.mg_forge_place_ents = [];
    level.mg_forge_place_ents[0] = gun;
    body = level.mg_press["press_body"];
    lever = level.mg_press["press_lever"];

    // t 0: the temper flares up as the gun is laid down, the ghouls rise out of it
    mg_fx_once( "barrel_flare", c.origin, 3 );
    body playsound( "mg_flame_burst" );
    level thread mg_forge_ghouls( c.origin );

    // t 3.4: the lever pulled down 45 degrees in 0.2 s (the smelter's handel_1_jnt, frames 102 to 109)
    wait 3.4;
    lever playsound( "zmb_trap_switch" );
    lever rotatepitch( 45, 0.2, 0.05, 0.05 );

    // t 3.6: the ram comes down (mg_press_down: 0.3 s, then 0.33 s) and strikes the gun at t 4.0
    wait 0.2;
    level thread mg_press_down();
    body playsound( "mg_press" );
    wait 0.43;
    fx = mg_coord( "MG_FORGE_FX" );
    mg_fx_once( "sparks", fx.origin, undefined, fx.angles );
    body playsound( "zmb_hellbox_slam_shake" );
    body playloopsound( "zmb_fire_loop", 0.5 );
    gun delete();

    // t 4.0 to 11.4: the press works the gun, the remaster's press fire through it, the gun burning under the ram after
    // a burst of flame, and sparks from the bed
    mg_fx_once( "forge_rise", fx.origin, 7.4, fx.angles );
    mg_fx_once( "flame_burst", c.origin );
    mg_fx_once( "forge_fire", c.origin, 7.4 );

    for ( i = 0; i < 5; i++ )
    {
        wait 1.4;
        mg_fx_once( "sparks", fx.origin, undefined, fx.angles );
        body playsound( "zmb_hellbox_slam_shake" );
    }

    // t 11.4: the finish, the ram and the lever up (frames 4 to 25); t 11.6 (smelter_show) the Magmagat on the bed
    wait 0.4;
    level thread mg_press_up();
    lever rotatepitch( -45, 0.7, 0.1, 0.3 );
    body stoploopsound( 0.5 );
    wait 0.17;
    gun = spawn_weapon_model( mg_magma_of( weapon ), undefined, c.origin, c.angles );
    level.mg_forge_place_ents[0] = gun;
    mg_fx_once( "explo", c.origin );
    body playsound( "mg_flame_burst" );
    body playsound( "zmb_buildable_complete" );
    level thread mg_forge_embers( gun, c.origin );
    gun thread mg_forge_gun_float( c.origin + ( 0, 0, 6 ) );
    return gun;
}

// self = the Magmagat on the bed: it rises off it as the ram lifts, then floats there until taken (the owner's wish,
// BO4's fireplace hover, mg_hover)
mg_forge_gun_float( origin )
{
    self endon( "death" );
    self moveto( origin, 0.8, 0.2, 0.4 );
    wait 0.8;
    self mg_hover( origin );
}

// BO4's reveal: tiny flames on the bed under the Magmagat, while it floats there.
mg_forge_embers( gun, origin )
{
    embers = mg_fx_loop( "embers", origin - ( 0, 0, 2 ) );

    while ( isdefined( gun ) )
        wait 0.2;

    mg_fx_stop( embers );
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
    level.mg_forge_busy = 0;
    level.mg_forge_open = ( state == "forge" || state == "done" );
    level.mg_press["press_ram"] moveto( mg_press_ram_rest(), 0.1 );

    // a press or a power step killed by the goto leaves its fire loop playing and its lever pulled: both back at rest
    level.mg_press["press_body"] stoploopsound();
    level.mg_press["press_lever"] rotateto( mg_coord( "MG_LEVER" ).angles, 0.1 );

    if ( state == "forge" && isdefined( self ) && isplayer( self ) )
    {
        c = mg_coord( "MG_FORGE_GUN" );
        level.mg_forge_gun_weapon = "blundergat_zm";
        level.mg_forge_placer = self;
        level.mg_forge_ready_gun = spawn_weapon_model( "magmagat_zm", undefined, c.origin, c.angles );
        level thread mg_forge_pickup_window( level.mg_forge_ready_gun );
    }
}

#using_animtree("fxanim_props");

// BO4's ghouls (its scene's two fakeactors, c_t8_zmb_mob_ghoul bodies in Mob's Afterlife ghost: tools/build_ghoul_mats.pl),
// each playing its own BO4 animation, flown by script (BO4 flies them by their animation's tag_origin track, in its
// scene's own frame, which neither a script_model plays nor fits the remaster's press), as the owner set it: out of the
// bed under the Magmagat head first (t 0), face first to its grip of the lever (its spot MG_GHOUL_1 / _2, a ghoul's
// origin its waist), the pull with the lever (t 3.4), then off through the roof (t 3.8). Script models share one
// animtree (Mob's fxanim_props, which mod.ff extends with theirs: tools/import_all.pl). Held in level.mg_forge_place_ents.
mg_forge_ghouls( bed )
{
    level endon( "mg_goto" );
    floor = mg_coord( "MG_PRESS" ).origin[2];
    scriptmodelsuseanimtree( #animtree );
    anims = array( %mg_ghoul_smelter_1, %mg_ghoul_smelter_2 );
    ghouls = [];

    for ( i = 0; i < 2; i++ )
    {
        c = mg_coord( "MG_GHOUL_" + ( i + 1 ) );
        yaw = vectortoangles( c.origin - bed )[1];
        g = spawn( "script_model", ( bed[0], bed[1], floor - 40 ) );    // under the floor, below the Magmagat
        g.angles = ( 0, yaw, 0 );
        g setmodel( mg_model( "ghoul" + ( i + 1 ) ) );
        g useanimtree( #animtree );
        g setanim( anims[i], 1, 0, 1 );
        g.mg_spot = c.origin;
        g.mg_face = c.angles;
        g.mg_yaw = yaw;
        ghouls[i] = g;
        level.mg_forge_place_ents[level.mg_forge_place_ents.size] = g;
    }

    wait 0.05;    // an effect played in the frame an entity appears is dropped by the clients

    // t 0 to 0.6: up through the machine (hidden in it) and out of the bed where the Magmagat lies, head first
    foreach ( g in ghouls )
    {
        mg_fx_add_tag( g, "ghost_body", "j_spineupper" );
        mg_fx_add_tag( g, "ghost_head", "j_head" );
        mg_fx_once( "ghost_tport", bed );
        playsoundatposition( "zmb_afterlife_object_apparate", bed );
        g playloopsound( "zmb_afterlife_ghost_loop", 0.5 );
        g moveto( bed + ( 0, 0, 25 ), 0.55, 0.15, 0.15 );
    }

    // t 0.6 to 2.6: face first to its grip, leaning into the flight, then upright to it
    wait 0.55;

    foreach ( g in ghouls )
    {
        g moveto( g.mg_spot, 2, 0.4, 0.7 );
        g rotateto( ( 40, g.mg_yaw, 0 ), 0.3, 0.1, 0.1 );
    }

    wait 1.6;

    foreach ( g in ghouls )
        g rotateto( g.mg_face, 0.4, 0.1, 0.2 );

    // t 3.4: the pull, the lever's
    wait 1.2;

    foreach ( g in ghouls )
        g moveto( g.mg_spot - ( 0, 0, 10 ), 0.2, 0.05, 0.05 );

    // t 3.8: off through the roof, head first
    wait 0.4;

    foreach ( g in ghouls )
        g moveto( g.mg_spot + ( 0, 0, 400 ), 1.4, 0.9, 0 );

    wait 1.4;

    foreach ( g in ghouls )
    {
        if ( !isdefined( g ) )
            continue;

        playsoundatposition( "zmb_afterlife_object_disapparate", g.origin );
        g delete();
    }
}
