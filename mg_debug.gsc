#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_hearth;
#include scripts\zm\zm_prison\mg_forge;
#include scripts\zm\zm_prison\mg_weapon;
#include scripts\zm\zm_prison\mg_place;

// Debug tools (`!mg`, needs `set mg_debug 1`): give / magma / shock, the tour, the lockdown and zone checks, and the fx
// / snd audition (`!mg fx <n|name|next|prev|stop>`, `!mg snd <n|alias|next|prev>`, ported from the Dead Frequency
// mod's audition tool without its grid).

// self = player
mg_debug_lockdown()
{
    self mg_out( "MG: lockdown on for 10 s (the office door and walls outlined)" );
    mg_lockdown_on();
    wait 10;

    if ( !mg_state_is( "souls" ) )
        mg_lockdown_off();
}

// self = player. Glints every 48 units along the kill zone's sides (mg_in_office_box), at z 1376, for 15 s.
mg_debug_zone()
{
    self mg_out( "MG: the kill zone marked for 15 s (x -1070 to -440, y 8493 to 9187)" );
    corners = array( ( -1070, 8493, 1376 ), ( -440, 8493, 1376 ), ( -440, 9187, 1376 ), ( -1070, 9187, 1376 ) );
    marks = [];

    for ( i = 0; i < 4; i++ )
    {
        a = corners[i];
        b = corners[( i + 1 ) % 4];
        steps = int( distance( a, b ) / 48 );

        for ( k = 0; k < steps; k++ )
        {
            mark = mg_fx_loop( "glint", a + ( b - a ) * ( k / steps ) );

            if ( isdefined( mark ) )
                marks[marks.size] = mark;
        }
    }

    wait 15;

    foreach ( mark in marks )
        mg_fx_stop( mark );
}

mg_debug_init()
{
    level.mg_shock = 0;
    level.mg_shock_weapon = "m1911_zm";
}

// self = player. 1 when the command was ours.
mg_debug_command( sub, arg, args )
{
    switch ( sub )
    {
        // the bridge requirement met, as when the plane lands on the bridge (the gate's own event, no vanilla flag)
        case "bridge":
            if ( !mg_state_is( "locked" ) )
            {
                self mg_out( "MG: the fireplace is already open (state " + level.mg_state + ")" );
                return 1;
            }

            level notify( "mg_bridge_reached" );
            self mg_out( "MG: bridge reached: the fireplace takes a Blundergat" );
            return 1;

        // every step's effects and sounds in their real place, one after the other (the review of the quest's look)
        case "tour":
            if ( is_true( self.mg_touring ) )
            {
                self mg_out( "MG: a tour is already running" );
                return 1;
            }

            self thread mg_debug_tour();
            return 1;

        // the office lockdown for 10 s, outside the quest
        case "lockdown":
            self thread mg_debug_lockdown();
            return 1;

        // the souls' kill zone marked along its sides, to check it against the lockdown's blue walls
        case "zone":
            self thread mg_debug_zone();
            return 1;

        case "give":
            self mg_give_weapon( "blundergat_zm" );
            self mg_out( "MG: Blundergat given" );
            return 1;

        case "magma":
            weapon = mg_has_blundergat( self );

            if ( !isdefined( weapon ) )
            {
                self mg_out( "MG: hold a Blundergat first (!mg give)" );
                return 1;
            }

            self mg_weapon_grant( weapon );
            return 1;

        case "shock":
            // "!mg shock gun" toggles the pistol zap; plain "!mg shock" zaps EVERY Afterlife shock box and panel of the
            // map at once (owner 2026-09-20: the ones behind walls cannot be aimed at, even with noclip)
            if ( isdefined( arg ) && tolower( arg ) == "gun" )
            {
                level.mg_shock = !is_true( level.mg_shock );

                if ( level.mg_shock )
                {
                    foreach ( player in getplayers() )
                        player thread mg_shock_loop();
                }

                word = "OFF";

                if ( level.mg_shock )
                    word = "ON";

                self mg_out( "MG: shock pistol " + word + " (" + level.mg_shock_weapon + " zaps Afterlife shock boxes and panels)" );
                return 1;
            }

            n = 0;

            foreach ( ent in getentarray( "afterlife_interact", "targetname" ) )
            {
                ent notify( "damage", 1, level );
                mg_fx_once( "blue_spark", ent.origin );
                n++;
            }

            self mg_out( "MG: zap sent to " + n + " Afterlife shock boxes and panels (!mg shock gun for the pistol mode)" );
            return 1;

        case "fx":
            self mg_aud_fx( arg );
            return 1;

        case "snd":
            self mg_aud_snd( arg );
            return 1;

        case "grab":
            if ( !isdefined( arg ) )
            {
                self mg_out( "Usage: !mg grab <KEY>   e.g. !mg grab MG_HEARTH   (!mg spots lists keys)" );
                return 1;
            }

            self mg_place_grab( arg );
            return 1;

        case "drop":
            self mg_place_drop();
            return 1;

        case "cancel":
            self mg_place_cancel();
            return 1;

        case "rot":
            if ( !isdefined( arg ) )
            {
                self mg_out( "Usage: !mg rot <deg>   e.g. !mg rot 15" );
                return 1;
            }

            self mg_place_rot( int( arg ) );
            return 1;

        case "up":
            if ( !isdefined( arg ) )
            {
                self mg_out( "Usage: !mg up <units>   e.g. !mg up 4" );
                return 1;
            }

            self mg_place_up( int( arg ) );
            return 1;

        case "show":
            if ( isdefined( arg ) && !isdefined( mg_coord( arg ) ) )
            {
                self mg_out( "MG: unknown key " + arg + " (!mg spots lists them)" );
                return 1;
            }

            mg_preview_show( arg );
            self mg_out( "MG: preview spawned (!mg hide to remove, !mg tp <KEY> to visit)" );
            return 1;

        case "hide":
            mg_preview_hide();
            self mg_out( "MG: preview removed" );
            return 1;

        // owner 2026-09-28: spawn any precached model 80 in front (the mod.ff props)
        case "model":
            if ( !isdefined( arg ) )
            {
                self mg_out( "Usage: !mg model <xmodel>   e.g. !mg model mg_barrel_green" );
                return 1;
            }

            self mg_debug_spawn_model( arg );
            return 1;

        case "tp":
            if ( !isdefined( arg ) )
            {
                self mg_out( "Usage: !mg tp <KEY>   e.g. !mg tp MG_HEARTH   (!mg spots lists keys)" );
                return 1;
            }

            if ( !self mg_preview_teleport( arg ) )
                self mg_out( "MG: unknown key " + arg );

            return 1;
    }

    return 0;
}

// self = player. `!mg tour`: teleports to each anchor and plays what the quest plays there, labelled on screen.
mg_debug_tour()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    self.mg_touring = 1;
    back = self.origin;
    back_angles = self getplayerangles();
    hearth = mg_coord( "MG_HEARTH" ).origin;
    use = mg_coord( "MG_HEARTH_USE" ).origin;
    skull = mg_coord( "MG_SKULL_1" ).origin;

    // 1. the first press at the fireplace: the boards burn
    self mg_tour_look( "1/7 The fireplace's first press: a flame burst, the boards burn", use, hearth );
    self playsoundtoplayer( "mg_flame_burst", self );
    level thread mg_hearth_boards_burn();
    wait 4;

    // 2. the Blundergat placed: the lockdown (not while a real one runs)
    self mg_tour_look( "2/7 The Blundergat placed: the laugh, the office outlined and shut", use, hearth );
    gun = spawn_weapon_model( "blundergat_zm", undefined, hearth, mg_coord( "MG_HEARTH" ).angles );
    self playsoundtoplayer( "zmb_easteregg_laugh", self );
    lockdown = !mg_state_is( "souls" );

    if ( lockdown )
        mg_lockdown_on();

    wait 4;

    if ( lockdown && !mg_state_is( "souls" ) )
        mg_lockdown_off();

    // 3. a soul: the lightning streak rising over the body
    spot = use + anglestoforward( ( 0, vectortoangles( use - hearth )[1], 0 ) ) * 90;
    self mg_tour_look( "3/7 A soul: the essence a kill drops; stepped on, it streaks into its skull", use + ( 0, 0, 10 ), spot );
    self playsoundtoplayer( "mg_soul_kill", self );
    essence = mg_fx_loop( "soul_trail", spot + ( 0, 0, 14 ) );

    if ( isdefined( essence ) )
    {
        essence playloopsound( "mg_soul_loop" );
        wait 1.5;
        self playsoundtoplayer( "evt_soulsuck_body", self );
        essence mg_essence_fly( skull );
        essence stoploopsound();
        mg_fx_stop( essence );
    }

    wait 0.5;

    // 4. a skull lit (every 5 souls)
    self mg_tour_look( "4/7 A skull lit (5 souls): its blue flame", use, skull );
    glow = mg_fx_loop( "soul_full", skull - ( 0, 0, 3.5 ) );
    wait 4;
    mg_fx_stop( glow );

    if ( isdefined( gun ) )
        gun delete();

    // 5. the run: a lit drum, then its flare as it refills the temper
    b = mg_coord( "MG_BARREL_1" ).origin;
    self mg_tour_look( "5/7 The run: a drum burning, its flare when it refills the temper", b + ( 90, 90, 40 ), b + ( 0, 0, 20 ) );
    fire = mg_fx_loop( "barrel_fire", b - ( 0, 0, 34.37 ) );
    wait 1.5;
    mg_fx_once( "barrel_flare", b - ( 0, 0, 34.37 ), 5 );
    self playsoundtoplayer( "mg_flame_burst", self );
    wait 4;
    mg_fx_stop( fire );

    // 6. the forge: powered, then a gun pressed into the Magmagat (the ram stays up while a real press runs)
    fc = mg_coord( "MG_FORGE_GUN" );
    angles = level.mg_press["press_body"].angles;
    self mg_tour_look( "6/7 The forge: the Machine powered, a Blundergat pressed", mg_coord( "MG_FORGE" ).origin + ( 0, 0, 10 ), fc.origin );
    mg_fx_once( "sparks", level.mg_press_rest, undefined, angles );
    self playsoundtoplayer( "zmb_powerpanel_activate", self );
    wait 1;
    self playsoundtoplayer( "mg_brutus_mgu", self );
    wait 2;
    press = !is_true( level.mg_forge_busy ) && !isdefined( level.mg_forge_ready_gun );
    gun = spawn_weapon_model( "blundergat_zm", undefined, fc.origin, fc.angles );
    wait 0.5;

    if ( press )
        level thread mg_press_down();

    wait 0.05;
    self playsoundtoplayer( "mg_press", self );
    wait 0.8;
    mg_fx_once( "forge_rise", level.mg_press_rest, 6, angles );
    gun delete();
    wait 3;
    gun = spawn_weapon_model( "magmagat_zm", undefined, fc.origin, fc.angles );

    if ( press )
        level thread mg_press_up();

    wait 3;
    gun delete();

    // 7. the Magmagat's shot, fired for real at the floor ahead: the blob flies and lays its pool
    self setorigin( back );
    self setplayerangles( back_angles );
    wait 0.2;
    fwd = anglestoforward( ( 0, back_angles[1], 0 ) );
    trace = bullettrace( back + fwd * 300 + ( 0, 0, 40 ), back + fwd * 300 - ( 0, 0, 200 ), 0, undefined );
    pos = trace["position"];
    self mg_tour_look( "7/7 The Magmagat's shot: the blob flies, a miss lays its pool (6 s), a zombie hit bursts", back, pos );
    start = self geteye() + fwd * 30;
    bolt = magicbullet( "mg_magma_bolt_zm", start, pos, self );

    if ( isdefined( bolt ) )
        level thread mg_blob_land( bolt, self, "magmagat_zm", start );

    wait 7;
    mg_fx_once( "explo", pos + ( 0, 0, 20 ) );
    self playsoundtoplayer( "wpn_blundersplat_explode", self );
    wait 1;

    self mg_out( "MG: tour done. Name a step (1-7) and what to change; any effect can be tried in place with `set mg_fx_<key> <fx>`" );
    self.mg_touring = 0;
}

// self = player. Stands at `from` looking at `at`, and says what comes.
mg_tour_look( label, from, at )
{
    self setorigin( from );
    self setplayerangles( vectortoangles( at - ( from + ( 0, 0, 60 ) ) ) );
    self iprintlnbold( label );
    self mg_out( "MG: " + label );
    wait 1;
}

// self = player. One script_model of `name` 80 in front, on the ground, facing the player; the previous one goes.
mg_debug_spawn_model( name )
{
    // a model nobody precached ends the map for everyone: only the mod's own (mg_coords) are offered
    if ( !isinarray( level.mg_models, name ) )
    {
        self mg_out( "MG: unknown model " + name + " (one of mg_coords' models)" );
        return;
    }

    if ( isdefined( level.mg_debug_model ) )
        level.mg_debug_model delete();

    fwd = anglestoforward( ( 0, self.angles[1], 0 ) );
    pos = self.origin + fwd * 80;
    trace = bullettrace( pos + ( 0, 0, 60 ), pos - ( 0, 0, 300 ), 0, self );

    if ( isdefined( trace["position"] ) )
        pos = trace["position"];

    level.mg_debug_model = spawn( "script_model", pos );
    level.mg_debug_model setmodel( name );
    level.mg_debug_model.angles = ( 0, self.angles[1] + 180, 0 );
    self mg_out( "MG: model " + name + " at " + int( pos[0] ) + " " + int( pos[1] ) + " " + int( pos[2] ) );
}

// self = player. Every shot of the shock weapon traces from the eye; the nearest afterlife_interact entity
// within 64 units of the hit (or hit directly) gets the vanilla zap event (attacker = level, as vanilla allows).
mg_shock_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( is_true( self.mg_shock_looping ) )
        return;

    self.mg_shock_looping = 1;

    while ( is_true( level.mg_shock ) )
    {
        self waittill( "weapon_fired", weapon );

        if ( !isdefined( weapon ) || weapon != level.mg_shock_weapon )
            continue;

        eye = self geteye();
        fwd = anglestoforward( self getplayerangles() );
        trace = bullettrace( eye, eye + fwd * 4000, 0, self );
        best = undefined;
        bestd = 64 * 64;

        foreach ( ent in getentarray( "afterlife_interact", "targetname" ) )
        {
            if ( isdefined( trace["entity"] ) && trace["entity"] == ent )
            {
                best = ent;
                break;
            }

            d = distancesquared( ent.origin, trace["position"] );

            if ( d < bestd )
            {
                bestd = d;
                best = ent;
            }
        }

        if ( !isdefined( best ) )
            continue;

        best notify( "damage", 1, level );
        mg_fx_once( "blue_spark", best.origin );
        self mg_out( "MG: zap sent to " + best.model + " at " + mg_vec_str( best.origin ) );
    }

    self.mg_shock_looping = 0;
}

// ---------------------------------------------------------------------------------------------- fx ----
// Every fx key registered by this mod (mg_fx_table(), already loaded by mg_fx_init in init()).
mg_aud_fx_list()
{
    l = [];

    foreach ( key, path in mg_fx_table() )
        l[l.size] = key; // bare key: mg_fx_loop / mg_fx_once add the "mg_" prefix themselves

    // then every effect the MAP registered (zm_prison_fx.gsc and friends, tools/assets/fx_registered_zm_prison.txt):
    // playable as is, no precache needed
    if ( isdefined( level._effect ) )
    {
        foreach ( key in getarraykeys( level._effect ) )
        {
            if ( key.size < 3 || getsubstr( key, 0, 3 ) != "mg_" )
                l[l.size] = key;
        }
    }

    return l;
}

// ------------------------------------------------------------------------------------------- sounds ----
// Prison / Afterlife aliases (tools/assets/soundbank/zmb_alcatraz.all.aliases.csv).
mg_aud_snd_list()
{
    l = [];
    l[l.size] = "zmb_afterlife_shockbox_on";
    l[l.size] = "zmb_afterlife_shockbox_off";
    l[l.size] = "zmb_afterlife_panel_on";
    l[l.size] = "zmb_afterlife_trigger_activate";
    l[l.size] = "zmb_afterlife_object_apparate";
    l[l.size] = "zmb_afterlife_object_disapparate";
    l[l.size] = "zmb_afterlife_zombie_warp_in";
    l[l.size] = "zmb_afterlife_zombie_warp_out";
    l[l.size] = "zmb_powerpanel_activate";
    l[l.size] = "zmb_quest_generator_panel_power";
    l[l.size] = "zmb_quest_generator_loop1";
    l[l.size] = "zmb_quest_forcefield_start";
    l[l.size] = "zmb_quest_forcefield_end";
    l[l.size] = "zmb_quest_electricchair_activate";
    l[l.size] = "zmb_hellbox_open";
    l[l.size] = "zmb_hellbox_jingle";
    l[l.size] = "zmb_hellbox_rise";
    l[l.size] = "zmb_perks_packa_ready";
    l[l.size] = "zmb_cha_ching";
    l[l.size] = "zmb_cha_ching_loud";
    l[l.size] = "zmb_no_cha_ching";
    l[l.size] = "zmb_powerup_grabbed";
    l[l.size] = "zmb_powerup_grabbed_3p";
    l[l.size] = "zmb_buildable_complete";
    l[l.size] = "zmb_fire_loop";
    l[l.size] = "amb_fire_med";
    l[l.size] = "amb_ember_burn";
    l[l.size] = "evt_wolfhead_eat";
    l[l.size] = "evt_wolfhead_fire_loop";
    l[l.size] = "evt_wolfhead_spawn_howl";
    l[l.size] = "evt_soulsuck_body";
    l[l.size] = "wpn_blundersplat_explode";
    l[l.size] = "wpn_blundersplat_fuse";
    l[l.size] = "wpn_blundergat_fire_plr";
    return l;
}

// --------------------------------------------------------------------------------------- commands ----
// self = the player who typed. Resolves n / next / prev / a name against `list`; undefined = print the list.
mg_aud_resolve( arg, list, last )
{
    if ( arg == "next" )
    {
        if ( !isdefined( last ) )
            return 0;

        return ( last + 1 ) % list.size;
    }

    if ( arg == "prev" )
    {
        if ( !isdefined( last ) )
            return list.size - 1;

        return ( last + list.size - 1 ) % list.size;
    }

    if ( mg_aud_is_number( arg ) )
    {
        n = int( arg );

        if ( n < 0 || n >= list.size )
            return undefined;

        return n;
    }

    for ( i = 0; i < list.size; i++ )
    {
        if ( list[i] == arg )
            return i;
    }

    return undefined;
}

mg_aud_is_number( s )
{
    if ( !isdefined( s ) || s.size == 0 )
        return 0;

    for ( i = 0; i < s.size; i++ )
    {
        c = s[i];

        if ( c != "0" && c != "1" && c != "2" && c != "3" && c != "4" && c != "5" && c != "6" && c != "7" && c != "8" && c != "9" )
            return 0;
    }

    return 1;
}

// Prints the list a few names a line (the console wraps long lines).
mg_aud_print_list( list, label )
{
    self mg_out( label + ": " + list.size + " entries (number = the n of !mg " + label + " <n>)" );
    line = "";

    for ( i = 0; i < list.size; i++ )
    {
        line = line + i + " " + list[i] + "   ";

        if ( ( i % 6 ) == 5 || i == list.size - 1 )
        {
            self mg_out( line );
            line = "";
            wait 0.05;
        }
    }
}

// !mg fx ...  (self = player)
mg_aud_fx( arg )
{
    list = mg_aud_fx_list();

    if ( !isdefined( arg ) || arg == "list" )
    {
        self thread mg_aud_print_list( list, "fx" );
        return;
    }

    mg_aud_fx_stop();

    if ( arg == "stop" )
    {
        self mg_out( "fx audition stopped" );
        return;
    }

    idx = mg_aud_resolve( arg, list, level.mg_aud_fx_idx );

    if ( !isdefined( idx ) )
    {
        // any registered key, even outside the curated list
        if ( isdefined( level._effect["mg_" + arg] ) )
        {
            mg_aud_fx_show( arg, -1 );
            return;
        }

        self mg_out( "fx: unknown '" + arg + "' (not in the list, not a registered fx). !mg fx list | stop" );
        return;
    }

    level.mg_aud_fx_idx = idx;
    mg_aud_fx_show( list[idx], idx );
}

// The fx at the point you aim at (ground hit within 300, else 150 ahead), for 8 s or until the next one.
mg_aud_fx_show( name, idx )
{
    full = "mg_" + name;

    if ( !isdefined( level._effect[full] ) && isdefined( level._effect[name] ) )
        full = name; // a key the map registered itself

    if ( !isdefined( level._effect[full] ) )
    {
        self mg_out( "[FX " + idx + "] " + name + ": no such fx registered, nothing to play" );
        return;
    }

    eye = self geteye();
    fwd = anglestoforward( self getplayerangles() );
    trace = bullettrace( eye, eye + fwd * 300, 0, self );
    pos = eye + fwd * 150;

    if ( isdefined( trace["fraction"] ) && trace["fraction"] < 1 )
        pos = trace["position"] + trace["normal"] * 4;

    level.mg_aud_fx_ent = spawn( "script_model", pos );
    level.mg_aud_fx_ent setmodel( "tag_origin" );
    playfxontag( level._effect[full], level.mg_aud_fx_ent, "tag_origin" );
    level thread mg_aud_fx_auto_stop( level.mg_aud_fx_ent, 8 );
    tag = "[FX " + idx + "/" + mg_aud_fx_list().size + "] ";

    if ( idx < 0 )
        tag = "[FX] ";

    self mg_out( tag + name + "  at " + mg_vec_str( pos ) + "  (8 s; !mg fx next | prev | <n> | <name> | list | stop)" );
}

mg_aud_fx_stop()
{
    if ( isdefined( level.mg_aud_fx_ent ) )
        mg_fx_stop( level.mg_aud_fx_ent );

    level.mg_aud_fx_ent = undefined;
}

mg_aud_fx_auto_stop( ent, seconds )
{
    level endon( "end_game" );
    wait( seconds );

    if ( isdefined( ent ) && isdefined( level.mg_aud_fx_ent ) && level.mg_aud_fx_ent == ent )
        mg_aud_fx_stop();
}

// !mg snd ...  (self = player). Played to you at your own position = full volume, like the mod's cues.
mg_aud_snd( arg )
{
    list = mg_aud_snd_list();

    if ( !isdefined( arg ) || arg == "list" )
    {
        self thread mg_aud_print_list( list, "snd" );
        return;
    }

    idx = mg_aud_resolve( arg, list, level.mg_aud_snd_idx );
    name = arg;
    tag = "[SND] ";

    if ( isdefined( idx ) )
    {
        level.mg_aud_snd_idx = idx;
        name = list[idx];
        tag = "[SND " + idx + "/" + list.size + "] ";
    }

    self playsoundtoplayer( name, self );
    self mg_out( tag + name + "  (!mg snd next | prev | <n> | <alias> | list; silence = the alias is in no bank)" );
}
