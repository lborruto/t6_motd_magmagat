#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;

// The Magmagat is its own weapon, magmagat_zm, shipped in our mod.ff (tools/build_weapon.pl: the Blundergat's rig
// and animations, BO4's Magmagat model on it); its Pack-a-Punch is magmagat_upgraded_zm, the Magmus Operandi. The remaster's
// Magmagat (_zm_weap_magmagat.gsc) is BO2's Acid Gat with fire, and so is ours: each shot fires one lava blob as T6's
// Acid Gat fires its dart (_zm_weap_blundersplat.gsc), a real sticky projectile: the blob grenade mg_magma_blob_zm,
// lobbed so that gravity brings it down as the remaster's. Then as BO4's own (zm_weap_blundergat.gsc, the Magmagat's
// script there; the Magmus differs only by its lure):
// - on a zombie: 0.5 s on it bursts in gore (1000 health or less) or burns, slowed, 4 s and dies; when it dies the
//   blob bursts: the zombies within 128 catch fire and take 400;
// - on Brutus: 100, then 5 s of burning, and the blob goes;
// - anywhere else: a lava pool for 5 s (radius 64, 32 high; 2 at once), the blob lying in it, luring 3 zombies over
//   128 units (the Magmus 6 over 256) when the floor is near. A zombie touching it catches fire; its owner takes 1
//   every 0.4 s.
// A burning zombie takes a share of its maximum health each second for up to 12 s. Magmagat damage pays no points per
// hit (the kill still does). The Acid Gat kit takes the Magmagat as the Blundergat it was and makes the Acid Gat.

mg_weapon_init()
{
    level.mg_pools = [];
    level.mg_burn_fx_count = 0;
    mg_weapon_register();
    maps\mp\zombies\_zm_spawner::register_zombie_damage_callback( ::mg_magma_damage_callback );
    // chained, not replaced: vanilla _zm_ai_brutus.gsc installs its own hook on this map (a Brutus-locked table)
    level.mg_prev_craftable_validation = level.custom_craftable_validation;
    level.custom_craftable_validation = ::mg_acid_station_validation;
    level thread mg_weapon_connect_watch();
    level thread mg_pool_damage_loop();
}

// init() only (precacheitem). The script lobs the blob grenade (magicgrenadetype): it is precached, as vanilla
// precaches the Acid Gat's dart and grenade.
mg_weapon_precache()
{
    precacheitem( "magmagat_zm" );
    precacheitem( "magmagat_upgraded_zm" );
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

// The Magmagat or its blob bursting: the weapons whose damage is the Magmagat's.
mg_is_magma_damage( weapon )
{
    return mg_is_magma( weapon ) || isdefined( weapon ) && weapon == "mg_magma_blob_zm";
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

// self = player. One blob per shot, lobbed from the eye along the crosshair (one blob and no aim help, as the
// remaster's single grenade): T6's projectile weapons fly straight, a grenade falls, so the blob is the grenade itself.
mg_blob_fire( weapon )
{
    self mg_blob_launch( self getplayercamerapos(), anglestoforward( self getplayerangles() ), weapon );
}

// self = player. The blob lobbed from origin along dir: mg_blob_speed forward and mg_blob_up upward (units per second,
// dvars to tune its arc in game; 1500 and 150 unless set), 20 units out so it clears its shooter.
mg_blob_launch( origin, dir, weapon )
{
    speed = getdvarint( "mg_blob_speed" );
    up = getdvarint( "mg_blob_up" );

    if ( speed <= 0 )
        speed = 1500;

    if ( getdvar( "mg_blob_up" ) == "" )
        up = 150;

    start = origin + dir * 20;
    blob = self magicgrenadetype( "mg_magma_blob_zm", start, dir * speed + ( 0, 0, up ), 10 );

    if ( isdefined( blob ) )
        level thread mg_blob_land( blob, self, weapon, blob mg_blob_flight_fire() );
}

// self = a blob in flight. A small fire rides it, over Harry's trail, on a carrier linked to it (the blob's model has
// no tag the effect could take); mg_blob_land puts it out where the blob lands.
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

// The blob lands where it sticks (a sticky grenade stops dead, or rides what it hit), then goes one of BO4's ways
// (zm_weap_blundergat.gsc function_482c54d5): on a zombie, on Brutus, or a lava pool on a surface. player may leave
// meanwhile.
mg_blob_land( blob, player, weapon, fire )
{
    level endon( "end_game" );
    prev = blob.origin;
    dir = ( 0, 0, -1 );

    while ( true )
    {
        wait 0.05;

        // one that hit nothing went off at the end of its fuse
        if ( !isdefined( blob ) )
        {
            mg_fx_stop( fire );
            return;
        }

        moved = blob.origin - prev;

        if ( isdefined( blob getlinkedent() ) || lengthsquared( moved ) < 1 )
            break;

        dir = vectornormalize( moved );
        prev = blob.origin;
    }

    // its own model flew it; from now a copy shows it, turned to what it stuck to (mg_blob_show)
    blob hide();
    mg_fx_stop( fire );
    mg_fx_once( "impact", blob.origin, undefined, mg_up_angles( mg_blob_normal( dir, blob ) ) );    // turned to the surface, as the pool
    blob.mg_owner = player;
    blob.mg_weapon = weapon;
    host = mg_blob_host( blob );

    // stuck to a teammate, it drops to the floor under him and pools there, as BO4's (function_482c54d5); stuck to
    // something else that moves but is no living zombie (a corpse, the gondola), no pool could follow it, so it goes at
    // once. A blob on the map itself reports the world as what it is linked to: that one pools.
    linked = blob getlinkedent();

    if ( !isdefined( host ) && isdefined( linked ) && isplayer( linked ) )
    {
        floor = bullettrace( linked.origin + ( 0, 0, 40 ), linked.origin - ( 0, 0, 1000 ), 0, linked );
        blob unlink();
        blob.origin = floor["position"];
        dir = ( 0, 0, -1 );
    }
    else if ( !isdefined( host ) && isdefined( linked ) && ( isai( linked ) || linked.classname == "script_brushmodel" ) )
    {
        blob delete();
        return;
    }

    // the grenade is hidden: a copy of the blob shows it. On a surface it stands out of it, a wall or a ceiling as the
    // floor, its pool with it (T6 keeps a stuck grenade as it flew); on a zombie or Brutus it rides the grenade.
    if ( !isdefined( host ) )
    {
        shown = blob mg_blob_show( mg_up_angles( mg_blob_normal( dir, blob ) ), 0 );
        level thread mg_pool( blob, player, weapon, shown );
    }
    else if ( mg_is_boss( host ) )
    {
        blob mg_blob_show( blob.angles, 1 );
        blob thread mg_blob_on_brutus( host, player, weapon );
    }
    else
    {
        blob mg_blob_show( blob.angles, 1 );
        blob thread mg_blob_on_zombie( host, player, weapon );

        // a second blob on the same zombie only goes with it
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

// The normal of the surface the blob stuck to, traced along its last flight direction through it (straight up when
// nothing is found).
mg_blob_normal( dir, blob )
{
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

// BO4 sorts its enemies (var_6f84b820): "basic" / "enhanced" zombies, "popcorn" fodder, "miniboss" / "boss". BO2's
// plain zombies are "zombie" (vanilla zombie_spawn_init); its fodder the dogs, Die Rise's leapers and Tranzit's
// denizens; every other enemy (Brutus on this map) a boss.
mg_is_popcorn( ai )
{
    return isdefined( ai.animname ) && ( ai.animname == "zombie_dog" || ai.animname == "leaper_zombie" || ai.animname == "screecher_zombie" );
}

mg_is_boss( ai )
{
    return isdefined( ai.animname ) && ai.animname != "zombie" && !mg_is_popcorn( ai );
}

// The lure of a pool, BO4's (function_7b25328b): vanilla's point of interest on the floor under the blob, 128 units
// and 3 zombies (the Magmus 256 and 6), only when that floor is within 64 of the blob (a blob up a wall or on a
// ceiling draws no one); Brutus ignores it. Returns its entity, or undefined.
mg_blob_lure( blob, weapon )
{
    trace = bullettrace( blob.origin, blob.origin - ( 0, 0, 1000 ), 0, blob );

    if ( trace["fraction"] >= 1 || distance( trace["position"], blob.origin ) > 64 )
        return undefined;

    lure = spawn( "script_origin", trace["position"] );

    if ( weapon == "magmagat_upgraded_zm" )
        lure create_zombie_point_of_interest( 256, 6, 10000 );
    else
        lure create_zombie_point_of_interest( 128, 3, 10000 );

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( isdefined( ai ) && mg_is_boss( ai ) )
            ai thread add_poi_to_ignore_list( lure );
    }

    return lure;
}

// self = zombie the blob stuck to (BO4's function_dc3470c5): 0.5 s on, one of 1000 health or less bursts in gore and
// dies; a tougher one catches fire for 1000, is slowed 4 s (function_7f95d262), then dies whatever its health. The
// notify feeds the spoon in the showers, as the remaster's killed_by_a_magmagat does.
mg_magma_stuck( player, weapon )
{
    self endon( "death" );
    self.mg_magma_stuck = 1;
    wait 0.5;
    self notify( "killed_by_a_blundersplat", player );

    // fodder: killed outright, no gore (BO4's popcorn)
    if ( mg_is_popcorn( self ) )
    {
        mg_magma_dodamage( self, self.health + 100, self.origin, player, "MOD_BURNED", weapon );
        return;
    }

    if ( self.health <= 1000 )
    {
        self thread maps\mp\zombies\_zm_spawner::zombie_gut_explosion();
        mg_magma_dodamage( self, self.health + 100, self.origin, player, "MOD_BURNED", weapon );
        return;
    }

    self mg_zombie_ignite( player, weapon, 1000 );
    self set_zombie_run_cycle( "walk" );
    wait 4;
    mg_magma_dodamage( self, self.health + 100, self.origin, player, "MOD_BURNED", weapon );
}

// self = blob on a zombie: when the zombie dies it bursts (BO4's function_209c8c45, on its death), then goes.
mg_blob_on_zombie( zombie, player, weapon )
{
    self endon( "death" );

    if ( isalive( zombie ) )
        zombie waittill( "death" );

    self mg_blob_burst( player, weapon );
}

// self = blob on Brutus (BO4's boss: function_ba9e077b, function_78f754f7): 100 burn damage, then he burns each second
// for 10 to 20 % of his maximum health (from round 15, 5 to 10 %) for 5 s, and the blob goes without a burst (vanilla
// brutus_damage_override keeps a share of it).
mg_blob_on_brutus( brutus, player, weapon )
{
    self endon( "death" );
    brutus endon( "death" );
    mg_magma_dodamage( brutus, 100, brutus.origin, player, "MOD_BURNED", weapon );
    brutus thread mg_burn_start();
    end = gettime() + 5000;

    while ( gettime() < end )
    {
        wait 1;

        if ( level.round_number < 15 )
            dmg = brutus.maxhealth * randomfloatrange( 0.1, 0.2 );
        else
            dmg = brutus.maxhealth * randomfloatrange( 0.05, 0.1 );

        mg_magma_dodamage( brutus, int( dmg ), brutus.origin, player, "MOD_BURNED", weapon );
    }

    brutus thread mg_burn_end( 0 );
    self delete();
}

// self = blob on a zombie that died: BO4's burst (function_209c8c45), played with Harry's explosion, Tranzit's lava
// zombie bursting in fire and smoke over it (the owner's) and the Acid Gat's explosion, the remaster's sound. The
// zombies within 128 not burning yet catch fire and take 400 (a blast that tears limbs off, vanilla's gibs); any
// other enemy (Brutus, fodder, a boss) takes 20 and burns. It hurts no player. Then the blob goes (BO4 detonates nothing: no explosion of the weapon's own).
mg_blob_burst( player, weapon )
{
    pos = self.origin;
    mg_fx_once( "explo", pos );
    mg_fx_once( "burst_fire", pos );
    playsoundatposition( "wpn_blundersplat_explode", pos );

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( !isdefined( ai ) || !isalive( ai ) || is_true( ai.mg_burning ) || distancesquared( ai.origin, pos ) > 128 * 128 )
            continue;

        if ( isdefined( ai.animname ) && ai.animname != "zombie" )
        {
            ai thread mg_brutus_scorch( player, weapon, 20 );
            continue;
        }

        ai mg_zombie_ignite( player, weapon );
        mg_magma_dodamage( ai, 400, pos, player, "MOD_EXPLOSIVE", weapon );
    }

    self delete();
}

// self = zombie. BO4's burning (function_ba9e077b, function_faa2e2e5): a first hit of hit (none when undefined), then
// each second a share of its maximum health, smaller in later rounds (60 to 90 % before round 9, 30 to 50 % before
// 16, 20 to 30 % before 29, then 15 to 20 %), for 8 s at most (BO4's on_fire_timeout), credited to player. It
// counts as on fire, as vanilla's burning zombies: one killed meanwhile falls dead instead of bursting in gore
// (_zm_spawner zombie_death_event). One fire at a time.
mg_zombie_ignite( player, weapon, hit )
{
    if ( is_true( self.mg_burning ) )
        return;

    self.mg_burning = 1;
    self.is_on_fire = 1;
    self mg_burn_start();

    if ( isdefined( hit ) )
        mg_magma_dodamage( self, int( hit ), self.origin, player, "MOD_BURNED", weapon );

    self thread mg_zombie_burn( player, weapon );
}

// self = a burning zombie: its fire's damage each second, then the flames out
mg_zombie_burn( player, weapon )
{
    self endon( "death" );
    end = gettime() + 8000;
    wait 0.05;

    while ( gettime() < end )
    {
        if ( level.round_number < 9 )
            share = randomfloatrange( 0.6, 0.9 );
        else if ( level.round_number < 16 )
            share = randomfloatrange( 0.3, 0.5 );
        else if ( level.round_number < 29 )
            share = randomfloatrange( 0.2, 0.3 );
        else
            share = randomfloatrange( 0.15, 0.2 );

        mg_magma_dodamage( self, int( self.maxhealth * share ), self.origin, player, "MOD_BURNED", weapon );
        wait 1;
    }

    self.mg_burning = undefined;
    self.is_on_fire = 0;
    self thread mg_burn_end( 0 );
}

// self = Brutus scorched by a pool or a burst (BO4's boss in function_ba9e077b): one hit, then 8 s of flames that do
// no more (vanilla's damage_on_fire finds him not on fire), and nothing more while they burn.
mg_brutus_scorch( player, weapon, hit )
{
    self endon( "death" );

    if ( is_true( self.mg_burning ) )
        return;

    self.mg_burning = 1;
    mg_magma_dodamage( self, int( hit ), self.origin, player, "MOD_BURNED", weapon );
    self mg_burn_start();
    wait 8;
    self.mg_burning = undefined;
    self thread mg_burn_end( 0 );
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

// The lava pool, BO4's (function_bf2a4486): a trigger of radius 64 and 32 high at the blob for both guns, wherever it
// stuck (on a ceiling it hangs 32 lower), 5 s, its fire played the blob's way up; 2 at once at most (the oldest goes).
// A zombie touching it catches fire (mg_pool_zombie); its owner touching it takes 1 every 0.4 s (mg_pool_player).
mg_pool( blob, player, weapon, shown )
{
    level endon( "end_game" );
    pos = blob.origin;
    origin = pos;

    if ( anglestoup( shown.angles )[2] < -0.7 )
        origin = pos - ( 0, 0, 32 );

    pool = spawn( "trigger_radius", origin, 0, 64, 32 );
    pool.owner = player;
    pool.weapon = weapon;
    fire = mg_fx_loop( "patch_fire", pos, shown.angles );
    lure = mg_blob_lure( blob, weapon );

    // counted once its fire is up: the oldest may still be in that wait and miss the notify
    if ( level.mg_pools.size >= 2 )
        level.mg_pools[0] notify( "mg_pool_end" );

    level.mg_pools[level.mg_pools.size] = pool;
    pool waittill_any_timeout( 5, "mg_pool_end" );
    arrayremovevalue( level.mg_pools, pool );
    pool delete();
    mg_fx_stop( fire );

    if ( isdefined( shown ) )
        shown delete();

    if ( isdefined( lure ) )
    {
        lure deactivate_zombie_point_of_interest();
        lure delete();
    }

    if ( isdefined( blob ) )
        blob delete();
}

// The pool this entity (a zombie, a player) touches, or undefined.
mg_pool_touched( ent )
{
    foreach ( pool in level.mg_pools )
    {
        // 128 covers the trigger's radius and a body's width before the exact test
        if ( isdefined( pool ) && distancesquared( ent.origin, pool.origin ) < 128 * 128 && ent istouching( pool ) )
            return pool;
    }

    return undefined;
}

// Every 0.05 s while a pool burns.
mg_pool_damage_loop()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 0.05;

        if ( level.mg_pools.size == 0 )
            continue;

        foreach ( ai in getaiarray( level.zombie_team ) )
        {
            if ( isdefined( ai ) && isalive( ai ) )
                ai mg_pool_zombie();
        }

        foreach ( player in getplayers() )
            player mg_pool_player();
    }
}

// self = zombie in a pool (BO4's function_c74dfed4): one not burning yet catches fire for a tenth of its health
// (mg_zombie_ignite); fodder dies; Brutus or another boss is scorched for a tenth of its own (mg_brutus_scorch).
mg_pool_zombie()
{
    pool = mg_pool_touched( self );

    if ( !isdefined( pool ) || is_true( self.mg_burning ) )
        return;

    if ( mg_is_popcorn( self ) )
    {
        mg_magma_dodamage( self, self.health + 100, pool.origin, pool.owner, "MOD_BURNED", pool.weapon );
        return;
    }

    if ( mg_is_boss( self ) )
    {
        self thread mg_brutus_scorch( pool.owner, pool.weapon, self.health * 0.1 );
        return;
    }

    self mg_zombie_ignite( pool.owner, pool.weapon, self.health * 0.1 );
}

// self = player. Only the pool's owner is hurt, as BO4's (function_b1abe6ab): 1 every 0.4 s while he touches it. BO4's
// engine burns the screen for MOD_BURNED; T6 needs setburn for it (as vanilla's fire trap).
mg_pool_player()
{
    pool = undefined;

    if ( is_player_valid( self ) )
        pool = mg_pool_touched( self );

    if ( !isdefined( pool ) || !isdefined( pool.owner ) || pool.owner != self )
        return;

    if ( isdefined( self.mg_pool_next ) && gettime() < self.mg_pool_next )
        return;

    self.mg_pool_next = gettime() + 400;
    self setburn( 0.5 );
    self dodamage( 1, pool.origin );
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

// self = zombie whose fire went out: the fire loop fades now, the flames delay s later, unless it catches fire again.
mg_burn_end( delay )
{
    self endon( "death" );
    self endon( "mg_burn_restart" );
    self stoploopsound( 2 );
    self.mg_burn_loop = undefined;
    if ( delay > 0 )
        wait( delay );

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
