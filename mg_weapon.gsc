#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;

// The Magmagat is its own weapon, magmagat_zm, shipped in our mod.ff (tools/build_weapon.pl: the Blundergat's rig
// and animations, a lava skin); its Pack-a-Punch is magmagat_upgraded_zm, the Magmus Operandi. Each shot also
// launches a lava ball; a zombie that catches it burns 0.6 s and explodes (150 units); a miss leaves an 8 s patch.
// The look lives in the weapon file (tools/build_weapon.pl: lava tanks, fire muzzle flash, red tracers); the script
// adds the flame riding the held gun and the fire whoosh of every shot.
// The Acid Gat kit refuses it by itself: vanilla only takes a blundergat_zm / blundergat_upgraded_zm.

mg_weapon_init()
{
    level.mg_patches = [];
    mg_weapon_register();
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

// The Magmagat a Blundergat becomes at the forge.
mg_magma_of( weapon )
{
    if ( isdefined( weapon ) && weapon == "blundergat_upgraded_zm" )
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

// self = player. The ball sticks to the zombie 0.6 s, then everything within 150 units dies (Brutus burns).
mg_ball_explode( ball, zombie, weapon )
{
    level endon( "end_game" );
    ball linkto( zombie, "J_SpineUpper", ( 0, 0, 0 ), ( 0, 0, 0 ) );
    burn = mg_fx_loop( "burn", zombie.origin + ( 0, 0, 40 ) );

    if ( isdefined( burn ) )
        burn linkto( zombie, "J_SpineUpper", ( 0, 0, 0 ), ( 0, 0, 0 ) );

    wait 0.6;
    pos = ball.origin;

    if ( isdefined( zombie ) )
        pos = zombie.origin + ( 0, 0, 30 );

    ball delete();
    mg_fx_stop( burn );
    mg_fx_once( "explo", pos );
    mg_snd_near( "wpn_blundersplat_explode", pos, 1200 );

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( !isdefined( ai ) || !isalive( ai ) || distancesquared( ai.origin, pos ) > 150 * 150 )
            continue;

        if ( isdefined( ai.animname ) && ai.animname == "brutus_zombie" )
        {
            self mg_brutus_burn( ai, 0.1, pos, "MOD_PROJECTILE_SPLASH", weapon );
            ai thread mg_burn_fx( 3 );
            continue;
        }

        ai dodamage( ai.health + 666, pos, self, self, "none", "MOD_PROJECTILE_SPLASH", 0, weapon );
    }
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

// self = player. Brutus burns but never dies from the Magmagat: the damage is clamped so at least 1 hp remains.
mg_brutus_burn( ai, frac, pos, mod, weapon )
{
    dmg = int( ai.maxhealth * frac );

    if ( dmg >= ai.health )
        dmg = ai.health - 1;

    if ( dmg > 0 )
        ai dodamage( dmg, pos, self, self, "none", mod, 0, weapon );
}

// self = player. A magma patch: 8 s, 60 units, 250 + 30 * round every 0.5 s (Brutus 2 % of his max health).
mg_patch( pos, weapon )
{
    level endon( "end_game" );

    if ( !isdefined( self.mg_patches ) )
        self.mg_patches = [];

    // cap 6 per player, oldest removed first
    if ( self.mg_patches.size >= 6 )
    {
        oldest = self.mg_patches[0];
        mg_fx_stop( oldest );
        rest = [];

        for ( i = 1; i < self.mg_patches.size; i++ )
            rest[rest.size] = self.mg_patches[i];

        self.mg_patches = rest;
    }

    fire = mg_fx_loop( "patch_fire", pos );

    if ( !isdefined( fire ) )
        return;

    self.mg_patches[self.mg_patches.size] = fire;
    embers = mg_fx_loop( "embers", pos );
    mg_snd_near( "zmb_fire_loop", pos, 600 );
    tick = 250 + 30 * level.round_number;

    for ( t = 0; t < 8 && isdefined( fire ); t += 0.5 )
    {
        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( !isdefined( ai ) || !isalive( ai ) || distancesquared( ai.origin, pos ) > 60 * 60 )
                continue;

            if ( isdefined( ai.animname ) && ai.animname == "brutus_zombie" )
            {
                self mg_brutus_burn( ai, 0.02, pos, "MOD_BURNED", weapon );
                continue;
            }

            ai dodamage( tick, pos, self, self, "none", "MOD_BURNED", 0, weapon );

            if ( !is_true( ai.mg_burning ) )
            {
                ai.mg_burning = 1;
                ai thread mg_burn_fx( 1.5 );
                ai thread mg_burn_clear( 1.5 );
            }
        }

        wait 0.5;
    }

    mg_fx_stop( embers );

    if ( isdefined( fire ) )
    {
        mg_fx_stop( fire );
        kept = [];

        foreach ( p in self.mg_patches )
        {
            if ( isdefined( p ) )
                kept[kept.size] = p;
        }

        self.mg_patches = kept;
    }
}

// self = zombie
mg_burn_clear( seconds )
{
    self endon( "death" );
    wait( seconds );
    self.mg_burning = 0;
}
