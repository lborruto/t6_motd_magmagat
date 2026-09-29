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
// key -> asset path. Every path is in tools/assets/assets_zm_prison.txt. Dvars mg_fx_<key> override a path at load.
mg_fx_table()
{
    // one key per visible role; each is the effect zm_prison itself plays for that job (maps/mp/zm_prison_fx.gsc,
    // clientscripts/mp/zm_prison_weap_quest.csc), overridable in game with the dvar mg_fx_<key>
    t = [];
    t["fire_md"] = "maps/zombie_alcatraz/fx_alcatraz_fire_md";
    t["fire_sm"] = "maps/zombie_alcatraz/fx_alcatraz_fire_sm";
    t["fire_xsm"] = "maps/zombie_alcatraz/fx_alcatraz_fire_xsm";
    t["embers"] = "maps/zombie_alcatraz/fx_alcatraz_embers_flat";
    t["blue_fire"] = "maps/zombie_alcatraz/fx_alcatraz_afterlife_zmb_tport";
    // the souls: the wolf heads' own (a soul leaves the body and flies; a full catcher glows)
    t["soul_release"] = "maps/zombie_alcatraz/fx_alcatraz_soul_charge_start";
    t["soul"] = "maps/zombie_alcatraz/fx_alcatraz_soul_charged";
    t["soul_start"] = "maps/zombie_alcatraz/fx_alcatraz_soul_charge_start";
    t["soul_trail"] = "weapon/lightning_hands/lightning_hands_muzzleflash_trail"; // the BO3 remaster's soul trail
    t["soul_arrive"] = "weapon/tomahawk/fx_tomahawk_charge_ug"; // a soul-energy flash (the wolf heads' impact is their bite blood)
    t["soul_hit"] = "weapon/tomahawk/fx_tomahawk_charge"; // the soul taken by a player
    t["soul_full"] = "maps/zombie_alcatraz/fx_alcatraz_soul_charged";
    // the hearth: a real fire; the hell portal of the wolf heads opens in it for the tempered gun
    t["hearth_fire"] = "maps/zombie_alcatraz/fx_alcatraz_fire_md";
    t["hearth_blue"] = "maps/zombie_alcatraz/fx_alcatraz_portal_hell";
    t["hearth_close"] = "maps/zombie_alcatraz/fx_alcatraz_portal_hell_close";
    t["hearth_flare"] = "maps/zombie_alcatraz/fx_alcatraz_falling_fire_impact"; // the deposit's flare-up
    t["gun_vanish"] = "maps/zombie_alcatraz/fx_alcatraz_afterlife_zmb_tport"; // a gun not taken in time vanishes
    // the run: fire in the barrels, the temper riding the gun
    t["barrel_fire"] = "maps/zombie_alcatraz/fx_alcatraz_fire_sm";
    t["barrel_flare"] = "maps/zombie_alcatraz/fx_alcatraz_falling_fire_impact"; // a barrel spent on a refill
    t["gun_flame"] = "maps/zombie_alcatraz/fx_alcatraz_fire_xsm";
    // the forge: the generator's own sparks and smoke, afterlife ghosts, the quest-item glow on the gun to take
    t["ghost"] = "maps/zombie_alcatraz/fx_alcatraz_afterlife_zmb_tport";
    t["sparks"] = "maps/zombie_alcatraz/fx_alcatraz_generator_sparks";
    t["smoke"] = "maps/zombie_alcatraz/fx_alcatraz_generator_smk";
    t["glow"] = "maps/zombie_alcatraz/fx_alcatraz_quest_item_glow";
    t["glint"] = "maps/zombie_alcatraz/fx_alcatraz_key_glint";
    t["forge_rise"] = "maps/zombie_alcatraz/fx_alcatraz_fire_sm";
    // the weapon: the lava blob's fire trail, its impact, the lava gib, zombies on fire (the tomahawk's burning torso)
    t["ball"] = "maps/zombie_alcatraz/fx_alcatraz_falling_fire";
    t["ball_hit"] = "maps/zombie_alcatraz/fx_alcatraz_falling_fire_impact";
    t["burn"] = "maps/zombie_alcatraz/fx_alcatraz_zmb_fire_torso";
    t["explo"] = "maps/zombie/fx_zmb_tranzit_lava_torso_explo";
    t["blue_spark"] = "electrical/fx_elec_spark_bounce_blue_lg";
    t["patch_fire"] = "maps/zombie_alcatraz/fx_alcatraz_fire_xsm";
    t["magma_hold"] = "maps/zombie_alcatraz/fx_alcatraz_fire_xsm"; // the flame riding a held Magmagat
    t["magmus_hold"] = "maps/zombie_alcatraz/fx_alcatraz_fire_sm"; // the same on the Magmus Operandi, bigger
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

    playfxontag( level._effect["mg_" + key], ent, "tag_origin" );
    // an effect whose entity moves or links on its spawn frame may never draw: callers get it settled
    wait 0.15;
    return ent;
}

// A burst. Played on a short-lived entity, never loose: several zm_prison effects loop (the wolf heads' bite blood,
// the soul streak, the generator sparks), and a looping effect fired with playfx never stops and piles up; deleting
// its entity ends it.
mg_fx_once( key, origin, seconds )
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
    playfxontag( level._effect["mg_" + key], ent, "tag_origin" );
    ent thread mg_fx_once_end( seconds );
}

// self = a burst's entity
mg_fx_once_end( seconds )
{
    wait( seconds );

    if ( isdefined( self ) )
        self delete();
}

mg_fx_stop( ent )
{
    if ( isdefined( ent ) )
        ent delete();
}

// A looping fx on a still entity is culled by the client after a while: nudge it 0.5 units every 5 s.
mg_fx_keepalive( ent )
{
    level endon( "end_game" );
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

// A fresh trail entity that settles 0.15 s before it flies (a moved-on-spawn entity is sometimes never seen).
mg_trail( fxkey, from, to, speed )
{
    level endon( "end_game" );
    // aimed along the flight: the soul streak points where it goes
    ent = mg_fx_loop( fxkey, from, vectortoangles( to - from ) );

    if ( !isdefined( ent ) )
        return;

    time = distance( from, to ) / speed;

    if ( time < 0.3 )
        time = 0.3;

    if ( time > 2 )
        time = 2;

    ent moveto( to, time );
    wait( time );
    mg_fx_stop( ent );
}

// ---- sound --------------------------------------------------------------------------------------------------
mg_snd_near( alias, origin, radius )
{
    foreach ( player in getplayers() )
    {
        if ( distancesquared( player.origin, origin ) <= radius * radius )
            player playsoundtoplayer( alias, player );
    }
}

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

mg_bar_elem( color, alpha, width )
{
    hud = newclienthudelem( self );
    hud.alignx = "left";
    hud.aligny = "middle";
    hud.horzalign = "user_center";
    hud.vertalign = "user_bottom";
    hud.x = -100;
    hud.y = -48;
    hud.color = color;
    hud.alpha = alpha;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    hud setshader( "white", width, 8 );
    return hud;
}

// self = player
mg_bar_create( label )
{
    bar = spawnstruct();
    bar.width = 200;
    bar.owner = self;
    bar.bg = self mg_bar_elem( ( 0.1, 0.1, 0.1 ), 0.6, bar.width );
    bar.fill = self mg_bar_elem( ( 1, 0.55, 0.1 ), 0.9, 1 );

    if ( isdefined( label ) )
    {
        bar.text = self mg_text_elem( -56, 1.2, ( 1, 1, 1 ) );
        bar.text settext( label );
    }

    if ( !isdefined( self.mg_bars ) )
        self.mg_bars = [];

    if ( !isdefined( self.mg_bar_seq ) )
        self.mg_bar_seq = 0;

    self.mg_bar_seq++;
    bar.id = "b" + self.mg_bar_seq;
    self.mg_bars[bar.id] = bar;
    return bar;
}

mg_bar_update( bar, frac )
{
    if ( !isdefined( bar ) || !isdefined( bar.fill ) )
        return;

    if ( frac < 0 )
        frac = 0;

    if ( frac > 1 )
        frac = 1;

    w = int( bar.width * frac );

    if ( w < 1 )
        w = 1;

    bar.fill setshader( "white", w, 8 );
}

mg_bar_destroy( bar )
{
    if ( !isdefined( bar ) )
        return;

    if ( isdefined( bar.bg ) )
        bar.bg destroy();

    if ( isdefined( bar.fill ) )
        bar.fill destroy();

    if ( isdefined( bar.text ) )
        bar.text destroy();

    if ( isdefined( bar.owner ) && isdefined( bar.owner.mg_bars ) && isdefined( bar.id ) )
        bar.owner.mg_bars[bar.id] = undefined;
}

// self = player. A big centred title for `seconds` (the weapon name the HUD cannot show).
mg_hud_title( text, seconds )
{
    self endon( "disconnect" );

    if ( isdefined( self.mg_title_hud ) )
        self.mg_title_hud destroy();

    hud = self mg_text_elem( -140, 2.2, ( 1, 0.6, 0.15 ) );
    hud settext( text );
    hud.alpha = 0;
    hud fadeovertime( 0.3 );
    hud.alpha = 1;
    self.mg_title_hud = hud;
    wait( seconds );

    if ( isdefined( self.mg_title_hud ) && self.mg_title_hud == hud )
    {
        hud fadeovertime( 0.5 );
        hud.alpha = 0;
        wait 0.5;

        if ( isdefined( hud ) )
            hud destroy();

        self.mg_title_hud = undefined;
    }
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

    if ( isdefined( self.mg_title_hud ) )
        self.mg_title_hud destroy();

    if ( isdefined( self.mg_bars ) )
    {
        foreach ( bar in self.mg_bars )
        {
            if ( isdefined( bar ) )
                mg_bar_destroy( bar );
        }
    }

    self.mg_bars = [];
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

mg_zombies_near( pos, radius )
{
    n = 0;
    r2 = radius * radius;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && distancesquared( ai.origin, pos ) < r2 )
            n++;
    }

    return n;
}

// ---- the Warden's Office, as a box ---------------------------------------------------------------------------
// The map's zone_warden_office volume is smaller than the room looks (owner 2026-09-20: kills inside the room did not
// count). The owner walked the four corners: (-1056 8804) (-1056 8527) (-463 8531) (-462 8809), floor 1311..1336.
mg_in_office_box( pos )
{
    return pos[0] > -1070 && pos[0] < -450 && pos[1] > 8515 && pos[1] < 8820 && pos[2] > 1280 && pos[2] < 1520;
}

mg_ent_in_office( ent )
{
    if ( !isdefined( ent ) )
        return 0;

    return mg_in_office_box( ent.origin );
}

mg_player_in_office( player )
{
    return isdefined( player ) && is_player_valid( player ) && mg_ent_in_office( player );
}
