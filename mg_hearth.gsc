#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_run;
#include scripts\zm\zm_prison\mg_weapon;

// The fireplace, as the BO3 remaster plays it (_zm_weap_magmagat.gsc, the soul hook in zm_prison_cerberus_quest.gsc):
// once the bridge's chair has been taken, a first press burns the boards; then a Blundergat laid in the fire locks the
// Warden's Office down until 15 souls have reached the skulls (a kill in it drops an essence, BO4's way: stepped on, it
// flies into its skull; the skulls light at 5 / 10 / 15). The placer going down fails it and the gun is lost; a
// success leaves it to the placer, with no time limit: he deposits the essence (the fire burns blue), then takes it,
// tempered.

mg_hearth_init()
{
    level.mg_souls = 0;
    level.mg_souls_taken = 0;
    level.mg_essences = 0;
    level.mg_souls_on = 0;
    level.mg_skulls = [];
    level.mg_skull_fx = [];
    level.mg_skull_gen = 0;
    level.mg_hearth_session = 0;
    level.mg_hearth_burnt = 0;
    level.mg_lock_gen = 0;
    level.mg_lock_fx = [];
    level.mg_lock_clips = [];

    for ( i = 1; i <= 3; i++ )
    {
        c = mg_coord( "MG_SKULL_" + i );
        skull = spawn( "script_model", c.origin );
        skull setmodel( mg_skull_model( 0 ) );
        skull.angles = c.angles;
        level.mg_skulls[i - 1] = skull;
    }

    // BO4's skull piles by the fireplace, only for show (dvar mg_bo4 "piles")
    if ( mg_bo4( "piles" ) )
    {
        for ( i = 1; i <= 2; i++ )
        {
            c = mg_coord( "MG_SKULL_PILE_" + i );
            pile = spawn( "script_model", c.origin );
            pile setmodel( c.model );
            pile.angles = c.angles;
        }
    }

    level thread mg_hearth_prompt_loop();
}

// The remaster's use trigger tr_magmagat_upgrade, as our polled prompt (mg_prompt, as the forge): within 96 units of
// MG_HEARTH_USE. Ready: no hint before the boards have burnt (the remaster's first press), then the place hint for
// everyone; pickup: the deposit hint, then the take hint, for the placer alone.
mg_hearth_prompt_loop()
{
    level endon( "end_game" );
    use = mg_coord( "MG_HEARTH_USE" ).origin;

    while ( true )
    {
        wait 0.1;

        foreach ( player in getplayers() )
        {
            text = undefined;

            if ( is_player_valid( player ) && distancesquared( player.origin, use ) < 96 * 96 )
                text = mg_hearth_prompt_text( player );

            if ( !isdefined( text ) )
            {
                if ( is_true( player.mg_hearth_prompted ) )
                {
                    player.mg_hearth_prompted = 0;
                    player mg_prompt( 0, undefined );
                }

                continue;
            }

            // the boards' press has no hint: nothing on screen, the press still counts
            if ( text == "" )
            {
                player.mg_hearth_prompted = 0;
                player mg_prompt( 0, undefined );
            }
            else
            {
                player.mg_hearth_prompted = 1;
                player mg_prompt( 1, text );
            }

            if ( player mg_press_use() )
                level thread mg_hearth_press( player );
        }
    }
}

// the hint for this player at the fireplace, "" for a press without one, undefined for none
mg_hearth_prompt_text( player )
{
    if ( mg_state_is( "ready" ) )
    {
        if ( !is_true( level.mg_hearth_burnt ) )
            return "";

        // the owner's rule: offered only with a Blundergat in hand (no hint otherwise)
        if ( !mg_is_blundergat( player getcurrentweapon() ) )
            return undefined;

        return "Hold ^3[{+activate}]^7 to place Blundergat";
    }

    if ( mg_state_is( "pickup" ) && isdefined( level.mg_hearth_owner ) && player == level.mg_hearth_owner )
    {
        if ( !is_true( level.mg_hearth_charged ) )
            return "Hold ^3[{+activate}]^7 to deposit the essence";

        return "Hold ^3[{+activate}]^7 to take the Tempered Blundergat";
    }

    return undefined;
}

// One press at a time, as the remaster's place loop: a press while another runs is ignored.
mg_hearth_press( player )
{
    if ( is_true( level.mg_hearth_busy ) )
        return;

    level.mg_hearth_busy = 1;

    if ( mg_state_is( "ready" ) && !is_true( level.mg_hearth_burnt ) )
        mg_hearth_burn();
    else if ( mg_state_is( "ready" ) )
        mg_hearth_place( player );
    else if ( mg_state_is( "pickup" ) && !is_true( level.mg_hearth_charged ) && !is_true( level.mg_hearth_depositing ) )
        level thread mg_hearth_deposit( player );    // its own thread: a goto ending it must not leave the fireplace busy
    else if ( mg_state_is( "pickup" ) )
        mg_hearth_take( player );

    level.mg_hearth_busy = 0;
}

// The first press after the gate (MG.gsc:110-114): a flame burst at the trigger and the boards burn; 1 s later the
// fireplace takes a gun. T6's boards are static map geometry and stay: the fire bursts over them for the 4 s the
// remaster's boards take to dissolve.
mg_hearth_burn()
{
    playsoundatposition( "mg_flame_burst", mg_coord( "MG_HEARTH_USE" ).origin );
    level thread mg_hearth_boards_burn();
    wait 1;
    level.mg_hearth_burnt = 1;
}

mg_hearth_boards_burn()
{
    // the remaster dissolves its planks (mg_wood_barrier); T6's boards are the map's own and stay. Over the map's own
    // fire, any fire doubled it: a short blue flare instead, the fire the deposit will light, its burst at the bed
    // (the flare draws 34 to 65 units over its origin)
    wait 0.05;
    mg_fx_once( "barrel_flare", ( -479, 8796, 1299 ), 4 );
}

// ready -> souls (MG.gsc:128-153): the gun in the player's hands (any of the four; the owner's rule, the prompt shows
// only then) leaves him and lies in the fire, and the lockdown starts.
mg_hearth_place( player )
{
    weapon = player getcurrentweapon();

    // the owner's rule: the Blundergat goes in from the hands, not from the back
    if ( !mg_is_blundergat( weapon ) )
        return;

    player takeweapon( weapon );
    primaries = player getweaponslistprimaries();

    // T6 does not always switch by itself when the weapon in hand is taken
    if ( primaries.size > 0 )
        player switchtoweapon( primaries[0] );

    level.mg_hearth_weapon = weapon;
    level.mg_hearth_owner = player;
    mg_hearth_gun_spawn( weapon );
    mg_state_set( "souls" );
    level thread mg_lockdown( player );
}

// The gun in the fire, at MG_HEARTH. With mg_bo4 "hover", BO4's: it floats there (mg_hover).
mg_hearth_gun_spawn( weapon )
{
    c = mg_coord( "MG_HEARTH" );
    level.mg_hearth_gun = spawn_weapon_model( weapon, undefined, c.origin, c.angles );

    if ( mg_bo4( "hover" ) )
        level.mg_hearth_gun thread mg_hover( c.origin );
}

// The lockdown (MG.gsc:431-454): the office shut for players, its fire outline, the laugh, the laundry's defend music;
// the souls counted until 15 or until the placer goes down. It ends 2 s after either; then the gun waits for its
// placer, or is lost.
mg_lockdown( placer )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level.mg_hearth_session++;
    mg_lockdown_on();
    mg_laugh_all();

    // as the vanilla dryer (zm_alcatraz_sq.gsc dryer_trigger_thread), the remaster's change_zombie_music on T6
    if ( !is_true( level.music_override ) )
    {
        level notify( "sndStopBrutusLoop" );
        level thread maps\mp\zombies\_zm_audio::sndmusicstingerevent( "laundry_defend" );
    }

    level.mg_souls = 0;
    level.mg_souls_taken = 0;
    level.mg_souls_on = 1;
    mg_death_listen_add( "mg_hearth", ::mg_hearth_zombie_died );
    level thread mg_lockdown_fail_watch( placer );
    level waittill( "mg_lockdown_end", won );
    level.mg_souls_on = 0;
    mg_death_listen_remove( "mg_hearth" );

    // a failed lockdown puts the skulls out at once (MG.gsc:507-511)
    if ( !won )
        mg_skulls_dark();

    wait 2;
    mg_lockdown_off();

    // the placer may have left in those 2 s: nobody could take the gun
    if ( won && isdefined( placer ) )
    {
        mg_state_set( "pickup" );
        level thread mg_hearth_owner_watch( placer, level.mg_hearth_session );
    }
    else
        mg_hearth_reset();
}

// pickup: the placer alone can take the gun, so his leaving the game loses it (the remaster would wait forever)
mg_hearth_owner_watch( placer, session )
{
    level endon( "end_game" );
    level endon( "mg_goto" );

    if ( isdefined( placer ) )
        placer waittill( "disconnect" );

    if ( mg_state_is( "pickup" ) && level.mg_hearth_session == session )
    {
        mg_debug_print( "MG: the placer left the game: the tempered Blundergat is lost" );
        mg_hearth_reset();
    }
}

// The only fail (MG.gsc:517-533): the placer in last stand or in afterlife, checked every 0.1 s. Another player going
// down does not matter. The placer leaving the game fails it too (the remaster would hang with no one to take the gun).
mg_lockdown_fail_watch( placer )
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_lockdown_end" );
    wait 0.05;    // mg_lockdown is waiting for the end before any fail is sent

    while ( true )
    {
        if ( !isdefined( placer ) )
        {
            mg_debug_print( "MG: the placer left the game: the lockdown fails, the Blundergat is lost" );
            break;
        }

        if ( placer maps\mp\zombies\_zm_laststand::player_is_in_laststand() || is_true( placer.afterlife ) || placer.sessionstate == "spectator" )
        {
            mg_debug_print( "MG: the placer went down: the lockdown fails, the Blundergat is lost" );
            break;
        }

        wait 0.1;
    }

    level notify( "mg_lockdown_end", 0 );
}

// The 15th soul (MG.gsc:492-500): 1 s later the laugh and the success.
mg_lockdown_won()
{
    level endon( "end_game" );
    level endon( "mg_goto" );
    level endon( "mg_lockdown_end" );
    wait 1;
    mg_laugh_all();
    mg_debug_print( "MG: 15 souls: the lockdown is over, the tempered Blundergat waits for its placer" );
    level notify( "mg_lockdown_end", 1 );
}

// The remaster laughs at world (0, 0, 0) for everyone; T6's alias carries 5000 units, so it goes to each player.
mg_laugh_all()
{
    foreach ( p in getplayers() )
        p playsoundtoplayer( "zmb_easteregg_laugh", p );
}

// A zombie killed by any player, with anything, whose body lies in the office, gives a soul (CQ.gsc:223-278). Brutus
// (animname brutus_zombie) and other archetypes never count. The killer may stand anywhere.
mg_hearth_zombie_died( zombie )
{
    // no more essences than souls still missing: each is a looping effect, a sound and a thread
    if ( !is_true( level.mg_souls_on ) || level.mg_souls_taken + level.mg_essences >= 15 )
        return;

    if ( !isdefined( zombie ) || !isdefined( zombie.animname ) || zombie.animname != "zombie" )
        return;

    if ( !isdefined( zombie.attacker ) || !isplayer( zombie.attacker ) )
    {
        mg_debug_print( "MG: kill not counted: no player attacker" );
        return;
    }

    if ( !mg_ent_in_office( zombie ) )
    {
        mg_debug_print( "MG: kill not counted: the zombie died outside the office" );
        return;
    }

    level thread mg_soul( zombie.origin, level.mg_hearth_session );
}

// A soul as BO4 drops it (the owner's call over the remaster, whose souls count by themselves): the kill leaves an
// essence, the remaster's blue skull flame, that rises off the body over 2 s and hums in place; a player stepping on it
// sends it fast into the skull it fills, and it counts on arrival. An essence nobody takes fades after 20 s. Its skull lights at 5, 10, 15.
mg_soul( pos, session )
{
    level endon( "end_game" );
    playsoundatposition( "mg_soul_kill", pos );
    level.mg_essences++;
    essence = mg_fx_loop( "soul_full", pos + ( 0, 0, 4 ) );

    if ( !isdefined( essence ) )
    {
        level.mg_essences--;
        return;
    }

    essence playloopsound( "mg_soul_loop" );
    essence moveto( essence.origin + ( 0, 0, 36 ), 2, 0, 1.2 );
    level thread mg_fx_keepalive( essence );
    taker = essence mg_essence_wait( session );
    level.mg_essences--;

    if ( !isdefined( taker ) )
    {
        essence stoploopsound();
        mg_fx_stop( essence );
        return;
    }

    // the skull this soul fills, reserved as it is taken (5 a skull)
    level.mg_souls_taken++;
    idx = int( ( level.mg_souls_taken - 1 ) / 5 );
    playsoundatposition( "evt_soulsuck_body", essence.origin );
    playsoundatposition( "evt_wolfhead_body_count", essence.origin );    // the wolf heads' soul taken, where it lay
    essence mg_essence_fly( level.mg_skulls[idx].origin );
    essence stoploopsound();
    mg_fx_stop( essence );

    if ( !is_true( level.mg_souls_on ) || level.mg_hearth_session != session || level.mg_souls >= 15 )
        return;

    level.mg_souls++;
    n = level.mg_souls;
    mg_debug_print( "MG: soul " + n + "/15" );

    if ( n % 5 == 0 )
        level thread mg_skull_light( int( n / 5 ) - 1 );

    if ( n >= 15 )
        level thread mg_lockdown_won();
}

// self = an essence. The player who steps on it (within 40 units, feet near it), or undefined when nobody does within
// 20 s, when the lockdown ends first or when every soul is already on its way.
mg_essence_wait( session )
{
    level endon( "end_game" );
    expiry = gettime() + 20000;

    while ( is_true( level.mg_souls_on ) && level.mg_hearth_session == session && level.mg_souls_taken < 15 && gettime() < expiry )
    {
        foreach ( player in getplayers() )
        {
            if ( !is_player_valid( player ) || distance2dsquared( player.origin, self.origin ) > 40 * 40 )
                continue;

            if ( abs( player.origin[2] - self.origin[2] ) < 72 )
                return player;
        }

        wait 0.05;
    }

    return undefined;
}

// self = an essence taken: a hop, then a fast streak into the skull (0.5 s).
mg_essence_fly( skull )
{
    self notify( "mg_moving" );
    up = self.origin + ( 0, 0, 24 );
    self moveto( up, 0.2, 0, 0.1 );
    wait 0.2;
    self moveto( skull, 0.5, 0.2, 0 );
    wait 0.5;
}

// The mantle skull's model: the remaster's (its skull keeps one model, lit or not), or with mg_bo4 "skulls" BO4's,
// a plain skull that becomes the Afterlife skull once lit.
mg_skull_model( lit )
{
    if ( !mg_bo4( "skulls" ) )
        return mg_model( "skull" );

    if ( lit )
        return mg_model( "skull_bo4_lit" );

    return mg_model( "skull_bo4" );
}

// Skull index 0..2 lights: the remaster's blue flame skull on it (MG.gsc:473-494, MG.csc:86-99); nothing sounds. The
// remaster's skull model does not change, BO4's turns into its Afterlife skull. It stays lit until a failed lockdown or
// a failed run.
mg_skull_light( idx )
{
    skull = level.mg_skulls[idx];

    if ( !isdefined( skull ) )
        return;

    skull setmodel( mg_skull_model( 1 ) );
    mg_fx_stop( level.mg_skull_fx[idx] );
    gen = level.mg_skull_gen;
    ent = mg_fx_loop( "soul_full", skull.origin - ( 0, 0, 3.5 ) ); // at the skull's foot, as the remaster's skull fire

    // the skulls were put out while the flame spawned
    if ( gen != level.mg_skull_gen )
    {
        mg_fx_stop( ent );
        return;
    }

    level.mg_skull_fx[idx] = ent;

    if ( isdefined( ent ) )
        level thread mg_fx_keepalive( ent );
}

// All three skulls out: on a failed lockdown here, and on a failed run from mg_run (MG.gsc:507-511, lockdown_failed /
// tempered_step_failed). After a forged gun they stay lit for the rest of the game.
mg_skulls_dark()
{
    level.mg_skull_gen++;

    foreach ( ent in level.mg_skull_fx )
        mg_fx_stop( ent );

    level.mg_skull_fx = [];

    foreach ( skull in level.mg_skulls )
    {
        if ( isdefined( skull ) )
            skull setmodel( mg_skull_model( 0 ) );
    }
}

// The owner's deposit (over the remaster, which hands the gun at once): the placer pours the essence into the fire,
// three souls streaking from him into the gun, then the fireplace bursts into the remaster's blue flame and
// burns blue until the tempered Blundergat is taken, as BO4's turns blue; the skulls, their souls given, go out. The
// map's own fire there is a client effect no server script can put out, so the blue one burns over it, on its spot.
mg_hearth_deposit( player )
{
    level endon( "mg_goto" );

    if ( !mg_state_is( "pickup" ) || !isdefined( level.mg_hearth_owner ) || player != level.mg_hearth_owner )
        return;

    session = level.mg_hearth_session;
    hearth = mg_coord( "MG_HEARTH" ).origin;
    level.mg_hearth_depositing = 1;
    from = player geteye() - ( 0, 0, 12 );

    // the three skulls' souls leave the placer for the gun in the fire, one after the other
    for ( i = 0; i < 3; i++ )
    {
        if ( isdefined( player ) )
            from = player geteye() - ( 0, 0, 12 );

        level thread mg_hearth_soul_in( from, hearth - ( 0, 0, 20 ) );
        wait 0.15;
    }

    wait 0.3;
    // over the map's fire (createfx fx_alcatraz_fire_sm at -466.08 8807.48 1333.03): the remaster's blue flame draws
    // 30 to 35 units over its origin
    playsoundatposition( "mg_flame_burst", hearth );
    mg_fx_once( "hearth_flare", hearth - ( 0, 0, 20 ) );
    blue = mg_fx_loop( "hearth_blue", ( -459, 8817.2, 1303 ) );    // 12 deeper into the fireplace than the map's fire
    level.mg_hearth_depositing = 0;

    // a reset (the placer gone, a goto) during those waits: the fire stays as it was
    if ( !mg_state_is( "pickup" ) || level.mg_hearth_session != session )
    {
        mg_fx_stop( blue );
        return;
    }

    level.mg_hearth_blue = blue;
    level.mg_hearth_charged = 1;
    mg_skulls_dark();
    level thread mg_fx_keepalive( blue );
}

// a soul leaving its skull for the fire
mg_hearth_soul_in( from, to )
{
    soul = mg_fx_loop( "soul_full", from );

    if ( !isdefined( soul ) )
        return;

    soul moveto( to, 0.45, 0.15, 0 );
    wait 0.45;
    mg_fx_stop( soul );
}

// The blue fire out (taken, or the step reset).
mg_hearth_blue_off()
{
    level.mg_hearth_depositing = 0;
    level.mg_hearth_busy = 0;
    mg_fx_stop( level.mg_hearth_blue );
    level.mg_hearth_blue = undefined;
    level.mg_hearth_charged = 0;
}

// pickup -> run (MG.gsc:735-766): only the placer, and not while drinking or holding a mine, equipment, the revive
// tool or nothing (the press is ignored). He gets our tempered gun (T6 cannot draw the remaster's view-model flame);
// the run gives the placed variant back when it ends.
mg_hearth_take( player )
{
    if ( !mg_state_is( "pickup" ) || !isdefined( level.mg_hearth_owner ) || player != level.mg_hearth_owner )
        return;

    if ( !is_player_valid( player ) || is_true( player.is_drinking ) || !mg_can_replace_current( player ) )
        return;

    weapon = level.mg_hearth_weapon;

    if ( !isdefined( weapon ) )
        weapon = "blundergat_zm";

    tempered = mg_tempered_of( weapon );
    player mg_give_weapon( tempered );    // the vanilla rule (wait_for_player_to_take): a full hand gives up the gun in it
    player.mg_tempered_from = weapon;

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun delete();

    level.mg_hearth_gun = undefined;
    level.mg_hearth_weapon = undefined;
    level.mg_hearth_owner = undefined;
    mg_hearth_blue_off();
    mg_run_start( player, tempered );
}

// The remaster's lockdown: one effect outlining the office's door and walls, where its exploder fx_mg_quest_lockdown
// stands (BO3 -4432 3971 2720, no rotation), brought onto BO2's office by the fit of the two maps' office windows
// (BO2 = BO3 x 1.015 / 1.019 + 3605 / 4976, the remaster's office being a little smaller; tools/assets/bo3_fx.tsv
// stretches the effect the same way); and its wardens_playerclip across the office door. The dvars mg_lock_offset
// ("x y z") and mg_lock_yaw move and turn it in game, to fit it on the door and windows.
mg_lockdown_on()
{
    mg_lockdown_off();
    origin = ( -961.4, 9027.4, 1373 );    // the fit, then 10 west and 5 up onto BO2's office door (the owner's check in game)
    origin = origin + mg_dvar_vec( "mg_lock_offset", ( 0, 0, 0 ) );

    level thread mg_lockdown_wall( origin, ( 0, getdvarfloat( "mg_lock_yaw" ), 0 ) );
    mg_lockdown_clip_on();
}

// a wall still spawning when the lockdown ends goes at once
mg_lockdown_wall( origin, angles )
{
    gen = level.mg_lock_gen;
    wall = mg_fx_loop( "lockdown", origin, angles );

    if ( gen != level.mg_lock_gen )
        mg_fx_stop( wall );
    else if ( isdefined( wall ) )
    {
        level.mg_lock_fx[level.mg_lock_fx.size] = wall;
        level thread mg_fx_keepalive( wall );
    }
}

// T6's office has no wardens_playerclip: four player-only collision pillars (32 x 32 x 128, centred) stand where the
// remaster's clip closes the zone, the inner doorway its blue wall frames (BO3 x -4469 to -4363 at y 4124: BO2 x -991
// to -884 at y 9183). Players can neither leave nor come in; zombies walk through.
mg_lockdown_clip_on()
{
    foreach ( dx in array( -48, -16, 16, 48 ) )
    {
        clip = spawn( "script_model", ( -938 + dx, 9183, 1400 ) );
        clip setmodel( mg_model( "player_clip" ) );
        clip ghost();
        level.mg_lock_clips[level.mg_lock_clips.size] = clip;
    }
}

mg_lockdown_off()
{
    foreach ( wall in level.mg_lock_fx )
        mg_fx_stop( wall );

    foreach ( clip in level.mg_lock_clips )
    {
        if ( isdefined( clip ) )
            clip delete();
    }

    level.mg_lock_fx = [];
    level.mg_lock_clips = [];
    level.mg_lock_gen++;
}

// A failed lockdown (or a placer gone before the pickup): the gun is lost (it was taken from the placer), the skulls
// are out, the fireplace takes a gun again.
mg_hearth_reset()
{
    mg_death_listen_remove( "mg_hearth" );
    level.mg_souls_on = 0;
    level.mg_souls = 0;
    level.mg_souls_taken = 0;

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun delete();

    level.mg_hearth_gun = undefined;
    mg_skulls_dark();
    mg_hearth_blue_off();
    level.mg_hearth_weapon = undefined;
    level.mg_hearth_owner = undefined;

    if ( mg_state_is( "souls" ) || mg_state_is( "pickup" ) )
        mg_state_set( "ready" );
}

// !mg goto support (self = the player typing): builds what the asked state expects from the hearth. The typing player
// is the placer; from souls on the boards have burnt, from pickup on the three skulls are lit.
mg_hearth_fabricate( state )
{
    placer = self;

    if ( !isdefined( placer ) || !isplayer( placer ) )
        placer = getplayers()[0];

    level.mg_hearth_session++;
    mg_death_listen_remove( "mg_hearth" );
    mg_lockdown_off();
    level.mg_souls_on = 0;
    level.mg_souls = 0;
    level.mg_souls_taken = 0;

    if ( isdefined( level.mg_hearth_gun ) )
        level.mg_hearth_gun delete();

    level.mg_hearth_gun = undefined;
    level.mg_hearth_weapon = undefined;
    level.mg_hearth_owner = undefined;
    mg_skulls_dark();
    mg_hearth_blue_off();
    level.mg_hearth_burnt = 1;

    if ( state == "locked" )
        level.mg_hearth_burnt = 0;

    if ( state == "souls" || state == "pickup" )
    {
        level.mg_hearth_weapon = "blundergat_zm";
        level.mg_hearth_owner = placer;
        mg_hearth_gun_spawn( "blundergat_zm" );
    }

    if ( state == "souls" )
        level thread mg_lockdown_delayed( placer );

    if ( state == "pickup" )
        level thread mg_hearth_owner_watch( placer, level.mg_hearth_session );

    if ( state == "pickup" || state == "run" || state == "forge" || state == "done" )
    {
        level.mg_souls = 15;
        level.mg_souls_taken = 15;

        for ( i = 0; i < 3; i++ )
            level thread mg_skull_light( i );
    }
}

// the state is set right after fabrication; the lockdown must start after that
mg_lockdown_delayed( placer )
{
    level endon( "mg_goto" );
    wait 0.1;
    level thread mg_lockdown( placer );
}
