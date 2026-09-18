#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;

// Anchors (origin + angles) and prop models. Defaults are placeholders around the vanilla free-Blundergat desk
// struct sq_bg_reward (-767 8662.5 1370.5, tools/assets/zm_prison.d3dbsp.ents.txt) and the dock generator
// generator_core (-449 6307 72). The owner records the real spots in game (cheats `!place` / `!spot KEY`) and
// pastes them into mg_apply_overrides below: an override always wins over a default.

mg_models_init()
{
    level.mg_models = [];
    level.mg_models["skull"] = "p6_zm_al_skull";
    level.mg_models["barrel"] = "p6_zm_al_wood_barrel_01";
    level.mg_models["candle"] = "p6_zm_al_candle_med_on";
    level.mg_models["gun_world"] = "t6_wpn_zmb_blundergat_world";
    level.mg_models["ball"] = "t6_wpn_zmb_projectile_blundergat";
    level.mg_models["beacon"] = "p6_zm_al_candle_tall_on"; // visible stand-in for point anchors (no prop of their own)
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

    // barrels along the route (spec: office exit, top of the spiral stairs, bottom of the tunnels, generator door):
    // placeholders on the zone volume origins of tools/assets/zm_prison.d3dbsp.ents.txt
    mg_coord_set( "MG_BARREL_1", ( -600, 9100, 1336 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_2", ( 227, 8713, 761 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_3", ( 80, 7954, 211 ), ( 0, 0, 0 ), mg_model( "barrel" ) );
    mg_coord_set( "MG_BARREL_4", ( -400, 6500, 72 ), ( 0, 0, 0 ), mg_model( "barrel" ) );

    // forge: the left generator of the Generator Room (existing map model, nothing spawned)
    mg_coord_set( "MG_FORGE", ( -400, 6330, 72 ), ( 0, 190.7, 0 ), mg_model( "beacon" ) );
    mg_coord_set( "MG_FORGE_GUN", ( -449, 6307, 120 ), ( 0, 280, -90 ), mg_model( "gun_world" ) );


    mg_apply_overrides();
}

// Owner spots go here, one line each: mg_coord_override( "KEY", ( x, y, z ), ( pitch, yaw, roll ) );
mg_apply_overrides()
{
    mg_coord_override( "MG_HEARTH", ( -475, 8804, 1353 ), ( 0, 135, -90 ) ); // owner spot 2026-09-18 (yaw 495 = 135; roll -90 lays the gun flat as the vanilla desk gun)
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
