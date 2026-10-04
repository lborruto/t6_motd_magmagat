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
    scriptmodelsuseanimtree( #animtree );
    anims = array( %mg_ghoul_smelter_1, %mg_ghoul_smelter_2 );
    ghouls = [];

    for ( i = 0; i < 2; i++ )
    {
        path = mg_ghoul_path( i );
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

// Ghoul i's path around the lever (MG_LEVER: its frame, turned by its yaw; heights from the machine's floor): its keys,
// each ["pos"] and ["ang"] in the world, 0.2 s apart.
mg_ghoul_path( i )
{
    l = mg_coord( "MG_LEVER" );
    yaw = l.angles[1];
    floor = mg_coord( "MG_PRESS" ).origin[2];
    keys = [];

    foreach ( item in strtok( mg_ghoul_path_data( i ), "|" ) )
    {
        v = strtok( item, "," );
        k = [];
        x = float( v[0] );
        y = float( v[1] );
        k["pos"] = ( l.origin[0] + x * cos( yaw ) - y * sin( yaw ), l.origin[1] + x * sin( yaw ) + y * cos( yaw ), floor + float( v[2] ) );
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
        return "58.1,86.3,0.3,35,154,13|56.8,89.9,14.6,30,168,15|52.7,95.3,31.6,30,-178,18|45.9,99.8,41.0,42,-169,16|36.4,101.1,45.1,79,-175,7|25.4,100.6,44.8,54,21,-146|10.0,100.5,34.5,31,14,-135|-6.0,103.7,24.7,28,11,-128|-16.6,111.1,22.3,25,14,-109|-23.9,120.2,22.8,14,16,-78|-26.1,130.2,24.4,0,3,-52|-22.2,143.3,28.2,-1,-25,-33|-15.8,153.8,36.6,5,-56,-14|-10.8,153.8,47.7,9,-63,2|-7.9,152.2,53.6,8,-57,8|-6.7,150.5,55.3,5,-53,8|-8.2,148.7,53.0,4,-54,2|-10.8,146.9,47.3,0,-48,0|-12.7,146.5,43.6,2,-38,4|-14.4,146.5,42.3,12,-27,18|-15.0,146.7,43.6,16,-32,19|-16.3,147.4,46.6,16,-28,19|-19.0,148.6,48.3,11,-28,19|-22.9,145.6,47.9,6,-26,19|-26.0,139.9,41.9,2,-20,20|-28.5,134.2,37.1,-2,-13,20|-29.5,129.5,37.3,-5,-10,17|-28.7,126.4,39.1,-8,-11,16|-27.4,123.7,41.6,-9,-14,14|-26.5,121.3,45.3,-7,-15,14|-26.5,119.4,47.6,-4,-15,14|-27.0,118.6,48.0,-1,-12,14|-27.7,118.1,47.9,1,-8,17|-28.4,117.8,47.0,3,-3,20|-29.1,117.7,45.4,5,2,22|-29.8,117.7,43.8,8,6,25|-30.3,117.6,42.5,12,10,27|-30.6,117.3,41.8,15,13,28|-30.5,116.3,41.5,16,13,30|-29.9,113.2,41.9,14,8,30|-29.2,108.1,43.2,14,0,29|-28.3,101.2,45.9,21,-9,27|-27.5,92.6,48.2,34,-21,21|-26.5,82.5,48.5,47,-43,8|-24.7,71.0,46.9,59,-64,-7|-22.7,58.3,41.3,72,-64,-4|-19.2,44.5,33.6,84,-52,10|-13.1,29.8,26.5,85,-134,-68|-0.2,14.3,22.9,71,-135,-65|19.9,-1.7,27.2,48,-125,-49|45.0,-18.3,42.8,20,-129,-37|73.4,-35.1,67.2,-2,-144,-19|103.1,-52.1,97.3,-14,-167,-3|132.0,-69.1,129.6,-23,148,25|158.2,-86.8,160.5,-5,94,64|178.6,-104.5,186.7,16,78,73|185.6,-110.3,200.7,20,78,68|186.6,-110.5,201.9,32,58,72";

    return "52.0,95.4,3.1,-10,33,22|52.1,95.4,10.0,-12,33,17|52.1,95.2,25.0,-14,35,11|51.6,94.3,40.6,-29,33,23|49.3,89.8,53.4,-42,-0,72|45.6,81.7,58.6,-22,-22,105|39.8,70.9,52.2,0,-22,122|29.9,58.6,41.2,18,-9,135|21.2,45.6,32.0,24,20,127|20.4,32.3,25.2,14,37,114|29.8,19.6,21.0,-1,54,96|44.7,12.7,21.1,-12,81,69|59.8,12.9,25.9,-16,116,47|70.1,15.6,34.9,-15,144,18|70.6,18.9,44.9,-9,150,7|69.5,20.8,53.0,-8,148,4|67.4,20.4,53.8,-9,143,5|64.8,18.6,48.1,-10,137,6|63.6,16.9,44.1,-8,129,4|63.0,15.3,42.2,5,118,-6|62.9,14.5,43.3,11,123,-7|63.1,13.3,46.2,11,120,-7|63.5,10.4,48.1,8,120,-8|60.2,7.6,48.4,4,119,-9|53.8,6.3,43.0,-1,114,-11|46.9,5.7,38.3,-3,106,-14|40.4,6.2,39.7,-3,100,-13|35.9,8.0,42.9,-3,93,-8|32.6,10.6,47.1,-1,82,-1|30.9,13.2,52.1,4,69,6|34.5,15.8,56.9,19,55,18|46.5,18.0,57.6,49,63,49|62.4,19.7,54.4,57,86,81|82.5,21.9,53.0,59,92,79|102.7,25.8,53.7,72,79,54|120.1,32.6,57.4,76,-16,-50|134.8,44.1,63.4,53,-35,-80|149.2,64.0,73.5,36,-25,-88|153.6,97.1,81.8,15,-8,-85|149.4,126.2,83.5,8,8,-83|137.6,151.7,80.0,18,26,-86|114.3,177.4,73.7,29,45,-85|86.2,193.7,67.6,38,67,-81|56.2,192.4,64.7,43,89,-76|29.1,182.8,63.5,40,105,-79|13.3,169.9,63.2,40,120,-81|2.1,155.9,63.5,41,133,-82|-7.1,140.9,65.7,46,149,-82|-12.2,125.1,68.7,51,166,-80|-11.8,108.7,72.4,56,-172,-72|-6.1,91.3,78.9,59,-149,-62|3.0,71.7,90.2,60,-131,-55|15.1,53.2,106.4,61,-115,-49|33.2,37.3,126.6,62,-102,-45|51.5,23.7,147.1,63,-88,-40|65.6,14.1,163.9,64,-74,-34|72.7,10.8,178.2,62,-57,-23|75.1,10.8,189.3,61,-54,-18";
}
// end ghoul paths
