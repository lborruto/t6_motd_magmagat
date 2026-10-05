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
    level.mg_models["barrel"] = "mg_barrel_green"; // mod.ff: the remaster's drum at its five barrel spots (dark green; the flame is blue)
    level.mg_models["barrel_fill"] = "mg_barrel_fill"; // mod.ff (tools/barrel_fill.pl): its filling, BO4's ash and burnt splinters 2/3 up
    level.mg_models["gun_world"] = "t6_wpn_zmb_blundergat_world";
    level.mg_models["ball"] = "mg_magma_blob"; // mod.ff (tools/import_all.pl): BO4's own lava blob, p8_fxp_magma_blob, as the weapon files ($blob in tools/build_weapon.pl)
    level.mg_models["press_body"] = "mg_press_body"; // mod.ff: the remaster's press (p8_zm_esc_machinery_01) without its ram
    level.mg_models["press_ram"] = "mg_press_ram"; // its ram, which script brings down
    level.mg_models["beacon"] = "p6_zm_al_candle_tall_on"; // visible stand-in for point anchors (no prop of their own)
    level.mg_models["skull_bo4"] = "mg_skull_bo4"; // mod.ff: BO4's mantle skull, plain (its quest's three)
    level.mg_models["skull_bo4_lit"] = "mg_skull_bo4_lit"; // mod.ff: BO4's lit one, the Afterlife skull, once filled
    level.mg_models["press_lever"] = "mg_press_lever"; // mod.ff: BO4's smelter's lever on the press, pivot at its origin
    level.mg_models["ghoul1"] = "mg_ghoul1"; // mod.ff: BO4's ghouls, the ghosts that pull the lever (skinned, Afterlife ghost material)
    level.mg_models["ghoul2"] = "mg_ghoul2";
    level.mg_models["chain_hang"] = "p6_zm_al_chain_drop_long"; // zm_prison's: a chain hanging down the forge machine
    level.mg_models["chain_loop"] = "p6_zm_al_chain_loop"; // zm_prison's: a chain looped round its foot
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

    // the fireplace, its use spot and its skulls: placeholders at the desk; the owner's grabs (mg_apply_overrides) set them
    mg_coord_set( "MG_HEARTH", ( -767, 8662, 1372 ), ( 0, 180, 0 ), mg_model( "gun_world" ) );
    mg_coord_set( "MG_HEARTH_USE", ( -433, 8762, 1353 ), ( 0, 135, 0 ), mg_model( "beacon" ) );
    mg_coord_set( "MG_SKULL_1", ( -495, 8784, 1409 ), ( 0, 135, 0 ), mg_model( "skull_bo4" ) );
    mg_coord_set( "MG_SKULL_2", ( -475, 8804, 1409 ), ( 0, 135, 0 ), mg_model( "skull_bo4" ) );
    mg_coord_set( "MG_SKULL_3", ( -455, 8824, 1409 ), ( 0, 135, 0 ), mg_model( "skull_bo4" ) );

    // barrels along the route (spec: office exit, top of the spiral stairs, bottom of the tunnels, generator door):
    // placeholders on the zone volume origins of tools/assets/zm_prison.d3dbsp.ents.txt
    mg_coord_set( "MG_BARREL_1", ( -600, 9100, 1336 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_2", ( 227, 8713, 761 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_3", ( 80, 7954, 211 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_4", ( -400, 6500, 72 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_5", ( -62, 7007, 88 ), ( 0, 184, 0 ), mg_model( "barrel" ) ); // owner: five barrels on the route

    // forge: placeholders near the Generator Room (the overrides stand it where the owner set it; mg_forge spawns the press)
    mg_coord_set( "MG_FORGE", ( -400, 6330, 72 ), ( 0, 190.7, 0 ), mg_model( "beacon" ) );
    mg_coord_set( "MG_FORGE_GUN", ( -449, 6307, 120 ), ( 0, 280, -90 ), mg_model( "gun_world" ) );

    mg_apply_overrides();

    // the forge's machine (its foot): the owner pinned it (mg_apply_overrides), so this default is only the fallback,
    // where the remaster's gun spot puts it (mg_upgrade_struct 44 over the bed's foot, 8.75 back, 6.51 aside);
    // `!mg grab MG_PRESS` moves it, the gun spot and the use spot with it
    gun = level.mg_coords["MG_FORGE_GUN"];
    yaw = gun.angles[1] + 90;
    foot = gun.origin + anglestoforward( ( 0, yaw, 0 ) ) * -8.75 + anglestoright( ( 0, yaw, 0 ) ) * 6.51 - ( 0, 0, 44 );
    mg_coord_set( "MG_PRESS", foot, ( 0, yaw, 0 ), mg_model( "press_body" ) );

    // BO4's lever on the machine (its pivot): pinned by the owner too, so this default is only the fallback, where the
    // smelter has it next to its smasher, the smelter's smasher and our ram being one mesh at 0.755 scale (the
    // smasher's centre + (33.5, 0, -30.6) scaled, from our ram's centre (5.4, -0.25, 86.5)), on the machine's other side
    // (the remaster's machine faces the other way than BO4's), its grips out toward the player as the machine faces;
    // `!mg grab MG_LEVER` places it, and the forge's ghouls fly to its grips (mg_forge_ghouls). The machine and the
    // lever read below are the pinned ones.
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

    // chains on the machine's feet, as BO4's forge wears them (the owner's wish): zm_prison's own, two hanging down
    // its corners and two looped round its feet, at the corners of its foot (77 x 134); `!mg grab MG_CHAIN_1..4`
    // places them on it
    kinds = array( "chain_hang", "chain_loop" );

    foreach ( i, corner in array( ( 34, 60, 30 ), ( 34, -60, 12 ), ( -30, 60, 30 ), ( -30, -60, 12 ) ) )
    {
        spot = press.origin + anglestoforward( ( 0, p, 0 ) ) * corner[0] - anglestoright( ( 0, p, 0 ) ) * corner[1] + ( 0, 0, corner[2] );
        mg_coord_set( "MG_CHAIN_" + ( i + 1 ), spot, ( 0, p, 0 ), mg_model( kinds[i % 2] ) );
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

    mg_coord_override( "MG_BARREL_1", ( -468, 9403, 1359 ), ( 0, 248, 0 ) ); // 1 down: it stood off the floor

    mg_coord_override( "MG_BARREL_2", ( 270, 8855, 1151 ), ( 0, 248, 0 ) ); // 1 down: it stood off the floor

    mg_coord_override( "MG_BARREL_3", ( 268, 8828, 856 ), ( 0, 351, 0 ) ); // 8 up: it sank into the floor

    mg_coord_override( "MG_BARREL_4", ( 85, 8697, 399 ), ( 0, 8, 0 ) );

    mg_coord_override( "MG_BARREL_5", ( -62, 7007, 87 ), ( 0, 184, 0 ) ); // 1 down: it stood off the floor

    // the forge: the machine stands where the owner set it (his grab, 2026-10-04: press
    // -310 6358 64, yaw 101; the remaster's spot was 136 6655 72, yaw 190.7); the machine, its gun spot on the bed and its
    // lever are each pinned by the owner's grabs below
    mg_coord_override( "MG_FORGE", ( -315.9, 6383.5, 64 ), ( 0, 101, 0 ) );

    // the machine pinned where it stood (its default follows the gun spot, which the owner then fitted on its bed). Its
    // model is given: pinned before its default is set, it has no anchor yet to keep one from (`!mg grab`, `!mg show`)
    mg_coord_override( "MG_PRESS", ( -310, 6358, 64 ), ( 0, 101, 0 ), mg_model( "press_body" ) );
    mg_coord_override( "MG_FORGE_GUN", ( -311, 6367, 112 ), ( 0, 11, 0 ) );

    // its lever, fitted on the machine by the owner (2026-10-05)
    mg_coord_override( "MG_LEVER", ( -316, 6385, 131 ), ( 0, 101, 0 ), mg_model( "press_lever" ) );    // its grips out, toward the player
}

mg_coord_set( key, origin, angles, model )
{
    if ( isdefined( level.mg_coords[key] ) && is_true( level.mg_coords[key].overridden ) )
        return;

    level.mg_coords[key] = mg_coord_make( origin, angles, model );
}

// An override without a model keeps the model of the existing anchor, if any.
mg_coord_override( key, origin, angles, model )
{
    if ( !isdefined( model ) && isdefined( level.mg_coords[key] ) )
        model = level.mg_coords[key].model;

    c = mg_coord_make( origin, angles, model );
    c.overridden = 1;
    level.mg_coords[key] = c;
}

// an anchor: where it stands, how it turns, the prop that shows it (undefined for none)
mg_coord_make( origin, angles, model )
{
    c = spawnstruct();
    c.origin = origin;
    c.angles = angles;
    c.model = model;
    return c;
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
