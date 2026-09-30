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
    t["hearth_flare"] = "maps/zombie_alcatraz/fx_alcatraz_falling_fire_impact"; // the boards bursting into flame
    t["fire_sm"] = "maps/zombie_alcatraz/fx_alcatraz_fire_sm"; // the boards burning (4 s)
    t["lockdown"] = "mg/fx_alcatraz_lockdown_wardens"; // the remaster's lockdown: the office's door and walls outlined
    t["soul_trail"] = "mg/lightning_hands_muzzleflash_trail"; // the remaster's soul rising over the body
    t["soul_full"] = "mg/fx_alcatraz_blue_flame_skull"; // the remaster's lit skull
    // the run: fire in the barrels, the temper riding the gun
    t["barrel_fire"] = "mg/fx_alcatraz_blue_flame_loop"; // the remaster's drum flame
    t["barrel_flare"] = "mg/fx_alcatraz_blue_flame_flare_up"; // the remaster's: a drum refilling the temper
    t["gun_flame"] = "mg/fx_alcatraz_blue_flame_vm"; // the remaster's tempered-gun flame
    // the forge
    t["sparks"] = "mg/fx_alcatraz_magmagat_power"; // the remaster's: the Machine powered
    t["forge_rise"] = "mg/fx_prison_magmagat_press_fire"; // the remaster's press at work
    // the weapon (its bolt's trail, impact and burst are in the weapon files, tools/build_weapon.pl)
    t["burn"] = "maps/zombie_alcatraz/fx_alcatraz_zmb_fire_torso"; // a zombie the blob stuck to, burning
    t["patch_fire"] = "mg/fx_prison_magmagat_aoe"; // the remaster's lava pool
    t["explo"] = "mg/fx_magmagat_explode"; // the blob bursting (`!mg tour`; the weapon file plays it in the game)
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

mg_player_in_office( player )
{
    return isdefined( player ) && is_player_valid( player ) && mg_ent_in_office( player );
}
