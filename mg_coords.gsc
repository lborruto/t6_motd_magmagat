#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;

// Anchors (origin + angles) and prop models. Defaults are placeholders around the vanilla free-Blundergat desk
// struct sq_bg_reward (-767 8662.5 1370.5, tools/assets/zm_prison.d3dbsp.ents.txt) and the dock generator
// generator_core (-449 6307 72). The owner records the real spots in game (`!mg grab KEY`, `!mg spots`) and
// pastes them into mg_apply_overrides below: an override always wins over a default.

mg_models_init()
{
    level.mg_models = [];
    level.mg_models["skull"] = "mg_skull"; // mod.ff (tools/import_all.pl): the BO3 remaster's skull
    level.mg_models["barrel"] = "mg_barrel_green"; // mod.ff: the remaster's drum at its five barrel spots (dark green; the flame is blue)

    if ( mg_bo4( "barrels" ) )
        level.mg_models["barrel"] = "mg_barrel_bo4"; // mod.ff: BO4's drum, p8_zm_esc_barrel_drum
    level.mg_models["gun_world"] = "t6_wpn_zmb_blundergat_world";
    level.mg_models["ball"] = "mg_magma_blob"; // mod.ff (tools/import_all.pl): BO4's own lava blob, p8_fxp_magma_blob, as the weapon files ($blob in tools/build_weapon.pl)
    level.mg_models["press_body"] = "mg_press_body"; // mod.ff: the remaster's press (p8_zm_esc_machinery_01) without its ram
    level.mg_models["press_ram"] = "mg_press_ram"; // its ram, which script brings down
    level.mg_models["beacon"] = "p6_zm_al_candle_tall_on"; // visible stand-in for point anchors (no prop of their own)
    level.mg_models["puddle"] = "mg_fx_magma_splat02_mesh"; // mod.ff: the remaster's lava splat, a pool's lava with mg_bo4 "pool"
    level.mg_models["skull_bo4"] = "mg_skull_bo4"; // mod.ff: BO4's mantle skull, plain (dvar mg_bo4 "skulls")
    level.mg_models["skull_bo4_lit"] = "mg_skull_bo4_lit"; // mod.ff: BO4's lit one, the Afterlife skull, once filled
    level.mg_models["press_lever"] = "mg_press_lever"; // mod.ff: BO4's smelter's lever on the press, pivot at its origin
    level.mg_models["ghoul1"] = "mg_ghoul1"; // mod.ff: BO4's ghouls, the ghosts that pull the lever (skinned, Afterlife ghost material)
    level.mg_models["ghoul2"] = "mg_ghoul2";
    level.mg_models["skull_pile1"] = "mg_skull_pile_sml"; // mod.ff: BO4's skull piles by the fireplace (dvar mg_bo4 "piles")
    level.mg_models["skull_pile2"] = "mg_skull_pile_med";
    level.mg_models["press_clip"] = "collision_clip_64x64x128"; // common_zm: the forge machine's collision for players and zombies, centred
    level.mg_models["clip"] = "collision_clip_32x32x128"; // common_zm, always loaded: player collision for the barrels (a script_model alone has none), centred
    level.mg_models["player_clip"] = "collision_player_32x32x128"; // patch_zm, always loaded: blocks players only (the office door in the lockdown), centred
}

mg_model( kind )
{
    if ( !isdefined( level.mg_models ) )
        mg_models_init();

    if ( isdefined( level.mg_models[kind] ) )
        return level.mg_models[kind];

    mg_debug_print( "MG: unknown model kind " + kind );
    return "tag_origin";
}

// init() only.
mg_precache()
{
    if ( !isdefined( level.mg_models ) )
        mg_models_init();

    foreach ( kind, name in level.mg_models )
        if ( name != "tag_origin" )
            precachemodel( name );
}

mg_coords_init()
{
    if ( isdefined( level.mg_coords ) )
        return;

    level.mg_coords = [];

    // hearth: placeholder position at the desk until overridden below; the skulls and the use point are
    // already derived from the owner's real MG_HEARTH spot (mg_apply_overrides), adjust with !mg grab if the
    // hearth ever moves again
    mg_coord_set( "MG_HEARTH", ( -767, 8662, 1372 ), ( 0, 180, 0 ), mg_model( "gun_world" ) );
    mg_coord_set( "MG_HEARTH_USE", ( -433, 8762, 1353 ), ( 0, 135, 0 ), mg_model( "beacon" ) ); // derived from the owner's MG_HEARTH spot; adjust with !mg grab
    mg_coord_set( "MG_SKULL_1", ( -495, 8784, 1409 ), ( 0, 135, 0 ), mg_model( "skull" ) ); // derived from the owner's MG_HEARTH spot; adjust with !mg grab
    mg_coord_set( "MG_SKULL_2", ( -475, 8804, 1409 ), ( 0, 135, 0 ), mg_model( "skull" ) ); // derived from the owner's MG_HEARTH spot; adjust with !mg grab
    mg_coord_set( "MG_SKULL_3", ( -455, 8824, 1409 ), ( 0, 135, 0 ), mg_model( "skull" ) ); // derived from the owner's MG_HEARTH spot; adjust with !mg grab
    // BO4's skull piles (mg_bo4 "piles"): on the floor at each end of the mantle, 35 past the outer skulls and 20 out
    // into the office (from the owner's skull overrides); adjust with !mg grab
    mg_coord_set( "MG_SKULL_PILE_1", ( -517, 8830, 1336 ), ( 0, 315, 0 ), mg_model( "skull_pile1" ) );
    mg_coord_set( "MG_SKULL_PILE_2", ( -422, 8735, 1336 ), ( 0, 315, 0 ), mg_model( "skull_pile2" ) );

    // barrels along the route (spec: office exit, top of the spiral stairs, bottom of the tunnels, generator door):
    // placeholders on the zone volume origins of tools/assets/zm_prison.d3dbsp.ents.txt
    mg_coord_set( "MG_BARREL_1", ( -600, 9100, 1336 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_2", ( 227, 8713, 761 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_3", ( 80, 7954, 211 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_4", ( -400, 6500, 72 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_5", ( -62, 7007, 88 ), ( 0, 184, 0 ), mg_model( "barrel" ) ); // owner: five barrels on the route

    // forge: placeholders near the Generator Room (the override stands it where the remaster's is; mg_forge spawns the press)
    mg_coord_set( "MG_FORGE", ( -400, 6330, 72 ), ( 0, 190.7, 0 ), mg_model( "beacon" ) );
    mg_coord_set( "MG_FORGE_GUN", ( -449, 6307, 120 ), ( 0, 280, -90 ), mg_model( "gun_world" ) );


    mg_apply_overrides();

    // the forge's machine (its foot): by default where the remaster's gun spot puts it (mg_upgrade_struct 44 over the
    // bed's foot, 8.75 back, 6.51 aside); `!mg grab MG_PRESS` moves it, the gun spot and the use spot with it
    gun = level.mg_coords["MG_FORGE_GUN"];
    yaw = gun.angles[1] + 90;
    foot = gun.origin + anglestoforward( ( 0, yaw, 0 ) ) * -8.75 + anglestoright( ( 0, yaw, 0 ) ) * 6.51 - ( 0, 0, 44 );
    mg_coord_set( "MG_PRESS", foot, ( 0, yaw, 0 ), mg_model( "press_body" ) );

    // BO4's lever on the machine (its pivot): by default where the smelter has it next to its smasher, the smelter's
    // smasher and our ram being one mesh at 0.755 scale (the smasher's centre + (33.5, 0, -30.6) scaled, from our ram's
    // centre (5.4, -0.25, 86.5)), on the machine's other side (the remaster's machine faces the other way than BO4's),
    // its grips out toward the player as the machine faces; `!mg grab MG_LEVER` places it, and the forge's ghouls fly
    // to its grips (mg_forge_ghouls)
    press = level.mg_coords["MG_PRESS"];
    p = press.angles[1];
    lever = press.origin + anglestoforward( ( 0, p, 0 ) ) * -28.1 + anglestoright( ( 0, p, 0 ) ) * 0.26 + ( 0, 0, 55.9 );
    mg_coord_set( "MG_LEVER", lever, ( 0, p, 0 ), mg_model( "press_lever" ) );

    // where the machine's own effects play (its power, its fire): the machine's origin and turn by default, a beacon to
    // fit them on it with `!mg grab MG_FORGE_FX` (the remaster's effects were made for its machine where it stood)
    mg_coord_set( "MG_FORGE_FX", press.origin, press.angles, mg_model( "beacon" ) );

    // the forge's ghouls, each at its grip of the lever: 53 along its shaft, 14 out of the machine, its origin (the
    // ghoul's waist) 8 under the grip so its hands are on it, turned to it; `!mg grab MG_GHOUL_1` / `_2` places them
    l = level.mg_coords["MG_LEVER"];
    ly = ( 0, l.angles[1], 0 );
    grip = l.origin + anglestoforward( ly ) * 8 + ( 0, 0, 10.5 );

    foreach ( i, side in array( -1, 1 ) )
    {
        spot = grip - anglestoright( ly ) * ( side * 53 ) + anglestoforward( ly ) * 14 - ( 0, 0, 8 );
        mg_coord_set( "MG_GHOUL_" + ( i + 1 ), spot, ( 0, l.angles[1] + 180, 0 ), mg_model( "ghoul" + ( i + 1 ) ) );
    }
}

// Owner spots go here, one line each: mg_coord_override( "KEY", ( x, y, z ), ( pitch, yaw, roll ) );
mg_apply_overrides()
{
    mg_coord_override( "MG_HEARTH", ( -475.7, 8805.4, 1357 ), ( 0, 315, 0 ) ); // the remaster's gun spot in the fire (its struct pf93_auto2, BO3 -3966.34 3753.71 2709, yaw 315, by the office fit)

    // owner grab pass 2026-09-18 (evening)
    mg_coord_override( "MG_SKULL_1", ( -506, 8819, 1424 ), ( 0, 315, 0 ) );

    mg_coord_override( "MG_SKULL_2", ( -483, 8796, 1424 ), ( 0, 315, 0 ) );

    mg_coord_override( "MG_SKULL_3", ( -461, 8774, 1424 ), ( 0, 315, 0 ) );

    mg_coord_override( "MG_HEARTH_USE", ( -489, 8787, 1336 ), ( 0, 237, 0 ) );

    mg_coord_override( "MG_BARREL_1", ( -468, 9403, 1360 ), ( 0, 248, 0 ) );

    mg_coord_override( "MG_BARREL_2", ( 270, 8855, 1152 ), ( 0, 248, 0 ) );

    mg_coord_override( "MG_BARREL_3", ( 268, 8828, 856 ), ( 0, 351, 0 ) ); // 8 up: it sank into the floor

    mg_coord_override( "MG_BARREL_4", ( 85, 8697, 399 ), ( 0, 8, 0 ) );

    mg_coord_override( "MG_BARREL_5", ( -62, 7007, 88 ), ( 0, 184, 0 ) );

    // the forge: the machine stands where BO4's own fits, turned to face as the owner set it (his grab, 2026-10-04: press
    // -310 6358 64, yaw 101; the remaster's spot was 136 6655 72, yaw 190.7); the gun on its bed and the use trigger keep
    // the remaster's offsets from it (mg_upgrade_struct -7.4 -8.0 44, tr_forge -25.5 -5.7), and mg_press_spawn stands
    // the machine back from the gun
    mg_coord_override( "MG_FORGE", ( -315.9, 6383.5, 64 ), ( 0, 101, 0 ) );

    mg_coord_override( "MG_FORGE_GUN", ( -318.1, 6365.3, 108 ), ( 0, 11, 0 ) );

    // its lever, fitted on the machine by the owner (2026-10-05)
    mg_coord_override( "MG_LEVER", ( -316, 6385, 131 ), ( 0, 101, 0 ) );    // its grips out, toward the player
}

mg_coord_set( key, origin, angles, model )
{
    if ( isdefined( level.mg_coords[key] ) && is_true( level.mg_coords[key].overridden ) )
        return;

    c = spawnstruct();
    c.origin = origin;
    c.angles = angles;
    c.model = model;
    level.mg_coords[key] = c;
}

// An override without a model keeps the model of the existing anchor, if any.
mg_coord_override( key, origin, angles, model )
{
    if ( !isdefined( model ) && isdefined( level.mg_coords[key] ) )
        model = level.mg_coords[key].model;

    c = spawnstruct();
    c.origin = origin;
    c.angles = angles;
    c.model = model;
    c.overridden = 1;
    level.mg_coords[key] = c;
}

mg_coord( key )
{
    if ( !isdefined( level.mg_coords ) )
        mg_coords_init();

    if ( !isdefined( level.mg_coords[key] ) )
    {
        mg_debug_print( "MG: unknown anchor " + key );
        return undefined;
    }

    return level.mg_coords[key];
}

mg_coords_keys()
{
    if ( !isdefined( level.mg_coords ) )
        mg_coords_init();

    return getarraykeys( level.mg_coords );
}

mg_vec_str( v )
{
    return int( v[0] ) + " " + int( v[1] ) + " " + int( v[2] );
}

mg_coord_line( key )
{
    c = mg_coord( key );

    if ( !isdefined( c ) )
        return key + ": undefined";

    line = key + " | " + mg_vec_str( c.origin ) + " | " + mg_vec_str( c.angles );

    if ( isdefined( c.model ) )
        line += " | " + c.model;

    if ( is_true( c.overridden ) )
        line += " (override)";

    return line;
}
