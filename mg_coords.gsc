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

    // hearth: placeholders at the desk until the owner spots the real fireplace
    mg_coord_set( "MG_HEARTH", ( -767, 8662, 1372 ), ( 0, 180, 0 ) );
    mg_coord_set( "MG_HEARTH_USE", ( -720, 8662, 1370 ), ( 0, 180, 0 ) );
    mg_coord_set( "MG_SKULL_1", ( -767, 8632, 1400 ), ( 0, 180, 0 ) );
    mg_coord_set( "MG_SKULL_2", ( -767, 8662, 1400 ), ( 0, 180, 0 ) );
    mg_coord_set( "MG_SKULL_3", ( -767, 8692, 1400 ), ( 0, 180, 0 ) );

    // barrels along the route (spec: office exit, top of the spiral stairs, bottom of the tunnels, generator door):
    // placeholders on the zone volume origins of tools/assets/zm_prison.d3dbsp.ents.txt
    mg_coord_set( "MG_BARREL_1", ( -600, 9100, 1336 ), ( 0, 0, 0 ) );
    mg_coord_set( "MG_BARREL_2", ( 227, 8713, 761 ), ( 0, 0, 0 ) );
    mg_coord_set( "MG_BARREL_3", ( 80, 7954, 211 ), ( 0, 0, 0 ) );
    mg_coord_set( "MG_BARREL_4", ( -400, 6500, 72 ), ( 0, 0, 0 ) );

    // forge: the left generator of the Generator Room (existing map model, nothing spawned)
    mg_coord_set( "MG_FORGE", ( -400, 6330, 72 ), ( 0, 190.7, 0 ) );
    mg_coord_set( "MG_FORGE_GUN", ( -449, 6307, 120 ), ( 0, 280, -90 ) );

    mg_apply_overrides();
}

// Owner spots go here, one line each: mg_coord_override( "KEY", ( x, y, z ), ( pitch, yaw, roll ) );
mg_apply_overrides()
{
}

mg_coord_set( key, origin, angles )
{
    if ( isdefined( level.mg_coords[key] ) && is_true( level.mg_coords[key].overridden ) )
        return;

    c = spawnstruct();
    c.origin = origin;
    c.angles = angles;
    level.mg_coords[key] = c;
}

mg_coord_override( key, origin, angles )
{
    c = spawnstruct();
    c.origin = origin;
    c.angles = angles;
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

    tag = "";

    if ( is_true( c.overridden ) )
        tag = " (override)";

    return key + " | " + mg_vec_str( c.origin ) + " | " + mg_vec_str( c.angles ) + tag;
}
