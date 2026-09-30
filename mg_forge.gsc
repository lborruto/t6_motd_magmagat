#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_run;
#include scripts\zm\zm_prison\mg_weapon;

// The forge: the remaster's Machine (mg_upgrade_machine) in the dock Generator Room, as _zm_weap_magmagat.gsc runs it.
// During the temper run the carrier powers it: that ends the run in success and opens the forge to every player for
// good. Then any of the four Blundergats placed on its bed is pressed (5.65 s: the ram down, the press fire, the
// Magmagat on the bed as the ram lifts), and only the player who placed it may take the Magmagat, within 15 s or it
// is lost.

mg_forge_init()
{
    level.mg_forge_open = 0;
    level.mg_forge_busy = 0;
    mg_press_spawn();
    level thread mg_forge_prompt_loop();
}

// The remaster's press (p8_zm_esc_machinery_01, mg_upgrade_machine), placed as the remaster places it around the
// gun on its bed (mg_upgrade_struct): turned 90 degrees from the gun, (-8.75, -6.51) in its own frame, 44 below.
mg_press_spawn()
{
    c = mg_coord( "MG_FORGE_GUN" );
    yaw = c.angles[1] + 90;
    fwd = anglestoforward( ( 0, yaw, 0 ) );
    left = anglestoright( ( 0, yaw, 0 ) ) * -1;
    origin = c.origin + fwd * -8.75 + left * -6.51 - ( 0, 0, 44 );
    level.mg_press = [];

    foreach ( part in array( "press_body", "press_ram" ) )
    {
        m = spawn( "script_model", origin );
        m.angles = ( 0, yaw, 0 );
        m setmodel( mg_model( part ) );
        level.mg_press[part] = m;
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

// What the forge offers this player right now, or undefined: the remaster's tr_forge hints (the Acid Gat station's
// ZM_PRISON_CONVERT_START / ZM_PRISON_MISSING_BLUNDERGAT and its own ZM_PRISON_MG_CONVERT_PICKUP) in plain text, as
// the other polled prompts.
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

    if ( mg_forge_carrying( player ) )
        return "Hold ^3[{+activate}]^7 to power the Machine";

    if ( !is_true( level.mg_forge_open ) )
        return undefined;

    if ( isdefined( player.mg_forge_missing_until ) && gettime() < player.mg_forge_missing_until )
        return "Missing Blundergat";

    return "Hold ^3[{+activate}]^7 to place the Blundergat";
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

    if ( mg_forge_carrying( player ) )
    {
        mg_forge_power( player );
        return;
    }

    if ( !is_true( level.mg_forge_open ) )
        return;

    weapon = mg_has_blundergat( player );

    // no gun to press: the remaster says so for 2 s
    if ( !isdefined( weapon ) )
    {
        player.mg_forge_missing_until = gettime() + 2000;
        return;
    }

    mg_forge_place( player, weapon );
}

// The carrier powers the Machine (the remaster's function_b09dee70): the power panel sound and the power effect on
// the machine, the run ends in success and the carrier gets his Blundergat back; 1 s later the Warden's line to him,
// and the forge is open to every player for good.
mg_forge_power( player )
{
    level endon( "mg_goto" );
    level.mg_forge_busy = 1;
    level.mg_press["press_body"] playsound( "zmb_powerpanel_activate" );
    mg_run_end_ok();
    mg_state_set( "done" );
    mg_fx_once( "sparks", level.mg_press_rest, undefined, level.mg_press["press_body"].angles );
    wait 1;

    if ( isdefined( player ) )
        player playsoundtoplayer( "mg_brutus_mgu", player );

    level.mg_forge_open = 1;
    level.mg_forge_busy = 0;
    mg_debug_print( "MG: the Machine is powered; the forge stays open for any Blundergat" );
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

    c = mg_coord( "MG_FORGE_GUN" );
    gun = spawn_weapon_model( weapon, undefined, c.origin, c.angles );
    level.mg_forge_gun_weapon = weapon;
    level.mg_forge_placer = player;
    level.mg_forge_place_ents = [];
    level.mg_forge_place_ents[0] = gun;

    // t 0.5: the start anim (the ram comes down 0.3 s in); t 0.55: the press sound at the machine
    wait 0.5;
    level thread mg_press_down();
    wait 0.05;
    level.mg_press["press_body"] playsound( "mg_press" );

    // t 1.35, the start anim over: the press fire once at the machine, the gun under the ram gone
    wait 0.8;
    mg_fx_once( "forge_rise", level.mg_press_rest, 6, level.mg_press["press_body"].angles );
    gun delete();

    // t 4.35: the Magmagat lies on the bed as the end anim lifts the ram; ready 0.8 + 0.5 s later
    wait 3;
    gun = spawn_weapon_model( mg_magma_of( weapon ), undefined, c.origin, c.angles );
    level.mg_forge_place_ents[0] = gun;
    level thread mg_press_up();
    wait 1.3;
    level.mg_forge_ready_gun = gun;
    level.mg_forge_place_ents = [];
    level.mg_forge_busy = 0;
    level thread mg_forge_pickup_window( gun );
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

// The placer takes the Magmagat (the Magmus Operandi when a Pack-a-Punched gun was pressed). One who already owns a
// Magmagat only gets its ammo refilled, as the remaster.
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
    owned = mg_has_magma( player );

    if ( isdefined( owned ) )
        player givemaxammo( owned );
    else
        player mg_weapon_grant( weapon );

    mg_forge_rest();
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
