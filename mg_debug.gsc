#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_weapon;
#include scripts\zm\zm_prison\mg_place;

// Debug tools (`!mg`, needs `set mg_debug 1`): give / magma / shock and the fx / snd audition (ported from
// the Dead Frequency mod's audition tool and renamed to this mod's prefix). The fx/snd grid ("!mg fx grid")
// was dropped: it needs a ground-trace helper and a "beacon" pedestal model that do not exist in this mod
// (owner 2026-09-18); the required part (`!mg fx <n|name|next|prev|stop>`, `!mg snd <n|alias|next|prev>`)
// ported unchanged.

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
        case "give":
            if ( !self hasweapon( "blundergat_zm" ) )
                self giveweapon( "blundergat_zm" );

            self switchtoweapon( "blundergat_zm" );
            self mg_out( "MG: Blundergat given" );
            return 1;

        case "magma":
            weapon = mg_has_blundergat( self );

            if ( !isdefined( weapon ) )
            {
                self mg_out( "MG: hold a Blundergat first (!mg give)" );
                return 1;
            }

            mg_weapon_grant( self, weapon );
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

// Prints the list ten names a line (the console wraps long lines).
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
