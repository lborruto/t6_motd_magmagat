#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;

// The Magmagat is its own weapon, magmagat_zm, shipped in our mod.ff (tools/build_weapon.pl: the Blundergat's rig
// and animations, a lava skin); its Pack-a-Punch is magmagat_upgraded_zm, the Magmus Operandi. Each shot also
// launches a lava blob with BO4's numbers (zm_weap_blundergat.gsc): a zombie that catches it burns 0.5 s, then dies
// (up to 1000 health; stronger ones take 1000 and burn 4 s) and everything within 128 units takes 400 and catches
// fire; a miss leaves a 5 s molten pool (3 at most) that sets zombies on fire, lures them, and hurts its owner.
// Brutus burns (10-20 % of his health a second for 5 s, half from round 15): the lava can kill him, as in BO4.
// The look lives in the weapon file (tools/build_weapon.pl: lava tanks, fire muzzle flash, red tracers); the script
// adds the flame riding the held gun, the fire whoosh of every shot, and flies BO4's kind of effects: a tumbling
// lava blob (mg_lava_blob) and a molten pool mesh under every miss (mg_lava_pool).
// The Acid Gat kit takes it (BO4): the Magmagat goes in as the Blundergat it was, the kit makes the Acid Gat.

mg_weapon_init()
{
    level.mg_patches = [];
    mg_weapon_register();
    // chained, not replaced: vanilla _zm_ai_brutus.gsc installs its own hook on this map (a Brutus-locked table)
    level.mg_prev_craftable_validation = level.custom_craftable_validation;
    level.custom_craftable_validation = ::mg_acid_station_validation;
    level thread mg_weapon_connect_watch();
}

// init() only (precacheitem).
mg_weapon_precache()
{
    precacheitem( "magmagat_zm" );
    precacheitem( "magmagat_upgraded_zm" );
}

// Pack-a-Punch reads level.zombie_weapons[name].upgrade_name (vanilla _zm_weapons::can_upgrade_weapon): the
// Magmagat copies the Blundergat's entry, out of the Mystery Box.
mg_weapon_register()
{
    base = level.zombie_weapons["blundergat_zm"];
    s = spawnstruct();
    s.weapon_name = "magmagat_zm";
    s.upgrade_name = "magmagat_upgraded_zm";
    s.weapon_classname = "weapon_magmagat_zm";
    s.is_in_box = 0;

    if ( isdefined( base ) )
    {
        s.hint = base.hint;
        s.cost = base.cost;
        s.vox = base.vox;
        s.vox_response = base.vox_response;
        s.ammo_cost = base.ammo_cost;
    }

    level.zombie_weapons["magmagat_zm"] = s;
    level.zombie_weapons_upgraded["magmagat_upgraded_zm"] = "magmagat_zm";
    level.zombie_include_weapons["magmagat_zm"] = 0;
}

// The Magmagat a gun becomes at the forge: a Pack-a-Punched one (Sweeper, Vitriolic Withering) gives the Magmus
// Operandi (BO4).
mg_magma_of( weapon )
{
    if ( isdefined( weapon ) && ( weapon == "blundergat_upgraded_zm" || weapon == "blundersplat_upgraded_zm" ) )
        return "magmagat_upgraded_zm";

    return "magmagat_zm";
}

mg_is_magma( weapon )
{
    return isdefined( weapon ) && ( weapon == "magmagat_zm" || weapon == "magmagat_upgraded_zm" );
}

// The Magmagat this player carries, or undefined.
mg_has_magma( player )
{
    if ( !isdefined( player ) )
        return undefined;

    if ( player hasweapon( "magmagat_upgraded_zm" ) )
        return "magmagat_upgraded_zm";

    if ( player hasweapon( "magmagat_zm" ) )
        return "magmagat_zm";

    return undefined;
}

// self = player. Swaps the held Blundergat (or gives one) for its Magmagat.
mg_weapon_grant( weapon )
{
    magma = mg_magma_of( weapon );
    current = self getcurrentweapon();
    primaries = self getweaponslistprimaries();

    if ( isdefined( weapon ) && self hasweapon( weapon ) )
        self takeweapon( weapon );
    else if ( isdefined( primaries ) && primaries.size >= 2 && mg_can_replace_current( self ) )
        self takeweapon( current );

    if ( !self hasweapon( magma ) )
        self giveweapon( magma );

    self switchtoweapon( magma );
    self givemaxammo( magma );
    self mg_snd_player( "zmb_hellbox_arrive" );
    mg_debug_print( "MG: " + self.name + " holds a " + magma );
}

mg_weapon_connect_watch()
{
    level endon( "end_game" );

    foreach ( player in getplayers() )
    {
        player thread mg_weapon_shot_loop();
        player thread mg_weapon_hold_loop();
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread mg_weapon_shot_loop();
        player thread mg_weapon_hold_loop();
    }
}

// self = player. While a Magmagat is in hand (and the player is up) a small flame rides the gun; switching away,
// going down or dropping the gun puts it out.
mg_weapon_hold_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( is_true( self.mg_hold_watched ) )
        return;

    self.mg_hold_watched = 1;
    held = undefined;

    while ( true )
    {
        wait 0.2;
        weapon = self getcurrentweapon();

        if ( !mg_is_magma( weapon ) || !is_player_valid( self ) )
            weapon = undefined;

        if ( isdefined( held ) && isdefined( weapon ) && held == weapon && isdefined( self.mg_hold_fx ) )
            continue;

        mg_fx_stop( self.mg_hold_fx );
        self.mg_hold_fx = undefined;
        held = weapon;

        if ( !isdefined( weapon ) )
            continue;

        key = "magma_hold";

        if ( weapon == "magmagat_upgraded_zm" )
            key = "magmus_hold";

        fx = mg_fx_loop( key, self gettagorigin( "tag_weapon_right" ) );

        if ( !isdefined( fx ) )
            continue;

        fx linkto( self, "tag_weapon_right", ( 0, 0, 0 ), ( 0, 0, 0 ) );
        fx thread mg_weapon_hold_owner( self );
        self.mg_hold_fx = fx;
    }
}

// self = the held flame. It dies with its owner (a disconnect ends the hold loop before it can clean up).
mg_weapon_hold_owner( owner )
{
    self endon( "death" );

    while ( isdefined( owner ) )
        wait 0.5;

    self delete();
}

// self = player
mg_weapon_shot_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( is_true( self.mg_weapon_watched ) )
        return;

    self.mg_weapon_watched = 1;
    self.mg_balls = 0;

    while ( true )
    {
        self waittill( "weapon_fired", weapon );

        if ( !mg_is_magma( weapon ) )
            continue;

        mg_snd_near( "zmb_plane_fire_whoosh", self.origin, 900 );

        if ( self.mg_balls >= 3 )
            continue;

        self thread mg_lava_ball( weapon );
    }
}

// self = player. The ball flies to where the crosshair points (max 3000 units).
mg_lava_ball( weapon )
{
    self endon( "disconnect" );
    level endon( "end_game" );
    self.mg_balls++;
    eye = self geteye();
    fwd = anglestoforward( self getplayerangles() );
    trace = bullettrace( eye, eye + fwd * 3000, 1, self );
    target = trace["position"];
    start = self getweaponmuzzlepoint();
    ball = spawn( "script_model", start );
    ball setmodel( mg_model( "ball" ) );
    ball.angles = self getplayerangles();

    if ( isdefined( level._effect["mg_ball"] ) )
        playfxontag( level._effect["mg_ball"], ball, "tag_origin" );

    dist = distance( start, target );
    time = dist / 2000;

    if ( time < 0.05 )
        time = 0.05;

    ball moveto( target, time );
    ball rotatevelocity( ( 420, 260, 0 ), time + 1 );
    caught = undefined;
    aimed = undefined;
    hit_ent = trace["entity"];

    // the aimed zombie is caught when the ball ARRIVES, not now: the flight must be seen
    if ( isdefined( hit_ent ) && isai( hit_ent ) && isalive( hit_ent ) )
        aimed = hit_ent;

    elapsed = 0;

    while ( !isdefined( caught ) && elapsed < time )
    {
        wait 0.05;
        elapsed += 0.05;

        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( isdefined( ai ) && isalive( ai ) && distancesquared( ai.origin + ( 0, 0, 40 ), ball.origin ) < 40 * 40 )
            {
                caught = ai;
                break;
            }
        }
    }

    if ( !isdefined( caught ) && isdefined( aimed ) && isalive( aimed ) && distancesquared( aimed.origin + ( 0, 0, 40 ), ball.origin ) < 80 * 80 )
        caught = aimed;

    self.mg_balls--;

    if ( isdefined( caught ) && isalive( caught ) )
    {
        self thread mg_ball_explode( ball, caught, weapon );
        return;
    }

    pos = ball.origin;
    ball delete();
    mg_fx_once( "ball_hit", pos );
    self thread mg_patch( pos, weapon );
}

// self = player. The blob sticks 0.5 s, then (BO4): the zombie dies if it has 1000 health or less, else takes 1000
// and burns 4 s before dying; everyone within 128 units takes 400 and catches fire. Brutus burns instead.
mg_ball_explode( ball, zombie, weapon )
{
    level endon( "end_game" );
    ball linkto( zombie, "J_SpineUpper", ( 0, 0, 0 ), ( 0, 0, 0 ) );

    if ( isdefined( zombie.animname ) && zombie.animname == "brutus_zombie" )
    {
        self thread mg_brutus_burn( zombie, ball, weapon );
        return;
    }

    burn = mg_fx_loop( "burn", zombie.origin + ( 0, 0, 40 ) );

    if ( isdefined( burn ) )
        burn linkto( zombie, "J_SpineUpper", ( 0, 0, 0 ), ( 0, 0, 0 ) );

    wait 0.35;
    pos = ball.origin;

    if ( isdefined( zombie ) )
        pos = zombie.origin + ( 0, 0, 30 );

    ball delete();
    mg_fx_stop( burn );
    mg_fx_once( "explo", pos );
    mg_snd_near( "wpn_blundersplat_explode", pos, 1200 );

    if ( isdefined( zombie ) && isalive( zombie ) )
    {
        if ( zombie.health <= 1000 )
            zombie dodamage( zombie.health + 666, pos, self, self, "none", "MOD_PROJECTILE", 0, weapon );
        else
        {
            zombie dodamage( 1000, pos, self, self, "none", "MOD_PROJECTILE", 0, weapon );
            zombie thread mg_burn_fx( 4 );
            self thread mg_burn_then_die( zombie, 4, weapon );
        }
    }

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( !isdefined( ai ) || !isalive( ai ) || ai == zombie || distancesquared( ai.origin, pos ) > 128 * 128 )
            continue;

        if ( isdefined( ai.animname ) && ai.animname == "brutus_zombie" )
            continue;

        ai dodamage( 400, pos, self, self, "none", "MOD_GRENADE_SPLASH", 0, weapon );

        if ( isalive( ai ) && !is_true( ai.mg_burning ) )
        {
            ai.mg_burning = 1;
            ai thread mg_burn_fx( 3 );
            ai thread mg_burn_clear( 3 );
        }
    }
}

// self = player. A strong zombie burns, then dies.
mg_burn_then_die( zombie, seconds, weapon )
{
    zombie endon( "death" );
    wait( seconds );

    if ( isalive( zombie ) )
        zombie dodamage( zombie.health + 666, zombie.origin, self, self, "none", "MOD_BURNED", 0, weapon );
}

// self = zombie
mg_burn_fx( seconds )
{
    self endon( "death" );
    fx = mg_fx_loop( "burn", self.origin + ( 0, 0, 40 ) );

    if ( isdefined( fx ) )
        fx linkto( self, "J_SpineUpper", ( 0, 0, 0 ), ( 0, 0, 0 ) );

    wait( seconds );
    mg_fx_stop( fx );
}

// self = player. Brutus and the blob (BO4): 100 at once, then 10-20 % of his maximum health a second (5-10 % from
// round 15) for 5 s while the blob burns on him. It can kill him.
mg_brutus_burn( ai, ball, weapon )
{
    level endon( "end_game" );
    ai dodamage( 100, ai.origin, self, self, "none", "MOD_PROJECTILE", 0, weapon );
    ai thread mg_burn_fx( 5 );
    lo = 0.1;
    hi = 0.2;

    if ( level.round_number >= 15 )
    {
        lo = 0.05;
        hi = 0.1;
    }

    for ( t = 0; t < 5 && isdefined( ai ) && isalive( ai ); t++ )
    {
        wait 1;

        if ( isdefined( ai ) && isalive( ai ) )
            ai dodamage( int( ai.maxhealth * randomfloatrange( lo, hi ) ), ai.origin, self, self, "none", "MOD_BURNED", 0, weapon );
    }

    if ( isdefined( ball ) )
        ball delete();
}

// self = player. A molten pool (BO4): 5 s, 64 units across, 3 at most (the oldest goes). A zombie that walks in
// catches fire: 10 % of its health at once, then a burn that scales with the round; a crawler dies at once. The pool
// lures zombies (128 units, 3 of them; the Magmus Operandi's 256 and 6) and hurts its owner (1 every 0.4 s).
// Brutus burns 2 % of his health every 0.5 s in it.
mg_patch( pos, weapon )
{
    level endon( "end_game" );

    if ( !isdefined( self.mg_patches ) )
        self.mg_patches = [];

    while ( self.mg_patches.size >= 3 )
    {
        mg_patch_stop( self.mg_patches[0] );
        rest = [];

        for ( i = 1; i < self.mg_patches.size; i++ )
            rest[rest.size] = self.mg_patches[i];

        self.mg_patches = rest;
    }

    // the patch lies on the floor under the impact (a ball that hit a wall pools below it)
    trace = bullettrace( pos + ( 0, 0, 24 ), pos - ( 0, 0, 160 ), 0, undefined );
    pos = trace["position"];
    fire = mg_fx_loop( "patch_fire", pos );

    if ( !isdefined( fire ) )
        return;

    pool = spawn( "script_model", pos + ( 0, 0, 0.3 ) );
    pool setmodel( mg_model( "pool" ) );
    pool.angles = ( 0, randomint( 360 ), 0 );
    fire.mg_pool = pool;
    self.mg_patches[self.mg_patches.size] = fire;
    embers = mg_fx_loop( "embers", pos );
    fire playloopsound( "zmb_fire_loop" );

    // the lure: vanilla's point of interest (the monkey bomb's), switched off with the pool
    big = isdefined( weapon ) && weapon == "magmagat_upgraded_zm";
    lure_dist = 128;
    lure_count = 3;

    if ( big )
    {
        lure_dist = 256;
        lure_count = 6;
    }

    pool create_zombie_point_of_interest( lure_dist, lure_count, 10000 );
    pool thread create_zombie_point_of_interest_attractor_positions( 4, 45 );

    for ( t = 0; t < 5 && isdefined( fire ); t += 0.4 )
    {
        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( !isdefined( ai ) || !isalive( ai ) || distancesquared( ai.origin, pos ) > 64 * 64 || abs( ai.origin[2] - pos[2] ) > 32 )
                continue;

            if ( isdefined( ai.animname ) && ai.animname == "brutus_zombie" )
            {
                ai dodamage( int( ai.maxhealth * 0.016 ), pos, self, self, "none", "MOD_BURNED", 0, weapon );
                continue;
            }

            if ( !is_true( ai.has_legs ) && isdefined( ai.has_legs ) )
            {
                ai dodamage( ai.health + 666, pos, self, self, "none", "MOD_BURNED", 0, weapon );
                continue;
            }

            if ( !is_true( ai.mg_burning ) )
            {
                ai.mg_burning = 1;
                ai dodamage( int( ai.maxhealth * 0.1 ), pos, self, self, "none", "MOD_BURNED", 0, weapon );
                ai thread mg_burn_fx( 3 );
                ai thread mg_burn_clear( 3 );
                self thread mg_pool_burn( ai, weapon );
            }
        }

        // the owner is not immune to his own lava
        if ( isdefined( self ) && is_player_valid( self ) && distancesquared( self.origin, pos ) < 64 * 64 && abs( self.origin[2] - pos[2] ) < 40 )
            self dodamage( 1, pos );

        wait 0.4;
    }

    if ( isdefined( pool ) )
        pool deactivate_zombie_point_of_interest();

    mg_fx_stop( embers );

    if ( isdefined( fire ) )
    {
        mg_patch_stop( fire );
        kept = [];

        foreach ( p in self.mg_patches )
        {
            if ( isdefined( p ) )
                kept[kept.size] = p;
        }

        self.mg_patches = kept;
    }
}

// self = player. A zombie set on fire by a pool burns a share of its health every second for 3 s (BO4 scales it with
// the round: most of it early, a fifth late).
mg_pool_burn( ai, weapon )
{
    ai endon( "death" );
    frac = 0.75;

    if ( level.round_number >= 29 )
        frac = 0.175;
    else if ( level.round_number >= 9 )
        frac = 0.75 - ( level.round_number - 9 ) * ( 0.575 / 20 );

    for ( i = 0; i < 3; i++ )
    {
        wait 1;

        if ( isalive( ai ) )
            ai dodamage( int( ai.maxhealth * frac / 3 ), ai.origin, self, self, "none", "MOD_BURNED", 0, weapon );
    }
}

// A patch goes: its fire and its pool mesh.
mg_patch_stop( fire )
{
    if ( !isdefined( fire ) )
        return;

    if ( isdefined( fire.mg_pool ) )
    {
        // the lure goes with it (vanilla keeps a list of points of interest)
        fire.mg_pool deactivate_zombie_point_of_interest();
        fire.mg_pool delete();
    }

    mg_fx_stop( fire );
}

// self = zombie
mg_burn_clear( seconds )
{
    self endon( "death" );
    wait( seconds );
    self.mg_burning = 0;
}

// self = the craftable trigger vanilla validates (zm_alcatraz_utility blundergat_upgrade_station). Vanilla's own hook
// runs first. At the Acid Gat kit (targetname blundergat_upgrade) a player holding a Magmagat and no Blundergat hands
// it in as the Blundergat of its tier: vanilla then makes the Acid Gat (the Magmus Operandi gives the Vitriolic
// Withering), as BO4's kit does.
mg_acid_station_validation( player )
{
    if ( isdefined( level.mg_prev_craftable_validation ) )
    {
        if ( !( self [[ level.mg_prev_craftable_validation ]]( player ) ) )
            return 0;
    }

    if ( !isdefined( self.targetname ) || self.targetname != "blundergat_upgrade" || !isdefined( player ) )
        return 1;

    magma = mg_has_magma( player );

    if ( !isdefined( magma ) || player hasweapon( "blundergat_zm" ) || player hasweapon( "blundergat_upgraded_zm" ) )
        return 1;

    base = "blundergat_zm";

    if ( magma == "magmagat_upgraded_zm" )
        base = "blundergat_upgraded_zm";

    player takeweapon( magma );
    player giveweapon( base );
    player switchtoweapon( base );
    mg_debug_print( "MG: " + player.name + " hands a " + magma + " to the Acid Gat kit" );
    return 1;
}
