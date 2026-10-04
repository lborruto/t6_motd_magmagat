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

    // BO4's lever (tools/import_all.pl), turned about its pivot (mg_lever_pivot) by mg_press_show
    lever = spawn( "script_model", mg_press_point( mg_lever_pivot() ) );
    lever.angles = ( 0, yaw + 180 + getdvarfloat( "mg_lever_yaw" ), 0 );    // facing out (see mg_lever_pivot); dvar mg_lever_yaw turns it more
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
}

// The lever's pivot in the press's frame: where the smelter has it next to its smasher, the smelter's smasher and our
// ram being one mesh at 0.755 scale (the smasher's centre + (33.5, 0, -30.6) scaled, from our ram's centre (5.4, -0.25,
// 86.5)), on the other side: the remaster's machine faces the other way than BO4's (the owner turned it 180 degrees to
// match), so the lever turns 180 degrees with it. The dvar mg_lever_offset "x y z" (forward, left, up) replaces it.
mg_lever_pivot()
{
    return mg_dvar_vec( "mg_lever_offset", ( -28.1, -0.26, 55.9 ) );
}

// A point in the press's frame (forward, left, up from its anchor MG_PRESS), in the world.
mg_press_point( v )
{
    c = mg_coord( "MG_PRESS" );
    yaw = ( 0, c.angles[1], 0 );
    return c.origin + anglestoforward( yaw ) * v[0] - anglestoright( yaw ) * v[1] + ( 0, 0, v[2] );
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

// The carrier powers the Machine (the remaster's function_b09dee70, its power sound and effect, 1 s later the Warden's
// line to him). The run goes on (the owner's rule: the tempered gun is what the forge takes); the Machine stays
// powered for good.
mg_forge_power( player )
{
    level endon( "mg_goto" );
    level.mg_forge_busy = 1;
    level thread mg_forge_power_fx();
    wait 1;

    if ( isdefined( player ) )
        player playsoundtoplayer( "mg_brutus_mgu", player );

    level.mg_forge_open = 1;
    level.mg_forge_busy = 0;
    mg_debug_print( "MG: the Machine is powered: lay the Tempered Blundergat on it" );
}

// The Machine waking (the owner's wish: more than electricity): the remaster's power effect and sound, a surge, the
// machine shuddering (its ram jolts, its lever twitches), and a flare of fire on its bed in embers. Also `!mg tour`.
mg_forge_power_fx()
{
    level endon( "mg_goto" );
    body = level.mg_press["press_body"];
    ram = level.mg_press["press_ram"];
    lever = level.mg_press["press_lever"];
    bed = mg_coord( "MG_FORGE_GUN" ).origin;
    body playsound( "zmb_powerpanel_activate" );
    body playsound( "evt_electrical_surge" );
    mg_fx_once( "sparks", level.mg_press_rest, undefined, body.angles );
    ram moveto( level.mg_press_rest - ( 0, 0, 4 ), 0.12 );
    lever rotatepitch( 8, 0.12 );
    wait 0.12;
    ram moveto( level.mg_press_rest, 0.2, 0, 0.15 );
    lever rotatepitch( -8, 0.25, 0, 0.2 );
    wait 0.3;
    mg_fx_once( "barrel_flare", bed, 3 );
    mg_fx_once( "forge_embers", bed, 3 );
    body playsound( "mg_flame_burst" );
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

// The press at work on weapon, on BO4's timeline (its scene aib_vign_zm_mob_smelter_ghost: the smelter's start anim,
// 11.4 s, then its finish; t from the gun laid down): two ghouls come out of the gun and pull the lever (t 3.4), the
// ram comes down on the gun (t 4.0, the smelter_press notetrack) and works it 7.4 s in fire and sparks, then lifts on
// the Magmagat (t 11.6, smelter_show), which glows on the bed in tiny flames until taken. The gun on the bed is held
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
    level thread mg_forge_ghouls();

    // t 3.4: the lever pulled down 45 degrees in 0.2 s (the smelter's handel_1_jnt, frames 102 to 109)
    wait 3.4;
    lever playsound( "zmb_trap_switch" );
    lever rotatepitch( 45, 0.2, 0.05, 0.05 );

    // t 3.6: the ram comes down (mg_press_down: 0.3 s, then 0.33 s) and strikes the gun at t 4.0
    wait 0.2;
    level thread mg_press_down();
    body playsound( "mg_press" );
    wait 0.43;
    mg_fx_once( "sparks", c.origin, undefined, body.angles );
    body playsound( "zmb_hellbox_slam_shake" );
    body playloopsound( "zmb_fire_loop", 0.5 );
    gun delete();

    // t 4.0 to 11.4: the press works the gun, the remaster's press fire through it and sparks from the bed
    mg_fx_once( "forge_rise", level.mg_press_rest, 7.4, body.angles );

    for ( i = 0; i < 5; i++ )
    {
        wait 1.4;
        mg_fx_once( "sparks", c.origin, undefined, body.angles );
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
    level thread mg_forge_glow( gun, c.origin );
    return gun;
}

// BO4's reveal: the Magmagat glows on the bed (a glow, no flame) over tiny flames, while it lies there.
mg_forge_glow( gun, origin )
{
    glow = mg_fx_loop( "forge_glow", origin );
    embers = mg_fx_loop( "forge_embers", origin - ( 0, 0, 2 ) );

    while ( isdefined( gun ) )
        wait 0.2;

    mg_fx_stop( glow );
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

#using_animtree("fxanim_props");

// BO4's ghouls (its scene's two fakeactors, c_t8_zmb_mob_ghoul bodies glowing blue: tools/build_ghoul_mats.pl), as its
// scene plays them: each plays its own 11.4 s animation and flies its own path around the lever, BO4's tag_origin
// track (mg_ghoul_path_data, tools/ghoul_path.pl), which a script_model does not take from the animation, so script
// moves it; they go at the animation's end_alpha (10.67 s). Script models share one animtree (Mob's fxanim_props,
// which mod.ff extends with theirs: tools/import_all.pl). Held in level.mg_forge_place_ents.
mg_forge_ghouls()
{
    level endon( "mg_goto" );
    yaw = level.mg_press["press_body"].angles[1];
    scriptmodelsuseanimtree( #animtree );
    anims = array( %mg_ghoul_smelter_1, %mg_ghoul_smelter_2 );
    ghouls = [];

    for ( i = 0; i < 2; i++ )
    {
        path = mg_ghoul_path( i, yaw );
        g = spawn( "script_model", path[0]["pos"] );
        g.angles = path[0]["ang"];
        g setmodel( mg_model( "ghoul" + ( i + 1 ) ) );
        g useanimtree( #animtree );
        g setanim( anims[i], 1, 0, 1 );
        g.mg_path = path;
        ghouls[i] = g;
        level.mg_forge_place_ents[level.mg_forge_place_ents.size] = g;
    }

    wait 0.05;    // an effect played in the frame an entity appears is dropped by the clients

    foreach ( g in ghouls )
    {
        mg_fx_add_tag( g, "ghost_body", "j_spineupper" );
        mg_fx_add_tag( g, "ghost_head", "j_head" );
        playsoundatposition( "zmb_afterlife_object_apparate", g.origin );
        g playloopsound( "zmb_afterlife_ghost_loop", 0.5 );
        g thread mg_ghoul_fly( g.mg_path );
    }

    // t 10.67, the animation's end_alpha
    wait 10.62;

    foreach ( g in ghouls )
    {
        if ( !isdefined( g ) )
            continue;

        mg_fx_once( "ghost_tport", g gettagorigin( "j_spineupper" ) );
        playsoundatposition( "zmb_afterlife_object_disapparate", g.origin );
        g delete();
    }
}

// Ghoul i's path: its keys, each ["pos"] in the world and ["ang"] (the press turned by yaw), 0.2 s apart.
mg_ghoul_path( i, yaw )
{
    keys = [];

    foreach ( item in strtok( mg_ghoul_path_data( i ), "|" ) )
    {
        v = strtok( item, "," );
        k = [];
        k["pos"] = mg_press_point( ( float( v[0] ), float( v[1] ), float( v[2] ) ) );
        k["ang"] = ( float( v[3] ), float( v[4] ) + yaw, float( v[5] ) );
        keys[keys.size] = k;
    }

    return keys;
}

// self = a ghoul: along its path, a key every 0.2 s
mg_ghoul_fly( path )
{
    self endon( "death" );

    for ( i = 1; i < path.size; i++ )
    {
        self moveto( path[i]["pos"], 0.2 );
        self rotateto( path[i]["ang"], 0.2 );
        wait 0.2;
    }
}

// ghoul paths (tools/ghoul_path.pl: BO4's, a key every 0.2 s; do not edit by hand)
mg_ghoul_path_data( i )
{
    if ( i == 0 )
        return "-86.2,-86.5,0.3,35,-26,13|-84.9,-90.2,14.6,30,-12,15|-80.8,-95.5,31.6,30,2,18|-74.0,-100.0,41.0,42,11,16|-64.5,-101.4,45.1,79,5,7|-53.5,-100.9,44.8,54,-159,-146|-38.1,-100.7,34.5,31,-166,-135|-22.1,-103.9,24.7,28,-169,-128|-11.5,-111.3,22.3,25,-166,-109|-4.2,-120.5,22.8,14,-164,-78|-2.0,-130.5,24.4,0,-177,-52|-5.8,-143.6,28.2,-1,155,-33|-12.3,-154.0,36.6,5,124,-14|-17.3,-154.0,47.7,9,117,2|-20.2,-152.4,53.6,8,123,8|-21.4,-150.8,55.3,5,127,8|-19.9,-148.9,53.0,4,126,2|-17.3,-147.2,47.3,0,132,0|-15.4,-146.7,43.6,2,142,4|-13.7,-146.8,42.3,12,153,18|-13.1,-147.0,43.6,16,148,19|-11.8,-147.6,46.6,16,152,19|-9.1,-148.8,48.3,11,152,19|-5.2,-145.8,47.9,6,154,19|-2.0,-140.2,41.9,2,160,20|0.4,-134.5,37.1,-2,167,20|1.4,-129.8,37.3,-5,170,17|0.6,-126.6,39.1,-8,169,16|-0.7,-123.9,41.6,-9,166,14|-1.6,-121.6,45.3,-7,165,14|-1.6,-119.6,47.6,-4,165,14|-1.1,-118.9,48.0,-1,168,14|-0.4,-118.4,47.9,1,172,17|0.3,-118.0,47.0,3,177,20|1.0,-117.9,45.4,5,-178,22|1.7,-117.9,43.8,8,-174,25|2.2,-117.9,42.5,12,-170,27|2.5,-117.6,41.8,15,-167,28|2.4,-116.5,41.5,16,-167,30|1.8,-113.4,41.9,14,-172,30|1.1,-108.4,43.2,14,-180,29|0.2,-101.4,45.9,21,171,27|-0.6,-92.9,48.2,34,159,21|-1.6,-82.7,48.5,47,137,8|-3.4,-71.3,46.9,59,116,-7|-5.4,-58.5,41.3,72,116,-4|-8.9,-44.8,33.6,84,128,10|-15.0,-30.1,26.5,85,46,-68|-27.9,-14.6,22.9,71,45,-65|-47.9,1.5,27.2,48,55,-49|-73.1,18.0,42.8,20,51,-37|-101.5,34.9,67.2,-2,36,-19|-131.2,51.9,97.3,-14,13,-3|-160.1,68.9,129.6,-23,-32,25|-186.3,86.5,160.5,-5,-86,64|-206.7,104.3,186.7,16,-102,73|-213.7,110.1,200.7,20,-102,68|-214.7,110.3,201.9,32,-122,72";

    return "-80.1,-95.7,3.1,-10,-147,22|-80.2,-95.6,10.0,-12,-147,17|-80.2,-95.5,25.0,-14,-145,11|-79.7,-94.6,40.6,-29,-147,23|-77.4,-90.1,53.4,-42,180,72|-73.7,-82.0,58.6,-22,158,105|-67.9,-71.2,52.2,0,158,122|-58.0,-58.9,41.2,18,171,135|-49.3,-45.9,32.0,24,-160,127|-48.5,-32.6,25.2,14,-143,114|-57.9,-19.8,21.0,-1,-126,96|-72.8,-13.0,21.1,-12,-99,69|-87.9,-13.2,25.9,-16,-64,47|-98.2,-15.9,34.9,-15,-36,18|-98.7,-19.2,44.9,-9,-30,7|-97.6,-21.1,53.0,-8,-32,4|-95.5,-20.6,53.8,-9,-37,5|-92.9,-18.9,48.1,-10,-43,6|-91.7,-17.1,44.1,-8,-51,4|-91.1,-15.5,42.2,5,-62,-6|-91.0,-14.8,43.3,11,-57,-7|-91.2,-13.6,46.2,11,-60,-7|-91.6,-10.7,48.1,8,-60,-8|-88.3,-7.9,48.4,4,-61,-9|-81.9,-6.6,43.0,-1,-66,-11|-75.0,-6.0,38.3,-3,-74,-14|-68.5,-6.5,39.7,-3,-80,-13|-64.0,-8.3,42.9,-3,-87,-8|-60.7,-10.9,47.1,-1,-98,-1|-59.0,-13.5,52.1,4,-111,6|-62.5,-16.0,56.9,19,-125,18|-74.6,-18.3,57.6,49,-117,49|-90.5,-20.0,54.4,57,-94,81|-110.6,-22.1,53.0,59,-88,79|-130.8,-26.0,53.7,72,-101,54|-148.2,-32.9,57.4,76,164,-50|-162.9,-44.4,63.4,53,145,-80|-177.3,-64.2,73.5,36,155,-88|-181.7,-97.4,81.8,15,172,-85|-177.5,-126.5,83.5,8,-172,-83|-165.7,-152.0,80.0,18,-154,-86|-142.4,-177.6,73.7,29,-135,-85|-114.3,-194.0,67.6,38,-113,-81|-84.3,-192.7,64.7,43,-91,-76|-57.2,-183.1,63.5,40,-75,-79|-41.4,-170.2,63.2,40,-60,-81|-30.2,-156.2,63.5,41,-47,-82|-21.0,-141.2,65.7,46,-31,-82|-15.9,-125.4,68.7,51,-14,-80|-16.3,-109.0,72.4,56,8,-72|-22.0,-91.6,78.9,59,31,-62|-31.1,-72.0,90.2,60,49,-55|-43.2,-53.4,106.4,61,65,-49|-61.3,-37.6,126.6,62,78,-45|-79.6,-23.9,147.1,63,92,-40|-93.7,-14.4,163.9,64,106,-34|-100.8,-11.1,178.2,62,123,-23|-103.2,-11.1,189.3,61,126,-18";
}
// end ghoul paths
