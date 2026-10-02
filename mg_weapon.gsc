#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;

// The Magmagat is its own weapon, magmagat_zm, shipped in our mod.ff (tools/build_weapon.pl: the Blundergat's rig
// and animations, BO4's Magmagat model on it); its Pack-a-Punch is magmagat_upgraded_zm, the Magmus Operandi. The remaster's
// Magmagat (_zm_weap_magmagat.gsc) is BO2's Acid Gat with fire, and so is ours: each shot fires one lava blob as T6's
// Acid Gat fires its dart (_zm_weap_blundersplat.gsc), a real sticky projectile (mg_magma_bolt_zm, which leaves the
// blob grenade mg_magma_blob_zm where it lands). Then, as the remaster:
// - on a zombie: it burns in the Acid Gat's stun for 1 s and dies, whatever its health; the blob bursts 0.05 s later;
// - on Brutus: 2500 burn damage (his own armour takes 90 % of it), the blob bursts 3 s later;
// - anywhere else: a lava pool for 6 s (a radius of 32, the Magmus 64), the blob lying in it. A zombie in it takes a
//   quarter of its maximum health every 0.25 s; any player in it 20 every 0.5 s. Brutus walks through.
// In all three the blob lures zombies (250 units, 5 of them; the Magmus 500 and 10). Magmagat damage pays no points per
// hit (the kill still does). The Acid Gat kit takes the Magmagat as the Blundergat it was and makes the Acid Gat.

mg_weapon_init()
{
    level.mg_pools = [];
    level.mg_ignite_end = 0;
    level.mg_burn_fx_count = 0;
    mg_weapon_register();
    maps\mp\zombies\_zm_spawner::register_zombie_damage_callback( ::mg_magma_damage_callback );
    // chained, not replaced: vanilla _zm_ai_brutus.gsc installs its own hook on this map (a Brutus-locked table)
    level.mg_prev_craftable_validation = level.custom_craftable_validation;
    level.custom_craftable_validation = ::mg_acid_station_validation;
    level thread mg_weapon_connect_watch();
    level thread mg_pool_damage_loop();
}

// init() only (precacheitem). The script fires the bolt (magicbullet) and the bolt leaves the blob: both are precached,
// as vanilla precaches the Acid Gat's dart and grenade.
mg_weapon_precache()
{
    precacheitem( "magmagat_zm" );
    precacheitem( "magmagat_upgraded_zm" );
    precacheitem( "mg_magma_bolt_zm" );
    precacheitem( "mg_magma_blob_zm" );
    precacheitem( "mg_tempered_zm" );
    precacheitem( "mg_tempered_upgraded_zm" );
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

    // the tempered guns: known to vanilla's weapon code, out of the box, never Pack-a-Punched
    foreach ( name in array( "mg_tempered_zm", "mg_tempered_upgraded_zm" ) )
    {
        t = spawnstruct();
        t.weapon_name = name;
        t.weapon_classname = "weapon_" + name;
        t.is_in_box = 0;

        if ( isdefined( base ) )
        {
            t.hint = base.hint;
            t.cost = base.cost;
            t.vox = base.vox;
            t.vox_response = base.vox_response;
            t.ammo_cost = base.ammo_cost;
        }

        level.zombie_weapons[name] = t;
        level.zombie_include_weapons[name] = 0;
    }
}

// The tempered gun the fireplace hands back for a Blundergat of this tier (BO4's model, its canisters burning blue).
mg_tempered_of( weapon )
{
    if ( isdefined( weapon ) && ( weapon == "blundergat_upgraded_zm" || weapon == "blundersplat_upgraded_zm" ) )
        return "mg_tempered_upgraded_zm";

    return "mg_tempered_zm";
}

mg_is_tempered( weapon )
{
    return isdefined( weapon ) && ( weapon == "mg_tempered_zm" || weapon == "mg_tempered_upgraded_zm" );
}

// self = player. A tempered gun held outside its run (the temper spent while the player was down, a fabricated
// state) turns back into the gun it was.
mg_tempered_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    while ( true )
    {
        wait 1;

        if ( !is_player_valid( self ) || ( mg_state_is( "run" ) && isdefined( level.mg_carrier ) && level.mg_carrier == self ) )
            continue;

        foreach ( w in array( "mg_tempered_zm", "mg_tempered_upgraded_zm" ) )
        {
            if ( self hasweapon( w ) )
                self mg_tempered_give_back( w );
        }
    }
}

// self = player. The tempered gun back to the Blundergat it was (BO4: the original gun returns when the temper ends).
mg_tempered_give_back( tempered )
{
    original = self.mg_tempered_from;

    // without a record of the gun placed (or a record of another tier), the tier the tempered gun carries
    if ( !isdefined( original ) || mg_tempered_of( original ) != tempered )
    {
        original = "blundergat_zm";

        if ( tempered == "mg_tempered_upgraded_zm" )
            original = "blundergat_upgraded_zm";
    }

    held = self getcurrentweapon() == tempered;
    self takeweapon( tempered );

    if ( !self hasweapon( original ) )
        self giveweapon( original );

    if ( held )
        self thread mg_switch_to( original );

    self.mg_tempered_from = undefined;
}

// The Magmagat a gun becomes at the forge: a Pack-a-Punched one (Sweeper, Vitriolic Withering) gives the Magmus
// Operandi.
mg_magma_of( weapon )
{
    if ( isdefined( weapon ) && ( weapon == "blundergat_upgraded_zm" || weapon == "blundersplat_upgraded_zm" || weapon == "mg_tempered_upgraded_zm" ) )
        return "magmagat_upgraded_zm";

    return "magmagat_zm";
}

mg_is_magma( weapon )
{
    return isdefined( weapon ) && ( weapon == "magmagat_zm" || weapon == "magmagat_upgraded_zm" );
}

// The Magmagat, its bolt in flight or its blob bursting: the weapons whose damage is the Magmagat's.
mg_is_magma_damage( weapon )
{
    return mg_is_magma( weapon ) || isdefined( weapon ) && ( weapon == "mg_magma_bolt_zm" || weapon == "mg_magma_blob_zm" );
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

// self = player. Swaps the held Blundergat (or, at two primaries, the gun in hand) for its Magmagat. A player who
// already owns a Magmagat only has its ammo refilled (the remaster's forge: function_704b802a, giveMaxAmmo), unless a
// Pack-a-Punched gun was pressed while he owns the plain one: that one becomes the Magmus Operandi, never the reverse.
mg_weapon_grant( weapon )
{
    owned = mg_has_magma( self );
    magma = mg_magma_of( weapon );

    if ( isdefined( owned ) && !( owned == "magmagat_zm" && magma == "magmagat_upgraded_zm" ) )
    {
        self givemaxammo( owned );
        mg_debug_print( "MG: " + self.name + " refills his " + owned );
        return;
    }

    if ( isdefined( owned ) )
        self takeweapon( owned );

    if ( isdefined( weapon ) && self hasweapon( weapon ) )
        self takeweapon( weapon );

    self mg_give_weapon( magma );
    self givemaxammo( magma );
    mg_debug_print( "MG: " + self.name + " holds a " + magma );
}

mg_weapon_connect_watch()
{
    level endon( "end_game" );

    foreach ( player in getplayers() )
    {
        player thread mg_weapon_shot_loop();
        player thread mg_tempered_watch();
    }

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread mg_weapon_shot_loop();
        player thread mg_tempered_watch();
    }
}

// self = player
mg_weapon_shot_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( is_true( self.mg_weapon_watched ) )
        return;

    self.mg_weapon_watched = 1;

    while ( true )
    {
        self waittill( "weapon_fired", weapon );

        if ( mg_is_magma( weapon ) )
            self thread mg_blob_fire( weapon );    // its own thread: one error must not end this player's loop
    }
}

// self = player. One blob per shot, fired from the eye to where the crosshair points, as the Acid Gat fires its dart
// (_zm_weap_blundersplat.gsc _titus_locate_target; one blob and no aim help, as the remaster's single grenade).
mg_blob_fire( weapon )
{
    origin = self getplayercamerapos();
    trace = bullettrace( origin, origin + anglestoforward( self getplayerangles() ) * 20000, 1, self );
    bolt = magicbullet( "mg_magma_bolt_zm", origin, trace["position"], self );

    if ( isdefined( bolt ) )
        level thread mg_blob_land( bolt, self, weapon, origin, bolt mg_blob_flight_fire() );
}

// self = a bolt in flight. A small fire rides it, over Harry's trail, on a carrier linked to it (the blob's model has
// no tag the effect could take); mg_blob_land puts it out where the bolt lands.
mg_blob_flight_fire()
{
    fire = spawn( "script_model", self.origin );
    fire setmodel( "tag_origin" );
    fire linkto( self );
    fire thread mg_blob_flight_fire_play();
    return fire;
}

// self = the flight fire's carrier: lit a frame after its spawn (an effect played in the frame an entity appears is
// dropped by the clients)
mg_blob_flight_fire_play()
{
    self endon( "death" );
    wait 0.05;
    mg_fx_add( self, "blob_fire" );
}

// The bolt lands and leaves its blob (the grenade tools/build_weapon.pl gives it, stuck where it hit); the blob
// then takes one of the remaster's three ways (_zm_weap_magmagat.gsc function_24eea6c5). player may leave meanwhile.
mg_blob_land( bolt, player, weapon, from, fire )
{
    level endon( "end_game" );
    last = bolt.origin;
    blob = undefined;

    // landed as soon as its blob appears beside it: a stuck bolt lingers a while before it goes, and waiting for it
    // held the pool's fire back (it goes unseen, the blob's copy shows from now)
    while ( isdefined( bolt ) )
    {
        last = bolt.origin;
        blob = mg_blob_find( last, 64 );

        if ( isdefined( blob ) )
        {
            bolt hide();
            break;
        }

        wait 0.05;
    }

    mg_fx_stop( fire );

    for ( i = 0; i < 3 && !isdefined( blob ); i++ )
    {
        blob = mg_blob_find( last );

        if ( !isdefined( blob ) )
            wait 0.05;
    }

    // a bolt that hit nothing and timed out leaves no blob
    if ( !isdefined( blob ) )
        return;

    blob.mg_claimed = 1;
    blob.mg_owner = player;
    blob.mg_weapon = weapon;
    host = mg_blob_host( blob );

    // stuck to something that moves but is no living zombie (a teammate, a corpse, the gondola): no pool could follow
    // it, so it bursts at once. A blob on the map itself reports the world as what it is linked to: that one pools.
    linked = blob getlinkedent();

    if ( !isdefined( host ) && isdefined( linked ) && ( isplayer( linked ) || isai( linked ) || linked.classname == "script_brushmodel" ) )
    {
        blob mg_blob_burst();
        return;
    }

    // the grenade itself is invisible (tools/build_weapon.pl): a copy of the blob shows it. On a surface it stands out
    // of it, a wall or a ceiling as the floor, its pool with it (T6 keeps a stuck grenade as it flew); on a zombie or
    // Brutus it rides the grenade.
    if ( !isdefined( host ) )
    {
        shown = blob mg_blob_show( mg_up_angles( mg_blob_normal( from, blob ) ), 0 );
        blob mg_blob_lure( weapon );
        level thread mg_pool( blob, player, weapon, shown );
    }
    else if ( mg_is_brutus( host ) )
    {
        blob mg_blob_show( blob.angles, 1 );
        blob thread mg_blob_on_brutus( host, player, weapon );
    }
    else
    {
        blob mg_blob_show( blob.angles, 1 );
        blob thread mg_blob_on_zombie( host, player );

        // a second blob on the same zombie only bursts with it
        if ( !is_true( host.mg_magma_stuck ) )
            host thread mg_magma_stuck( player, weapon );
    }
}

// self = a blob grenade. Its visible copy, turned to angles, riding it when ride is set; gone with the grenade.
mg_blob_show( angles, ride )
{
    shown = spawn( "script_model", self.origin );
    shown.angles = angles;
    shown setmodel( mg_model( "ball" ) );

    if ( ride )
        shown linkto( self );

    shown thread mg_blob_show_end( self );
    return shown;
}

// self = a blob's copy: it goes when its grenade does (a burst, the pool's end)
mg_blob_show_end( blob )
{
    self endon( "death" );
    blob waittill( "death" );
    self delete();
}

// The normal of the surface the blob stuck to, traced along the shot through it (straight up when nothing is found;
// the bolt's own last positions are often one and the same, which gave no direction).
mg_blob_normal( from, blob )
{
    dir = vectornormalize( blob.origin - from );
    trace = bullettrace( blob.origin - dir * 24, blob.origin + dir * 24, 0, blob );

    if ( trace["fraction"] >= 1 )
        return ( 0, 0, 1 );

    return trace["normal"];
}

// Angles that stand a model's up axis along n (pitch 90 more than n's own: forward to n, then up to it).
mg_up_angles( n )
{
    a = vectortoangles( n );
    return ( a[0] + 90, a[1], 0 );
}

// The unclaimed blob nearest to where its bolt was last seen (a grenade entity with the blob's model) within reach
// (300 units unless given), or undefined.
mg_blob_find( pos, reach )
{
    if ( !isdefined( reach ) )
        reach = 300;

    best = undefined;
    best_d = reach * reach;

    foreach ( g in getentarray( "grenade", "classname" ) )
    {
        if ( !isdefined( g.model ) || g.model != mg_model( "blob_grenade" ) || is_true( g.mg_claimed ) )
            continue;

        d = distancesquared( g.origin, pos );

        if ( d < best_d )
        {
            best = g;
            best_d = d;
        }
    }

    return best;
}

// The living zombie (or Brutus) this blob is stuck to, or undefined.
mg_blob_host( blob )
{
    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && blob islinkedto( ai ) )
            return ai;
    }

    // T6's projectile can pass through a moving zombie and land behind it: a blob ending inside a zombie's body (20
    // units from its axis, between its feet and its head; Brutus 40 and 110) sticks to it
    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( !isdefined( ai ) || !isalive( ai ) )
            continue;

        reach = 20;
        top = 72;

        if ( mg_is_brutus( ai ) )
        {
            reach = 40;
            top = 110;
        }

        if ( distance2dsquared( ai.origin, blob.origin ) > reach * reach )
            continue;

        dz = blob.origin[2] - ai.origin[2];

        // above its shins: a blob on the floor at its feet is a miss
        if ( dz >= 12 && dz <= top )
        {
            blob linkto( ai );
            return ai;
        }
    }

    return undefined;
}

mg_is_brutus( ai )
{
    return isdefined( ai.animname ) && ai.animname == "brutus_zombie";
}

// self = blob. The lure, vanilla's point of interest (the Acid Gat's own numbers, which the remaster keeps), on a blob
// on the floor or a wall only: as BO4's, one stuck on a zombie or on Brutus draws no one (the remaster's does).
mg_blob_lure( weapon )
{
    if ( weapon == "magmagat_upgraded_zm" )
        self create_zombie_point_of_interest( 500, 10, 10000 );
    else
        self create_zombie_point_of_interest( 250, 5, 10000 );
}

// self = zombie the blob stuck to (the remaster's function_876c11c9, BO2's _titus_target_animate_and_die): it burns in
// the Acid Gat's stun for 1 s, then dies whatever its health. The notify feeds the spoon in the showers, as the
// remaster's killed_by_a_magmagat does.
mg_magma_stuck( player, weapon )
{
    self endon( "death" );
    self.mg_magma_stuck = 1;
    self thread maps\mp\zombies\_zm_weap_blundersplat::_blundersplat_target_acid_stun_anim();
    self mg_burn_start();
    wait 1;
    self notify( "killed_by_a_blundersplat", player );
    mg_magma_dodamage( self, self.health + 666, self.origin, player, "MOD_BURNED", weapon );
}

// self = blob on a zombie: it bursts 0.05 s after the zombie dies (BO2's _titus_grenade_detonate_on_target_death).
mg_blob_on_zombie( zombie, player )
{
    self endon( "death" );

    if ( isalive( zombie ) )
        zombie waittill( "death" );

    // as BO4's: the zombie the blob burnt bursts with it (vanilla's own gore, _zm_spawner)
    if ( isdefined( zombie ) )
        zombie thread maps\mp\zombies\_zm_spawner::zombie_gut_explosion();

    self mg_blob_burst();
}

// self = blob on Brutus: 2500 burn damage once (vanilla brutus_damage_override keeps a tenth, half more for this
// spread-class gun, as BO3's does), and the blob bursts 3 s later.
mg_blob_on_brutus( brutus, player, weapon )
{
    self endon( "death" );
    mg_magma_dodamage( brutus, 2500, brutus.origin, player, "MOD_BURNED", weapon );
    wait 3;
    self mg_blob_burst();
}

// self = blob. It bursts 0.05 s from now: the weapon's own explosion (the remaster's 20 over 300 units,
// tools/build_weapon.pl) through resetmissiledetonationtime, as the remaster and BO2 do; it sets the zombies around it
// alight (mg_blob_ignite) and burns the players near it. Its look and sound are played here: Harry's explosion, with
// Tranzit's lava zombie bursting in fire and smoke over it (the owner's), and the remaster's own explosion sound, the
// Acid Gat's (a projExplosionSound of the mod's own bank stayed silent).
mg_blob_burst()
{
    pos = self.origin;

    if ( isdefined( self.script_noteworthy ) )
        self deactivate_zombie_point_of_interest();

    self resetmissiledetonationtime( 0.05 );
    mg_fx_once( "explo", pos );
    mg_fx_once( "burst_fire", pos );
    playsoundatposition( "wpn_blundersplat_explode", pos );
    mg_blob_ignite( pos, self.mg_owner, self.mg_weapon );
    level thread mg_blob_burn_players( pos, mg_pool_radius( self.mg_weapon ) * 2 );
    self thread mg_blob_burst_fallback();
}

// The burst sets the zombies around it alight, as BO4's (the remaster's does not): within 150 units, they burn as in a
// pool for 2 s, long enough to die of it, credited to the blob's owner. Brutus only takes the burst.
mg_blob_ignite( pos, owner, weapon )
{
    fire = spawnstruct();
    fire.origin = pos;
    fire.owner = owner;
    fire.weapon = weapon;
    fire.mg_until = gettime() + 2000;
    level.mg_ignite_end = fire.mg_until;

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && isalive( ai ) && !mg_is_brutus( ai ) && distancesquared( ai.origin, pos ) < 150 * 150 )
            ai.mg_ignited = fire;
    }
}

// self = a bursting blob. A grenade stuck to Brutus may never go off: still here 0.3 s on, the script bursts it with
// the weapon's own numbers (20 over 300 units).
mg_blob_burst_fallback()
{
    self endon( "death" );
    wait 0.3;

    if ( isdefined( self.mg_owner ) )
        radiusdamage( self.origin, 300, 20, 20, self.mg_owner, "MOD_GRENADE_SPLASH", "mg_magma_blob_zm" );
    else
        radiusdamage( self.origin, 300, 20, 20 );

    self delete();
}

// The burst burns the players near it too, the shooter as his teammates, as BO3's does (vanilla zombies spares a
// teammate's explosive and caps one's own): within reach, the width of the pool's fire (the zombies take the
// weapon's own 300 units), the remaster's 20, and on fire. PhD Flopper takes nothing, as from any
// explosion.
mg_blob_burn_players( pos, reach )
{
    wait 0.05;

    foreach ( player in getplayers() )
    {
        if ( !is_player_valid( player ) || player hasperk( "specialty_flakjacket" ) )
            continue;

        d = distance( player.origin, pos );

        if ( d > reach )
            continue;

        player setburn( 1 );
        player dodamage( 20, pos );
    }
}

// Magmagat damage, credited to its player while he is still here.
mg_magma_dodamage( victim, amount, pos, player, mod, weapon )
{
    if ( isdefined( player ) )
        victim dodamage( amount, pos, player, player, "none", mod, 0, weapon );
    else
        victim dodamage( amount, pos );
}

// self = zombie (vanilla _zm_spawner::zombie_damage). Magmagat damage pays no points per hit and skips vanilla's
// flame and grenade handling, as the remaster's function_93036c27; the kill still pays.
mg_magma_damage_callback( mod, hit_location, hit_origin, player, amount )
{
    return mg_is_magma_damage( self.damageweapon );
}

// The lava pool (the remaster's trigger magmagat_lava_pool): a trigger of radius 32 (the Magmus 64) and 32 high at
// the blob, wherever it stuck, 6 s, and its fire played the blob's way up (the remaster plays it on the blob). No
// cap as in the remaster, but 8 at once at most for T6's entity budget (the oldest goes).
mg_pool( blob, player, weapon, shown )
{
    level endon( "end_game" );
    radius = mg_pool_radius( weapon );
    pos = blob.origin;
    pool = spawn( "trigger_radius", pos, 0, radius, 32 );
    pool.owner = player;
    pool.weapon = weapon;

    fire = mg_fx_loop( "patch_fire", pool.origin, shown.angles );

    // counted once its fire is up: the oldest may still be in that wait and miss the notify
    if ( level.mg_pools.size >= 8 )
        level.mg_pools[0] notify( "mg_pool_end" );

    level.mg_pools[level.mg_pools.size] = pool;
    pool waittill_any_timeout( 6, "mg_pool_end" );
    arrayremovevalue( level.mg_pools, pool );
    pool delete();
    mg_fx_stop( fire );

    if ( isdefined( shown ) )
        shown delete();

    if ( isdefined( blob ) )
    {
        blob deactivate_zombie_point_of_interest();
        blob delete();
    }
}

// The pool trigger's radius for weapon: 32, the Magmus 64
mg_pool_radius( weapon )
{
    if ( isdefined( weapon ) && weapon == "magmagat_upgraded_zm" )
        return 64;

    return 32;
}

// The pool this entity (a zombie, a player) touches, or undefined: the remaster's own test on both (istouching).
mg_pool_touched( ent )
{
    foreach ( pool in level.mg_pools )
    {
        // 128 covers the Magmus radius and a body's width before the exact test
        if ( isdefined( pool ) && distancesquared( ent.origin, pool.origin ) < 128 * 128 && ent istouching( pool ) )
            return pool;
    }

    return undefined;
}

// Every 0.05 s, as the remaster's checks (function_8879b47f on zombies, function_a7de247a on players).
mg_pool_damage_loop()
{
    level endon( "end_game" );

    was_active = 0;

    while ( true )
    {
        wait 0.05;

        // no pool nor zombie set alight: one last pass lets whoever stood in one step out (sound off, burn fading),
        // then nothing
        active = level.mg_pools.size > 0 || gettime() < level.mg_ignite_end;

        if ( !active && !was_active )
            continue;

        was_active = active;

        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( isdefined( ai ) && isalive( ai ) && !mg_is_brutus( ai ) )
                ai mg_pool_zombie();
        }

        foreach ( player in getplayers() )
            player mg_pool_player();
    }
}

// self = zombie. In the pool (the remaster's function_8879b47f: the pool does the damage, the flames on the body only
// show it), or set alight by a blob's burst (mg_blob_ignite): a quarter of its maximum health every 0.25 s (dead in
// about 0.75 s), credited to the pool's or the blob's owner, and it burns; out of it, the burn fades (mg_burn_end). It
// counts as on fire, as vanilla's burning zombies: one killed by the Magmus (an upgraded shotgun to vanilla) or by a
// blob's burst meanwhile falls dead instead of bursting in gore (_zm_spawner zombie_death_event), as in BO3 and BO4.
mg_pool_zombie()
{
    pool = mg_pool_touched( self );

    // set alight: it burns as in a pool, wherever it walks
    if ( !isdefined( pool ) && isdefined( self.mg_ignited ) && gettime() < self.mg_ignited.mg_until )
        pool = self.mg_ignited;

    if ( !isdefined( pool ) )
    {
        if ( is_true( self.mg_in_pool ) )
        {
            self.mg_in_pool = undefined;
            self thread mg_burn_end( 4 );
        }

        return;
    }

    self.mg_in_pool = 1;

    if ( isdefined( self.mg_pool_next ) && gettime() < self.mg_pool_next )
        return;

    self.mg_pool_next = gettime() + 250;
    self.is_on_fire = 1;
    self mg_burn_start();
    mg_magma_dodamage( self, int( self.maxhealth / 4 ), pool.origin, pool.owner, "MOD_BURNED", pool.weapon );
}

// self = player. Every player standing in a pool (not only its owner) takes 20 every 0.5 s with the searing loop
// (T6's evt_plr_fire_loop for the remaster's evt_searing_flesh).
mg_pool_player()
{
    pool = undefined;

    if ( is_player_valid( self ) )
        pool = mg_pool_touched( self );

    if ( !isdefined( pool ) )
    {
        if ( is_true( self.mg_in_pool ) )
        {
            self.mg_in_pool = undefined;
            self stoploopsound( 2 );
        }

        return;
    }

    if ( !is_true( self.mg_in_pool ) )
    {
        self.mg_in_pool = 1;
        self playloopsound( "evt_plr_fire_loop", 1 );
    }

    if ( isdefined( self.mg_pool_next ) && gettime() < self.mg_pool_next )
        return;

    self.mg_pool_next = gettime() + 500;
    self setburn( 1 );    // on fire, screen and body, as vanilla's fire trap (the remaster's burnplayer)
    self dodamage( 20, pool.origin );
}

// self = zombie. It burns: T6's fire loop (for the remaster's chr_burning_loop) and its flames, on 12 zombies at most
// for T6's effect budget.
mg_burn_start()
{
    self notify( "mg_burn_restart" );

    if ( !is_true( self.mg_burn_watched ) )
    {
        self.mg_burn_watched = 1;
        self thread mg_burn_death();
    }

    if ( !is_true( self.mg_burn_loop ) )
    {
        self.mg_burn_loop = 1;
        self playloopsound( "zmb_fire_loop", 1 );
    }

    if ( is_true( self.mg_burn_lit ) || level.mg_burn_fx_count >= 12 )
        return;

    self.mg_burn_lit = 1;
    level.mg_burn_fx_count++;
    self thread mg_burn_fx();
}

// self = zombie. Its flames, laid out as vanilla's flame_death_fx lays a burning body's (zm_death): Mob's torso fire up
// and down the spine and a small fire on an arm and a leg, until mg_burn_end, or 2 s after its death as it lies there.
mg_burn_fx()
{
    tags = array( "J_SpineUpper", "J_SpineLower", random( array( "J_Elbow_LE", "J_Elbow_RI" ) ), random( array( "J_Knee_LE", "J_Knee_RI" ) ) );
    keys = array( "burn", "burn", "blob_fire", "blob_fire" );
    fx = [];

    for ( i = 0; i < tags.size; i++ )
    {
        ent = spawn( "script_model", self gettagorigin( tags[i] ) );
        ent setmodel( "tag_origin" );
        ent linkto( self, tags[i], ( 0, 0, 0 ), ( 0, 0, 0 ) );
        fx[i] = ent;
    }

    wait 0.05;    // an effect played in the frame its entity appears is dropped by the clients

    if ( isdefined( self ) && isalive( self ) )
    {
        for ( i = 0; i < fx.size; i++ )
            mg_fx_add( fx[i], keys[i] );

        // vanilla deletes far zombies without a death
        if ( self waittill_any_return( "death", "mg_burn_fx_off", "zombie_delete" ) == "death" )
            wait 2;
    }

    foreach ( ent in fx )
        mg_fx_stop( ent );

    level.mg_burn_fx_count--;

    if ( isdefined( self ) )
        self.mg_burn_lit = undefined;
}

// self = zombie out of the pool (the remaster's function_7a018272): the fire loop fades now, the flame 4 s later,
// unless it steps back in.
mg_burn_end( delay )
{
    self endon( "death" );
    self endon( "mg_burn_restart" );
    self stoploopsound( 2 );
    self.mg_burn_loop = undefined;
    wait( delay );
    self.is_on_fire = 0;
    self notify( "mg_burn_fx_off" );
}

// self = zombie. Its fire loop stops with it.
mg_burn_death()
{
    self waittill( "death" );

    if ( isdefined( self ) )
        self stoploopsound( 1 );
}

// self = the craftable trigger vanilla validates (zm_alcatraz_utility blundergat_upgrade_station). Vanilla's own hook
// runs first. At the Acid Gat kit (targetname blundergat_upgrade) a player holding a Magmagat and no Blundergat hands
// it in as the Blundergat of its tier: vanilla then makes the Acid Gat (the Magmus Operandi gives the Vitriolic
// Withering), as the remaster's kit does.
mg_acid_station_validation( player )
{
    if ( isdefined( level.mg_prev_craftable_validation ) )
    {
        if ( !( self [[ level.mg_prev_craftable_validation ]]( player ) ) )
            return 0;
    }

    if ( !isdefined( self.targetname ) || self.targetname != "blundergat_upgrade" || !isdefined( player ) )
        return 1;

    // vanilla asks again at every press of the pickup (wait_for_player_to_take): the gun inserted is gone by then, so
    // a Magmagat held beside it would be taken too
    if ( is_true( player.is_pack_splatting ) )
        return 1;

    magma = mg_has_magma( player );

    // a Blundergat beside it goes in instead (vanilla's pick); with an Acid Gat already, vanilla would only refill it and
    // the Magmagat would be lost: it stays
    if ( !isdefined( magma ) || player hasweapon( "blundergat_zm" ) || player hasweapon( "blundergat_upgraded_zm" ) )
        return 1;

    if ( player hasweapon( "blundersplat_zm" ) || player hasweapon( "blundersplat_upgraded_zm" ) )
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
