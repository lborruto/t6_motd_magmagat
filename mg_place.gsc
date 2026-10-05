#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_forge;

// Magmagat - live placement mode ("!mg grab <KEY>"), ported from Dead Frequency's df_place.gsc (2026-09-08).
//   The anchor's prop is held at the point under your crosshair and follows it: you walk, look, rotate and lift
//   it, then place it. Replaces guessing a height from `!mg spots`, which reports the anchor's stored position
//   and made props float above benches and tables.
//
// Controls while holding (every check is a builtin the stock scripts use: attackbuttonpressed
// Core/maps/mp/gametypes_zm/_gameobjects.gsc, adsbuttonpressed Core/maps/mp/zombies/_zm.gsc,
// meleebuttonpressed Core/maps/mp/animscripts/zm_dog_combat.gsc, usebuttonpressed, jumpbuttonpressed /
// sprintbuttonpressed Maps/Mob of the Dead/maps/mp/zm_prison_sq_fc.gsc, actionslot*buttonpressed
// Maps/Buried/maps/mp/zombies/_zm_ai_sloth.gsc):
//   fire / attack (mouse1, left click by default)   place it here and pin the anchor
//   melee (V by default; whatever key you have bound to melee)   cancel, leave the anchor as it was
//   ADS (right mouse)  hold to freeze the prop where it is (look around without moving it)
//   1 / 2 (slots 1/2)  turn left / right (15 deg, 5 with sprint held)
//   3 / 4 (slots 3/4)  lower / raise (4 units, 1 with sprint held)
//   use (F)            switch between "on the surface I aim at" and "floating 60 units in front of me"
//   jump (space)       face me again / reset the lift
//   chat fallback      !mg drop (place), !mg cancel (leave it as it was), !mg rot <deg>, !mg up <units>
//
// A place writes mg_coord_override( key, origin, angles, model ) (mg_coords.gsc), the same call
// mg_apply_overrides uses, and prints the paste-ready line so it can be made permanent in the sources.

// The forge machine's own part an anchor places (its key in level.mg_press: the lever), or undefined.
mg_place_press_part( key )
{
    if ( key == "MG_LEVER" )
        return "press_lever";

    return undefined;
}

mg_place_yaw_step()
{
    return 15;
}

mg_place_lift_step()
{
    return 4;
}

// How far in front of the eye a "floating" prop sits when surface snapping is off.
mg_place_float_dist()
{
    return 60;
}

// self = player. Starts holding `key`. A second grab replaces the first.
mg_place_grab( key )
{
    if ( !isdefined( mg_coord( key ) ) )
    {
        self mg_out( "MG: unknown anchor " + key + " (!mg spots lists them all)" );
        return;
    }

    self mg_place_end_current( "replaced" );
    mg_preview_hide(); // the !mg show copy of this anchor would sit inside the held prop

    c = mg_coord( key );
    model = c.model;
    had_model = isdefined( model );

    if ( !had_model )
        model = mg_model( "beacon" ); // anchors without a prop still need something visible

    // the forge's machine held: the real one goes meanwhile, and stands again where it is placed (or was); its lever
    // held: only the lever hides, the machine stays to fit it on
    part = mg_place_press_part( key );

    if ( key == "MG_PRESS" )
        mg_press_remove();
    else if ( isdefined( part ) && isdefined( level.mg_press[part] ) )
        level.mg_press[part] hide();

    ent = spawn( "script_model", c.origin );
    ent setmodel( model );
    ent.angles = c.angles;

    self.mg_place_key = key;
    self.mg_place_ent = ent;
    self.mg_place_model = model;
    self.mg_place_had_model = had_model;
    self.mg_place_yaw = 0;      // extra turn on top of "face me"
    self.mg_place_lift = 0;     // extra height above the surface
    self.mg_place_snap = 1;     // 1 = on the aimed surface, 0 = floating in front of me
    self.mg_place_start_org = c.origin;
    self.mg_place_start_ang = c.angles;
    self.mg_place_frozen = 0;
    // the lever, the machine's effects and its ghouls are fitted onto the machine, which the crosshair goes through (a
    // script_model stops no trace): they stay where they are and move by !mg move, !mg rot, !mg up and 1-4 only
    self.mg_place_pinned = isdefined( part ) || key == "MG_FORGE_GUN" || key == "MG_FORGE_FX" || key == "MG_GHOUL_1" || key == "MG_GHOUL_2";
    self.mg_place_nudge = ( 0, 0, 0 );

    self thread mg_place_think();

    if ( self.mg_place_pinned )
        self mg_out( "MG: holding " + key + ", pinned: !mg move <forward> <right> <up> (from where you look), !mg rot <deg>, !mg up <units>, 1/2 turn, 3/4 raise; FIRE = place, MELEE = cancel" );
    else
        self mg_out( "MG: holding " + key + " (" + model + "). FIRE = place, MELEE = cancel, ADS = freeze, 1/2 turn, 3/4 raise, F = surface/float, jump = reset, !mg drop / !mg cancel" );
    mg_debug_print( "MG: place mode on for " + key + " (" + model + ")" );
}

// self = player. The hold loop: follow the crosshair and read the buttons.
mg_place_think()
{
    self endon( "disconnect" );
    self endon( "mg_place_end" );
    level endon( "end_game" );

    last = 0;

    while ( isdefined( self.mg_place_ent ) )
    {
        wait 0.05;

        if ( !isdefined( self.mg_place_ent ) )
            return;

        self.mg_place_frozen = self adsbuttonpressed();

        if ( self.mg_place_pinned )
            self mg_place_pinned_update();
        else if ( !self.mg_place_frozen )
            self mg_place_follow();

        if ( gettime() - last > 200 )
        {
            last = gettime();
            self mg_place_hud();
        }

        // threaded: both end in mg_place_end_current, whose "mg_place_end" notify would kill this loop (and them with
        // it, before the [SPOT] line) if they ran inside it
        if ( self attackbuttonpressed() )
        {
            self thread mg_place_drop();
            return;
        }

        if ( self meleebuttonpressed() )
        {
            self thread mg_place_cancel();
            return;
        }

        self mg_place_buttons();
    }
}

// self = player. Moves the held prop under the crosshair (or in front of the eye when snapping is off).
mg_place_follow()
{
    eye = self geteye();
    forward = anglestoforward( self getplayerangles() );
    yaw = self.angles[1] + 180 + self.mg_place_yaw;
    pos = eye + forward * mg_place_float_dist();

    if ( self.mg_place_snap )
    {
        // park the held prop out of the way for the trace: aimed at, it was hit by its own trace and the prop
        // jumped between its face and the far wall every frame (owner 2026-09-18); the origin is set again below
        // in the same frame, so the client never sees the parking spot
        self.mg_place_ent.origin = ( 0, 0, -30000 );
        trace = bullettrace( eye, eye + forward * 2500, 0, self );
        pos = trace["position"];
        normal = ( 0, 0, 1 );

        if ( isdefined( trace["normal"] ) )
            normal = trace["normal"];

        // a wall or a fence: stand the prop against it, front pointing out of the surface
        if ( normal[2] < 0.35 && normal[2] > -0.35 )
        {
            pos = pos + normal * 2;
            yaw = vectortoangles( normal )[1] + self.mg_place_yaw;
        }
    }

    self.mg_place_ent.origin = pos + ( 0, 0, self.mg_place_lift );
    self.mg_place_ent.angles = ( self.mg_place_start_ang[0], yaw, self.mg_place_start_ang[2] );
}

// self = player. Turn, raise, snap mode, reset. Sprint held = fine steps.
mg_place_buttons()
{
    yaw_step = mg_place_yaw_step();
    lift_step = mg_place_lift_step();

    if ( self sprintbuttonpressed() )
    {
        yaw_step = 5;
        lift_step = 1;
    }

    if ( self actionslotonebuttonpressed() )
        self.mg_place_yaw -= yaw_step;

    if ( self actionslottwobuttonpressed() )
        self.mg_place_yaw += yaw_step;

    if ( self actionslotthreebuttonpressed() )
        self.mg_place_lift -= lift_step;

    if ( self actionslotfourbuttonpressed() )
        self.mg_place_lift += lift_step;

    if ( self usebuttonpressed() )
    {
        self.mg_place_snap = !self.mg_place_snap;
        self mg_out( "MG: " + mg_place_mode_text( self.mg_place_snap ) );
        wait 0.3; // one press, not a stream
    }

    if ( self jumpbuttonpressed() )
    {
        self.mg_place_yaw = 0;
        self.mg_place_lift = 0;
    }
}

mg_place_mode_text( snap )
{
    if ( snap )
        return "on the surface I aim at";

    return "floating " + mg_place_float_dist() + " units in front of me";
}

// self = player. Live read-out at the bottom of the screen.
mg_place_hud()
{
    if ( !isdefined( self.mg_place_ent ) )
        return;

    o = self.mg_place_ent.origin;
    text = self.mg_place_key + "  " + mg_vec_str( o ) + "  yaw " + int( self.mg_place_ent.angles[1] ) + "  lift " + int( self.mg_place_lift );

    if ( self.mg_place_frozen )
        text += "  [frozen]";

    self mg_prompt( 1, text );
}

// self = player. Pins the anchor where the prop stands and prints the line for the sources.
mg_place_drop()
{
    if ( !isdefined( self.mg_place_ent ) )
    {
        self mg_out( "MG: nothing held (!mg grab <KEY> first)" );
        return;
    }

    key = self.mg_place_key;
    model = self.mg_place_model;
    had_model = self.mg_place_had_model;
    origin = self.mg_place_ent.origin;
    angles = self.mg_place_ent.angles;

    // the machine placed: the gun on its bed, the use spot and the lever move and turn with it
    if ( key == "MG_PRESS" )
    {
        old = mg_coord( key );
        turn = angles[1] - old.angles[1];

        foreach ( k in array( "MG_FORGE_GUN", "MG_FORGE", "MG_LEVER", "MG_FORGE_FX", "MG_GHOUL_1", "MG_GHOUL_2" ) )
        {
            a = mg_coord( k );
            off = a.origin - old.origin;
            mg_coord_override( k, origin + ( off[0] * cos( turn ) - off[1] * sin( turn ), off[0] * sin( turn ) + off[1] * cos( turn ), off[2] ), a.angles + ( 0, turn, 0 ) );
            self mg_out( mg_coord_line( k ) );
        }
    }

    if ( had_model )
        mg_coord_override( key, origin, angles, model );
    else
        mg_coord_override( key, origin, angles );

    self mg_place_end_current( "placed" );

    // the held copy is gone, so put the anchor's own prop back: without this the model just vanishes on a
    // place and there is nothing to judge
    mg_preview_refresh( key );

    // mg_out, not mg_debug_print: the paste-ready line must reach the console whatever mg_debug is set to
    self mg_out( "[SPOT] " + key + " | " + mg_vec_str( origin ) + " | " + mg_vec_str( angles ) + " | " + model );

    line = "mg_coord_override( \"" + key + "\", ( " + int( origin[0] ) + ", " + int( origin[1] ) + ", " + int( origin[2] ) + " ), ( " + int( angles[0] ) + ", " + int( angles[1] ) + ", " + int( angles[2] ) + " )";

    if ( had_model )
        line += ", \"" + model + "\"";

    line += " );";
    self mg_out( line );

    self mg_snd_player( "zmb_buildable_complete" );
    mg_fx_once( "blue_spark", origin + ( 0, 0, 8 ) );
}

// self = player. Leaves the anchor exactly as it was.
mg_place_cancel()
{
    if ( !isdefined( self.mg_place_ent ) )
    {
        self mg_out( "MG: nothing held" );
        return;
    }

    key = self.mg_place_key;
    self mg_place_end_current( "cancelled" );
    self mg_out( "MG: " + key + " left where it was" );
}

// self = player. Removes the held prop and the read-out. `why` only goes to the console.
mg_place_end_current( why )
{
    if ( !isdefined( self.mg_place_ent ) )
        return;

    key = self.mg_place_key;
    self.mg_place_ent delete();
    self.mg_place_ent = undefined;
    self.mg_place_key = undefined;

    // the machine back (its lever with it, where it was placed)
    if ( isdefined( mg_place_press_part( key ) ) )
        mg_press_remove();

    if ( key == "MG_PRESS" || isdefined( mg_place_press_part( key ) ) )
        mg_press_spawn();

    self mg_prompt( 0, undefined );
    self notify( "mg_place_end" );
    mg_debug_print( "MG: place mode off (" + key + ", " + why + ")" );
}

// self = player. "!mg rot <deg>" and "!mg up <units>" for people who prefer typing.
mg_place_rot( deg )
{
    if ( !isdefined( self.mg_place_ent ) )
    {
        self mg_out( "MG: nothing held (!mg grab <KEY> first)" );
        return;
    }

    self.mg_place_yaw += deg;
    self mg_place_hud();
    self mg_out( "MG: turn " + int( self.mg_place_yaw ) + " deg" );
}

// self = player. A pinned prop (mg_place_pinned): its anchor, nudged, raised and turned, never the crosshair.
mg_place_pinned_update()
{
    a = self.mg_place_start_ang;
    self.mg_place_ent.origin = self.mg_place_start_org + self.mg_place_nudge + ( 0, 0, self.mg_place_lift );
    self.mg_place_ent.angles = ( a[0], a[1] + self.mg_place_yaw, a[2] );
}

// self = player. "!mg move <forward> <right> <up>": a pinned prop nudged in units, from where the player looks
mg_place_move( f, r, u )
{
    if ( !isdefined( self.mg_place_ent ) || !is_true( self.mg_place_pinned ) )
    {
        self mg_out( "MG: !mg move needs a pinned prop held (!mg grab MG_LEVER)" );
        return;
    }

    yaw = ( 0, self getplayerangles()[1], 0 );
    self.mg_place_nudge = self.mg_place_nudge + anglestoforward( yaw ) * f + anglestoright( yaw ) * r + ( 0, 0, u );
    self mg_place_hud();
}

mg_place_up( units )
{
    if ( !isdefined( self.mg_place_ent ) )
    {
        self mg_out( "MG: nothing held (!mg grab <KEY> first)" );
        return;
    }

    self.mg_place_lift += units;
    self mg_place_hud();
    self mg_out( "MG: lift " + int( self.mg_place_lift ) + " units" );
}

// ------------------------------------------------------------------------------------------ previews ----
// "!mg show [KEY]": spawns a copy of one anchor (or every anchor) plus a glint marker above it, so a spot
// can be judged in game without holding it.
mg_preview_show( key )
{
    if ( !isdefined( key ) )
    {
        foreach ( k in mg_coords_keys() )
        {
            mg_preview_refresh( k );
            mg_debug_print( "MG: " + mg_coord_line( k ) );
        }

        return;
    }

    mg_preview_refresh( key );
    mg_debug_print( "MG: " + mg_coord_line( key ) );
}

// (Re)spawn the preview of one key: model at the anchor plus a glint marker above it.
mg_preview_refresh( key )
{
    if ( !isdefined( level.mg_preview ) )
        level.mg_preview = [];

    if ( isdefined( level.mg_preview[key] ) )
    {
        foreach ( ent in level.mg_preview[key] )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.mg_preview[key] = [];
    c = mg_coord( key );

    if ( !isdefined( c ) )
        return;

    if ( isdefined( c.model ) )
    {
        ent = spawn( "script_model", c.origin );
        ent setmodel( c.model );
        ent.angles = c.angles;
        level.mg_preview[key][level.mg_preview[key].size] = ent;
    }

    marker = mg_fx_loop( "glint", c.origin + ( 0, 0, 40 ) );

    if ( isdefined( marker ) )
        level.mg_preview[key][level.mg_preview[key].size] = marker;
}

mg_preview_hide()
{
    if ( !isdefined( level.mg_preview ) )
        return;

    foreach ( key in getarraykeys( level.mg_preview ) )
    {
        foreach ( ent in level.mg_preview[key] )
        {
            if ( isdefined( ent ) )
                ent delete();
        }
    }

    level.mg_preview = [];
}

// self = player. Stands them 20 units above the anchor, only while they are on their feet (is_player_valid:
// connected, alive, not spectating) so a mid-air or downed player is left alone. Returns 1/0.
mg_preview_teleport( key )
{
    c = mg_coord( key );

    if ( !isdefined( c ) )
        return 0;

    if ( !is_player_valid( self ) )
        return 0;

    self setorigin( c.origin + ( 0, 0, 20 ) );
    return 1;
}
