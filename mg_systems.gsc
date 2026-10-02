#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

// Shared helpers (ported from Dead Frequency df_systems.gsc, trimmed to what this mod uses).

mg_debug_print( msg )
{
    if ( getdvarint( "mg_debug" ) == 1 )
    {
        iprintln( msg );
        print( "[MG] " + msg + "\n" );
    }
}

mg_out( text )
{
    if ( isdefined( self ) && isplayer( self ) )
        self iprintln( text );

    print( "[MG] " + text + "\n" );
}

// ---- fx -----------------------------------------------------------------------------------------------------
// key -> asset path: zm_prison's own (tools/assets/assets_zm_prison.txt) or the BO3 remaster's, shipped in mod.ff as mg/<name>
// (tools/bo3_fx.pl, tools/assets/bo3_fx.tsv). Dvars mg_fx_<key> override a path at load.
mg_fx_table()
{
    // one key per visible role: the BO3 remaster's own effect where it has one, else the one zm_prison plays for that
    // job (maps/mp/zm_prison_fx.gsc)
    t = [];
    // the fireplace: its boards burning at the first press, the lockdown, the souls and the lit skulls
    t["hearth_flare"] = "maps/zombie_alcatraz/fx_alcatraz_falling_fire_impact"; // the fire flaring as the souls go in
    t["fire_sm"] = "maps/zombie_alcatraz/fx_alcatraz_fire_sm"; // the boards burning (4 s)
    t["lockdown"] = "mg/fx_alcatraz_lockdown_wardens"; // the remaster's lockdown: the office's door and walls outlined
    t["soul_trail"] = "mg/lightning_hands_muzzleflash_trail"; // the remaster's soul rising over the body
    t["soul_full"] = "mg/fx_alcatraz_blue_flame_skull"; // the remaster's lit skull
    t["hearth_blue"] = "mg/fx_alcatraz_blue_flame_loop"; // the fireplace burning blue once the essence is deposited
    // the run: fire in the barrels, the temper riding the gun
    t["barrel_fire"] = "mg/fx_mg_barrel_flame"; // the remaster's drum flame, held inside the rim (tools/assets/bo3_fx.tsv)
    t["barrel_flare"] = "mg/fx_alcatraz_blue_flame_flare_up"; // the remaster's: a drum refilling the temper
    t["gun_flame"] = "mg/fx_alcatraz_blue_flame_vm"; // the remaster's tempered-gun flame
    // the forge
    t["sparks"] = "mg/fx_alcatraz_magmagat_power"; // the remaster's: the Machine powered
    t["forge_rise"] = "mg/fx_prison_magmagat_press_fire"; // the remaster's press at work
    t["ghost_body"] = "maps/zombie_alcatraz/fx_alcatraz_ghost_body"; // vanilla's Afterlife glow, on the forge's ghosts
    t["ghost_head"] = "maps/zombie_alcatraz/fx_alcatraz_ghost_head";
    t["ghost_tport"] = "maps/zombie_alcatraz/fx_alcatraz_afterlife_zmb_tport"; // a ghost appearing, vanishing
    // the weapon (its blob's trail is in the weapon file, tools/build_weapon.pl)
    t["burn"] = "maps/zombie_alcatraz/fx_alcatraz_zmb_fire_torso"; // a zombie the blob stuck to, burning
    t["patch_fire"] = "mg/fx_prison_magmagat_aoe"; // the remaster's lava pool
    t["blob_fire"] = "maps/zombie_alcatraz/fx_alcatraz_fire_xsm"; // a small fire riding the blob in flight
    t["impact"] = "mg/fx_magmagat_impact"; // Harry's: the blob landing
    t["explo"] = "mg/fx_magmagat_explode"; // Harry's: the blob bursting
    t["burst_fire"] = "maps/zombie/fx_zmb_tranzit_lava_torso_explo"; // Tranzit's lava zombie bursting: fire and smoke over it
    // the debug tools: a saved anchor, a previewed one
    t["blue_spark"] = "electrical/fx_elec_spark_bounce_blue_lg";
    t["glint"] = "maps/zombie_alcatraz/fx_alcatraz_key_glint";
    return t;
}

// Call from init() only (loadfx must run in the level-init window).
mg_fx_init()
{
    if ( !isdefined( level._effect ) )
        level._effect = [];

    foreach ( key, path in mg_fx_table() )
    {
        over = getdvar( "mg_fx_" + key );

        if ( isdefined( over ) && over != "" )
            path = over;

        level._effect["mg_" + key] = loadfx( path );
    }
}

// A looping effect on its own entity (mg_fx_stop deletes it). The effect is played one frame AFTER the entity is
// spawned: an entity the clients have not received yet drops any effect played on it (its sounds still play later),
// and a short settle follows before the caller moves or links it.
mg_fx_loop( key, origin, angles )
{
    if ( !isdefined( level._effect["mg_" + key] ) )
    {
        mg_debug_print( "MG: missing fx key " + key );
        return undefined;
    }

    ent = spawn( "script_model", origin );
    ent setmodel( "tag_origin" );

    if ( isdefined( angles ) )
        ent.angles = angles;

    wait 0.05;

    if ( !isdefined( ent ) )
        return undefined;

    playfxontag( level._effect["mg_" + key], ent, "tag_origin" );
    wait 0.1;
    return ent;
}

// A burst. Played on a short-lived entity, never loose: several zm_prison effects loop (the wolf heads' bite blood,
// the soul streak, the generator sparks), and a looping effect fired with playfx never stops and piles up; deleting
// its entity ends it. Returns at once (the play itself waits a frame for the entity to reach the clients).
mg_fx_once( key, origin, seconds, angles )
{
    if ( !isdefined( level._effect["mg_" + key] ) )
    {
        mg_debug_print( "MG: missing fx key " + key );
        return;
    }

    if ( !isdefined( seconds ) )
        seconds = 2.5;

    ent = spawn( "script_model", origin );
    ent setmodel( "tag_origin" );

    if ( isdefined( angles ) )
        ent.angles = angles;

    ent thread mg_fx_once_play( level._effect["mg_" + key], seconds );
}

// self = a burst's entity
mg_fx_once_play( fx, seconds )
{
    self endon( "death" );
    wait 0.05;
    playfxontag( fx, self, "tag_origin" );
    wait( seconds );
    self delete();
}

mg_fx_stop( ent )
{
    if ( isdefined( ent ) )
        ent delete();
}

// A second looping fx on an entity mg_fx_loop spawned (it goes with it).
mg_fx_add( ent, key )
{
    if ( isdefined( ent ) && isdefined( level._effect["mg_" + key] ) )
        playfxontag( level._effect["mg_" + key], ent, "tag_origin" );
}

// An effect on one of an entity's tags (a body's), if the effect is in the table.
mg_fx_add_tag( ent, key, tag )
{
    if ( isdefined( ent ) && isdefined( level._effect["mg_" + key] ) )
        playfxontag( level._effect["mg_" + key], ent, tag );
}

// A looping fx on a still entity is culled by the client after a while: nudge it 0.5 units every 5 s, until it goes
// or starts moving ("mg_moving": setting its origin would cut a moveto short).
mg_fx_keepalive( ent )
{
    level endon( "end_game" );
    ent endon( "death" );
    ent endon( "mg_moving" );
    up = 1;

    while ( isdefined( ent ) )
    {
        wait 5;

        if ( !isdefined( ent ) )
            return;

        if ( up )
            ent.origin = ent.origin + ( 0, 0, 0.5 );
        else
            ent.origin = ent.origin - ( 0, 0, 0.5 );

        up = !up;
    }
}

// ---- sound --------------------------------------------------------------------------------------------------
mg_snd_player( alias )
{
    if ( isdefined( self ) && isplayer( self ) )
        self playsoundtoplayer( alias, self );
}

// ---- HUD ----------------------------------------------------------------------------------------------------
mg_text_elem( y, scale, color )
{
    hud = newclienthudelem( self );
    hud.alignx = "center";
    hud.aligny = "bottom";
    hud.horzalign = "user_center";
    hud.vertalign = "user_bottom";
    hud.x = 0;
    hud.y = y;
    hud.font = "default";
    hud.fontscale = scale;
    hud.color = color;
    hud.alpha = 1;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    return hud;
}

// self = player. One prompt line; show 1 sets (or replaces) it, show 0 removes it.
mg_prompt( show, text )
{
    if ( show )
    {
        if ( isdefined( self.mg_prompt_hud ) )
        {
            if ( isdefined( self.mg_prompt_text ) && self.mg_prompt_text == text )
                return;

            self.mg_prompt_hud destroy();
        }

        hud = self mg_text_elem( -78, 1.3, ( 1, 1, 1 ) );
        hud settext( text );
        self.mg_prompt_hud = hud;
        self.mg_prompt_text = text;
        return;
    }

    if ( isdefined( self.mg_prompt_hud ) )
        self.mg_prompt_hud destroy();

    self.mg_prompt_hud = undefined;
    self.mg_prompt_text = undefined;
}

// self = player. 1 exactly once per press of the use key (300 ms debounce).
mg_press_use()
{
    pressed = self usebuttonpressed();
    was_down = is_true( self.mg_press_use_down );
    self.mg_press_use_down = pressed;

    if ( !pressed || was_down )
        return 0;

    if ( !isdefined( self.mg_press_use_last ) )
        self.mg_press_use_last = 0;

    if ( gettime() - self.mg_press_use_last < 300 )
        return 0;

    self.mg_press_use_last = gettime();
    return 1;
}

// HUD cleanup on disconnect, per player (started for everybody by mg_systems_boot).
mg_systems_boot()
{
    level endon( "end_game" );

    foreach ( player in getplayers() )
        player thread mg_hud_disconnect_watch();

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread mg_hud_disconnect_watch();
    }
}

mg_hud_disconnect_watch()
{
    if ( is_true( self.mg_hud_watched ) )
        return;

    self.mg_hud_watched = 1;
    self waittill( "disconnect" );

    if ( !isdefined( self ) )
        return;

    self mg_prompt( 0, undefined );
}

// ---- weapons ----------------------------------------------------------------------------------------------

// self = player. Puts weapon in his hands, as the mystery box does. T6 drops a switch asked in the frame of the
// giveweapon, and after a takeweapon of the gun in hand it first raises the other primary: the switch is asked again
// every 0.2 s, even during that raise, for up to 3 s.
mg_switch_to( weapon )
{
    self endon( "disconnect" );
    wait 0.05;

    for ( i = 0; i < 15; i++ )
    {
        if ( !self hasweapon( weapon ) || self getcurrentweapon() == weapon )
            return;

        self switchtoweapon( weapon );
        wait 0.2;
    }
}

// self = player. Gives weapon as the mystery box does: with a full hand of primaries (two, three with Mule Kick) the
// gun in hand makes room first (a gun given over the limit sits in no slot: it drops out of the hands). Then raises it.
mg_give_weapon( weapon )
{
    if ( !self hasweapon( weapon ) )
    {
        primaries = self getweaponslistprimaries();

        if ( isdefined( primaries ) && primaries.size >= get_player_weapon_limit( self ) )
        {
            current = self getcurrentweapon();

            // equipment or the revive tool in hand: a primary makes room instead
            if ( !isdefined( current ) || !isinarray( primaries, current ) )
                current = primaries[0];

            self takeweapon( current );
        }

        self giveweapon( weapon );
    }

    self thread mg_switch_to( weapon );
}

// ---- zombie deaths ------------------------------------------------------------------------------------------
mg_death_dispatch_init()
{
    if ( is_true( level.mg_death_ready ) )
        return;

    level.mg_death_ready = 1;
    level.mg_death_listeners = [];
    maps\mp\zombies\_zm_spawner::register_zombie_death_event_callback( ::mg_zombie_death_event );
}

// self = the zombie that died (self.attacker = the killer when a player)
mg_zombie_death_event()
{
    if ( !isdefined( level.mg_death_listeners ) )
        return;

    foreach ( func in level.mg_death_listeners )
    {
        if ( isdefined( func ) )
            [[ func ]]( self );
    }
}

mg_death_listen_add( key, func )
{
    mg_death_dispatch_init();
    level.mg_death_listeners[key] = func;
}

mg_death_listen_remove( key )
{
    if ( isdefined( level.mg_death_listeners ) )
        level.mg_death_listeners[key] = undefined;
}

// ---- the Warden's Office, as a box ---------------------------------------------------------------------------
// The remaster's soul catcher volume (the info_volume soul_catcher_mg targets, BO3 centre -4241 3787 2770), brought onto
// BO2 by the office fit (tools/assets/bo3_fx.tsv; it puts the BO3 skulls and office door within 10 units of ours): its
// sides are the lockdown's blue walls, west x -1070, south y 8493, the inner doorway y 9187, east x -440 (its centre
// maps to -755 8840). It holds the fireplace room and the office north of it up to that doorway. `!mg zone` shows it.
mg_in_office_box( pos )
{
    return pos[0] > -1070 && pos[0] < -440 && pos[1] > 8493 && pos[1] < 9187 && pos[2] > 1280 && pos[2] < 1560;
}

mg_ent_in_office( ent )
{
    if ( !isdefined( ent ) )
        return 0;

    return mg_in_office_box( ent.origin );
}
