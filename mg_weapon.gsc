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
// - on a zombie: 0.5 s on it bursts in gore (1000 health or less) or burns, slowed to 60 %, 4 s and dies (each blob
//   on it does so again); when Magmagat damage kills it, it is torn apart and the blob bursts: the zombies within 128
//   lose limbs, catch fire and take 400;
// - on Brutus: 0.5 s on, 100, then 5 s of burning, and the blob goes;
// - anywhere else (or after 5 s of flight): a lava pool for 5 s (radius 64, 32 high; 2 at once), the blob lying in
//   it, luring 3 zombies over 128 units (6 over 256 from a Magmus or Vitriolic Withering in hand) when the floor is near
//   and playable. A zombie touching it catches fire; Brutus burns each frame until his flames light; its owner takes 1
//   every 0.4 s.
// A burning zombie takes a share of its maximum health each second for up to 8 s, while fewer than 12 enemies burn.
// The script's own Magmagat hits pay vanilla's points per hit (the carrier bullet and the blob's impact nothing) and
// kill outright under Insta-Kill, the blob's impact too (the zombie dies on contact, no burst; the blob pools). A burst
// is the killing hit's player's. Burst hits and burn ticks pass BO4's throttle (2 each 0.1 s). The Acid Gat kit takes
// the Magmagat as the Blundergat it was and makes the Acid Gat, with the Magmagat's ammo; the Mystery Box offers no
// Blundergat to a Magmagat's owner.

mg_weapon_init()
{
    level.mg_pools = [];
    level.mg_burners = [];
    level.mg_burn_fx_count = 0;
    mg_weapon_register();
    maps\mp\zombies\_zm_spawner::register_zombie_damage_callback( ::mg_magma_damage_callback );
    // chained, not replaced: vanilla _zm_ai_brutus.gsc installs its own hook on this map (a Brutus-locked table)
    level.mg_prev_craftable_validation = level.custom_craftable_validation;
    level.custom_craftable_validation = ::mg_acid_station_validation;
    level.mg_prev_box_selection = level.custom_magic_box_selection_logic;
    level.custom_magic_box_selection_logic = ::mg_box_selection;
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
    s = mg_weapon_entry( "magmagat_zm", base );
    s.upgrade_name = "magmagat_upgraded_zm";
    level.zombie_weapons["magmagat_zm"] = s;
    level.zombie_weapons_upgraded["magmagat_upgraded_zm"] = "magmagat_zm";
    level.zombie_include_weapons["magmagat_zm"] = 0;

    // the tempered guns: known to vanilla's weapon code, out of the box, never Pack-a-Punched
    foreach ( name in array( "mg_tempered_zm", "mg_tempered_upgraded_zm" ) )
    {
        level.zombie_weapons[name] = mg_weapon_entry( name, base );
        level.zombie_include_weapons[name] = 0;
    }
}

// A weapon entry for vanilla's weapon code, out of the box, priced and voiced as the Blundergat (base, when the map
// has it).
mg_weapon_entry( name, base )
{
    s = spawnstruct();
    s.weapon_name = name;
    s.weapon_classname = "weapon_" + name;
    s.is_in_box = 0;

    if ( isdefined( base ) )
    {
        s.hint = base.hint;
        s.cost = base.cost;
        s.vox = base.vox;
        s.vox_response = base.vox_response;
        s.ammo_cost = base.ammo_cost;
    }

    return s;
}

// A Pack-a-Punched tier: the Sweeper, the Vitriolic Withering, the upgraded tempered gun, the Magmus Operandi.
mg_is_upgraded( weapon )
{
    return isdefined( weapon ) && ( weapon == "blundergat_upgraded_zm" || weapon == "blundersplat_upgraded_zm" || weapon == "mg_tempered_upgraded_zm" || weapon == "magmagat_upgraded_zm" );
}

// The tempered gun the fireplace hands back for a Blundergat of this tier (BO4's model, its canisters burning blue).
mg_tempered_of( weapon )
{
    if ( mg_is_upgraded( weapon ) )
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
    if ( mg_is_upgraded( weapon ) )
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
// (zm_weap_blundergat.gsc function_482c54d5): on a zombie, on Brutus, or a lava pool on a surface. One still flying
// after 5 s pools where it is, as BO4's (its waittilltimeout of 5 s). player may leave meanwhile.
mg_blob_land( blob, player, weapon, fire )
{
    level endon( "end_game" );
    prev = blob.origin;
    dir = ( 0, 0, -1 );
    end = gettime() + 5000;
    flying = 0;

    while ( true )
    {
        wait 0.05;

        // one gone before its 5 s (out of the world) does nothing
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

        // the hidden grenade flies on to its fuse, unwatched: its pool stays here
        if ( gettime() >= end )
        {
            flying = 1;
            break;
        }
    }

    // its own model flew it; from now a copy shows it, turned to what it stuck to (mg_blob_show)
    blob hide();
    host = undefined;

    // Harry's impact is built along its +X (its splash flies out along X): forward along the surface's normal, as the
    // engine plays a projectile's impact (the pool and the blob's model stand on their +Z instead: mg_up_angles). A
    // blob still flying after 5 s hit nothing: no impact.
    if ( !flying )
    {
        mg_fx_once( "impact", blob.origin, undefined, vectortoangles( mg_blob_normal( dir, blob ) ) );
        host = mg_blob_host( blob );
    }

    // stuck to a zombie or Brutus, the blob keeps burning on it until it goes, as BO4's (magma_gat_blob_fx 2, from the
    // stick to the zombie's death or Brutus's 5 s): its flight fire rides on, gone with the grenade. Anywhere else
    // (and on an Insta-Kill impact, which pools) it goes out: the pool burns instead.
    if ( isdefined( host ) && !mg_insta_kill_on( player, host ) )
        fire thread mg_blob_show_end( blob );
    else
        mg_fx_stop( fire );

    // stuck to a teammate, it drops to the floor under him and pools there, as BO4's (function_482c54d5); stuck to
    // something else that moves but is no living zombie (a corpse, the gondola), it pools where it is, the pool staying
    // there as BO4's (its pool model is never linked). A blob on the map itself reports the world as what it is linked
    // to: that one pools too.
    linked = blob getlinkedent();

    if ( !isdefined( host ) && isdefined( linked ) && isplayer( linked ) )
    {
        floor = bullettrace( linked.origin + ( 0, 0, 40 ), linked.origin - ( 0, 0, 1000 ), 0, linked );
        blob unlink();
        blob.origin = floor["position"];
        dir = ( 0, 0, -1 );
    }
    else if ( !isdefined( host ) && isdefined( linked ) && ( isai( linked ) || linked.classname == "script_brushmodel" ) )
        blob unlink();

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
    else if ( mg_insta_kill_on( player, host ) )
    {
        // BO4 threads the weapon's damage override (zm.gsc actor_damage_override_wrapper), so its "return 0" for
        // MOD_IMPACT cancels nothing, and Insta-Kill (zm_powerups function_fe6d6eac) turns the impact into health + 666:
        // the zombie dies on contact, head gibbed, with no burst (function_efefda46 returns before it on MOD_IMPACT,
        // mg_blob_on_zombie as it); the blob pools where it is. The spoon counts it, as the 0.5 s kill (mg_magma_stuck).
        host notify( "killed_by_a_blundersplat", player );

        if ( !is_true( host.no_gib ) )
            host thread maps\mp\zombies\_zm_spawner::zombie_head_gib( player, "MOD_IMPACT" );

        // the owner's call over BO4 (which pools at the projectile, here the zombie's chest, 12 to 72 over his feet):
        // the blob and its pool drop to the floor under him, as the teammate branch above, so no fire hangs in the
        // air. The floor is traced while he still stands (his body ignored), and the pool stands on its normal.
        floor = bullettrace( blob.origin + ( 0, 0, 8 ), blob.origin - ( 0, 0, 1000 ), 0, host );
        host dodamage( host.health + 666, blob.origin, player, player, "none", "MOD_IMPACT", 0, weapon );
        blob unlink();
        up = ( 0, 0, 1 );

        if ( floor["fraction"] < 1 )
        {
            blob.origin = floor["position"];
            up = floor["normal"];
        }

        shown = blob mg_blob_show( mg_up_angles( up ), 0 );
        level thread mg_pool( blob, player, weapon, shown );
    }
    else
    {
        blob mg_blob_show( blob.angles, 1 );
        blob thread mg_blob_on_zombie( host );

        // each blob on it, a second one too, as each of BO4's impacts (function_efefda46: MOD_IMPACT)
        host thread mg_magma_stuck( player, weapon, blob.origin );
    }
}

// self = a blob grenade. Its visible copy, turned to angles, riding it when ride is set; gone with the grenade.
mg_blob_show( angles, ride )
{
    shown = spawn( "script_model", self.origin );
    shown.angles = angles;
    shown setmodel( mg_model( "ball" ) );
    // BO4's stuck blob sounds (zm_weap_blundergat.csc magma_gat_blob_fx): its stick, then its burning loop until it goes.
    // The stick plays at its place: an event on an entity in the frame it appears is dropped by the clients.
    playsoundatposition( "mg_blob_stick", self.origin );
    shown playloopsound( "mg_blob_loop" );

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
// and 3 zombies (256 and 6 when its owner holds the Magmus Operandi or the Vitriolic Withering as it lands), only when
// that floor is within 64 of the blob (a blob up a wall or on a ceiling draws no one) and in the playable area; its
// spots are in the fire, freed as their zombies die (below). Brutus ignores it (vanilla brutus_spawn sets his
// ignore_all_poi, which get_zombie_point_of_interest honours). pos is where the pool lies, read as it started: a blob
// still flying at 5 s pools there while its hidden grenade flies on (and may be gone). Returns its entity, or undefined.
mg_blob_lure( pos, blob, player )
{
    ignore = undefined;

    if ( isdefined( blob ) )
        ignore = blob;

    trace = bullettrace( pos, pos - ( 0, 0, 1000 ), 0, ignore );

    // BO4's in_playable_area, and its create_zombie_point_of_interest's is_point_inside_enabled_zone: no lure in a
    // zone not yet opened
    if ( trace["fraction"] >= 1 || distance( trace["position"], pos ) > 64 || !check_point_in_playable_area( trace["position"] ) || !check_point_in_enabled_zone( trace["position"] ) )
        return undefined;

    held = undefined;

    if ( isdefined( player ) )
        held = player getcurrentweapon();

    lure = spawn( "script_origin", trace["position"] );

    n = 3;
    radius = 128;

    if ( isdefined( held ) && ( held == "magmagat_upgraded_zm" || held == "blundersplat_upgraded_zm" ) )
    {
        n = 6;
        radius = 256;
    }

    // BO4's attractors (create_zombie_point_of_interest_attractor_positions): n spots on the navmesh nearest the
    // pool's middle, 7.5 apart, so its zombies walk into the fire; one dying frees its spot (update_poi_on_death)
    // and the next comes, so over the pool's 5 s it draws nearly every zombie near it, as in BO4's play. Vanilla's
    // own layout puts its rings outside the pool (and hands out none under 4 a ring): the spots are laid here, one
    // ring of n round the middle (add_poi_attractor reads attractor_positions[i] = ( spot, lure ) and last_index)
    lure create_zombie_point_of_interest( radius, n, 10000 );
    lure.attractor_positions = [];

    for ( i = 0; i < n; i++ )
    {
        spot = lure.origin + anglestoforward( ( 0, i * 360 / n, 0 ) ) * 12;
        lure.attractor_positions[i] = array( spot, lure );
    }

    lure.last_index = array( n, n, n, n );
    lure.attract_to_origin = 0;
    level notify( "attractor_positions_generated" );    // as vanilla's layout: zombies repath to it now (attractors_generated_listener)
    return lure;
}

// self = zombie the blob stuck to (BO4's function_dc3470c5): 0.5 s on, one of 1000 health or less bursts in gore and
// dies; a tougher one catches fire for 1000 (another blob on a burning one: the 1000 alone), is slowed 4 s
// (function_7f95d262), then dies whatever its health. The notify feeds the spoon in the showers, as the remaster's
// killed_by_a_magmagat does.
mg_magma_stuck( player, weapon, from )
{
    self endon( "death" );
    wait 0.5;
    self notify( "killed_by_a_blundersplat", player );

    // fodder: killed outright; its death bursts it (mg_blob_on_zombie), as BO4's popcorn
    if ( mg_is_popcorn( self ) )
    {
        mg_magma_dodamage( self, self.health + 100, self.origin, player, "MOD_BURNED", weapon );
        return;
    }

    if ( self.health <= 1000 )
    {
        self mg_annihilate();
        mg_magma_dodamage( self, self.health + 100, self.origin, player, "MOD_BURNED", weapon );
        return;
    }

    self mg_zombie_ignite( player, weapon, 1000, from );

    // BO4's slowdown (hash_716657b9842cfd1b): 60 % of its speed whatever its gait, as vanilla's slowing weapons set
    // it (_zm_weap_slowgun, _zm_weap_staff_water: the anim rate, then a run update); it dies slowed
    self setentityanimrate( 0.6 );
    self.preserve_asd_substates = 1;    // as vanilla's staff_water set_anim_rate: its own run kept, not a new one

    if ( !is_true( self.is_traversing ) )
        self maps\mp\animscripts\zm_run::needsupdate();

    wait 4;
    mg_magma_dodamage( self, self.health + 100, self.origin, player, "MOD_BURNED", weapon, "torso_lower" );    // BO4's (function_7f95d262)
}

// self = zombie. BO4's annihilate (gibserverutils, its Magmagat deaths), as T6 can: vanilla's gut explosion, once;
// none in a hungry wolf's area (level.no_gib_in_wolf_area, where BO4 sets no_gib too) nor on a no_gib zombie. Its
// explosion sound plays either way, once, at its upper spine (BO4's zombie_magma_fire_explosion clientfield, set with
// every annihilate: zm_weap_blundergat.csc plays it at j_spineupper).
mg_annihilate()
{
    if ( !is_true( self.mg_exploded ) )
    {
        self.mg_exploded = 1;
        at = self gettagorigin( "j_spineupper" );

        if ( !isdefined( at ) )
            at = self.origin;

        playsoundatposition( "mg_explode", at );
    }

    if ( isdefined( level.no_gib_in_wolf_area ) && self [[ level.no_gib_in_wolf_area ]]() )
        self.no_gib = 1;

    if ( is_true( self.no_gib ) || is_true( self.guts_explosion ) )
        return;

    self thread maps\mp\zombies\_zm_spawner::zombie_gut_explosion();
}

// self = blob on a zombie. When Magmagat damage kills the zombie (BO4's function_efefda46 runs for its damage only:
// willbekilled) the zombie is torn apart and the blob bursts around it (function_209c8c45), for the killing player;
// any other death (another weapon, a trap, a despawn, a blob's impact) only takes the blob.
mg_blob_on_zombie( zombie )
{
    self endon( "death" );

    if ( isalive( zombie ) )
        zombie waittill( "death" );

    // a zombie killed by a blob's impact (Insta-Kill, mg_blob_land) does not burst, even wearing an older blob, as BO4's
    if ( !isdefined( zombie ) || !mg_is_magma_damage( zombie.damageweapon ) || zombie.damagemod == "MOD_IMPACT" )
    {
        self delete();
        return;
    }

    // BO4's burst is the killing hit's (function_efefda46, then function_209c8c45): its attacker and weapon, so in co-op
    // another player's Magmagat burn killing a zombie wearing this blob bursts it for him; no living player, no one
    killer = undefined;

    if ( isdefined( zombie.attacker ) && isplayer( zombie.attacker ) && isalive( zombie.attacker ) )
        killer = zombie.attacker;

    // BO4 plays the burst on the body at its upper spine (zombie_magma_fire_explosion): read before the annihilate,
    // which ghosts the body
    at = zombie gettagorigin( "j_spineupper" );

    if ( !isdefined( at ) )
        at = self.origin;

    hit = zombie getcentroid();    // where BO4's burst hits its neighbours from (getcentroid)
    zombie mg_annihilate();
    self mg_blob_burst( killer, zombie.damageweapon, zombie.origin, at, hit );
}

// self = blob on Brutus (BO4's boss: function_5f305489): his burn (mg_brutus_blob_burn) for 5 s, then the blob goes
// without a burst (it lands whole, as BO4's: mg_brutus_unscaled), ending every blob's burn on him with its own, as
// BO4's one notify does (hash_556bad125b55e1a9). A Brutus dying meanwhile takes the blob with him at once.
mg_blob_on_brutus( brutus, player, weapon )
{
    // the blobs on him, counted: his flames go out only when nothing burns him any more (no blob left on him, and no
    // pool or burst burn, mg_brutus_scorch's mg_burning), not at the first blob's end while a pool's 8 s still run.
    // No endon on the blob: one removed early still takes its count off him (the loop sees it gone), so the count
    // never sticks and his flames never stay lit for good.
    if ( !isdefined( brutus.mg_blobs ) )
        brutus.mg_blobs = 0;

    // no flames yet: as BO4's, he lights only through the scorch (mg_brutus_blob_burn's at 0.5 s, then damage_on_fire's
    // 2 s), 2.5 s after the stick and while fewer than 12 enemies burn
    brutus.mg_blobs++;
    brutus thread mg_brutus_blob_burn( player, weapon );
    end = gettime() + 5000;

    while ( gettime() < end && isdefined( self ) && isdefined( brutus ) && isalive( brutus ) )
        wait 0.05;

    if ( isdefined( brutus ) && isalive( brutus ) )
    {
        brutus.mg_blobs--;
        brutus notify( "mg_blob_out" );

        if ( !is_true( brutus.mg_burning ) && brutus.mg_blobs <= 0 )
            brutus thread mg_burn_end();
    }

    if ( isdefined( self ) )
        self delete();
}

// self = Brutus a blob stuck to (BO4's function_dc3470c5, function_78f754f7): 0.5 s on, 100 burn damage
// (mg_brutus_scorch), then at once and each second 10 to 20 % of his maximum health (from round 15, 5 to 10 %), until
// a blob on him comes off.
mg_brutus_blob_burn( player, weapon )
{
    self endon( "death" );
    wait 0.5;
    self endon( "mg_blob_out" );
    self thread mg_brutus_scorch( player, weapon, 100 );

    while ( true )
    {
        if ( level.round_number < 15 )
            dmg = self.maxhealth * randomfloatrange( 0.1, 0.2 );
        else
            dmg = self.maxhealth * randomfloatrange( 0.05, 0.1 );

        mg_magma_dodamage( self, int( dmg ), self.origin, player, "MOD_BURNED", weapon );
        wait 1;
    }
}

// self = blob on a zombie that died: BO4's burst (function_209c8c45), played with Harry's explosion, Tranzit's lava
// zombie bursting in fire and smoke over it (the owner's), both at its upper spine (at); its sound is BO4's explosion,
// played as the zombie is annihilated (mg_annihilate). The zombies within 128 of the dead one (centre) never lit yet
// lose limbs (function_b826901d: gib_random_parts, before the fire), catch fire and take 400 from its centroid (hit);
// any other enemy (Brutus, fodder, a boss) takes 20 and burns. It hurts no player. Then the blob goes (BO4 detonates
// nothing: no explosion of the weapon's own).
mg_blob_burst( player, weapon, centre, at, hit )
{
    mg_fx_once( "explo", at, undefined, ( -90, 0, 0 ) );    // its +X up: Harry's burst is built along X, it sprayed sideways
    mg_fx_once( "burst_fire", at );

    foreach ( ai in getaiarray( level.zombie_team ) )
    {
        if ( !isdefined( ai ) || !isalive( ai ) || is_true( ai.mg_lit ) || is_true( ai.is_on_fire ) || distancesquared( ai.origin, centre ) > 128 * 128 )
            continue;

        if ( isdefined( ai.animname ) && ai.animname != "zombie" )
        {
            ai thread mg_brutus_scorch( player, weapon, 20 );
            continue;
        }

        // lit only on its turn in the throttle (mg_zombie_ignite), as BO4's: a second burst before that turn hits it
        // again (400 and its limbs; it burns once)
        ai thread mg_burst_hit( player, weapon, hit );
    }

    self delete();
}

// self = zombie in a burst (BO4's function_b826901d): its turn in BO4's throttle (mg_throttle_wait), then its limbs,
// its fire and 400 at the lower torso, as BO4's hit
mg_burst_hit( player, weapon, pos )
{
    self endon( "death" );
    mg_throttle_wait();
    self mg_gib_random_parts( player );
    self mg_zombie_ignite( player, weapon, undefined, pos );
    mg_magma_dodamage( self, 400, pos, player, "MOD_EXPLOSIVE", weapon, "torso_lower" );
}

// BO4's throttle (zm_weap_blundergat level.var_214f6204: throttle_shared initialize( 2, 0.1 ), waitinqueue), shared by
// every burst hit and burn tick: 2 go through each 0.1 s, the others wait their turn in order, in a queue. A zombie
// that dies (or is removed) while it waits leaves the queue, its place going to the next, as BO4's _updatethrottle
// drops the entities gone: no place is ever kept for a dead waiter, so nothing waits behind one. self = the zombie
// waiting (its caller ends on its death, so its thread ends at once; mg_throttle_loop drops its ticket).
mg_throttle_wait()
{
    if ( !isdefined( level.mg_throttle_q ) )
    {
        level.mg_throttle_q = [];
        level.mg_throttle_free = 2;
        level thread mg_throttle_loop();
    }

    // a free place this 0.1 s and nobody before him: he goes at once
    if ( level.mg_throttle_free > 0 && level.mg_throttle_q.size == 0 )
    {
        level.mg_throttle_free--;
        return;
    }

    ticket = spawnstruct();    // one per wait: the same zombie may wait twice (a burn tick and a burst hit)
    ticket.ent = self;
    level.mg_throttle_q[level.mg_throttle_q.size] = ticket;
    ticket waittill( "mg_throttle_go" );
}

// Each 0.1 s: 2 places again, the dead waiters dropped, the first ones in line let through. The queue left is set
// before they go: one let through may kill a zombie whose burst queues more, and those join this queue, not a lost one.
mg_throttle_loop()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 0.1;
        free = 2;
        go = [];
        q = [];

        foreach ( ticket in level.mg_throttle_q )
        {
            if ( !isdefined( ticket.ent ) || !isalive( ticket.ent ) )
                continue;

            if ( free > 0 )
            {
                free--;
                go[go.size] = ticket;
            }
            else
                q[q.size] = ticket;
        }

        level.mg_throttle_q = q;
        level.mg_throttle_free = free;

        foreach ( ticket in go )
            ticket notify( "mg_throttle_go" );
    }
}

// self = zombie. BO4's gib_random_parts (zombie_utility): its head, each leg and each arm torn off one time in two,
// none with no_gib. T6 tears off one limb at a time (do_gib): the head apart (zombie_head_gib), then both legs, one
// leg or one arm, a zombie left without legs crawling on as vanilla's zombie_gib_on_damage sets it.
mg_gib_random_parts( player )
{
    if ( is_true( self.no_gib ) || !is_mature() )
        return;

    if ( randomint( 100 ) > 50 )
        self thread maps\mp\zombies\_zm_spawner::zombie_head_gib( player, "MOD_EXPLOSIVE" );    // its bleed credits him (damage_over_time)

    right_leg = randomint( 100 ) > 50;
    left_leg = randomint( 100 ) > 50;
    right_arm = randomint( 100 ) > 50;
    left_arm = randomint( 100 ) > 50;

    if ( right_leg && left_leg )
        ref = "no_legs";
    else if ( right_leg )
        ref = "right_leg";
    else if ( left_leg )
        ref = "left_leg";
    else if ( right_arm )
        ref = "right_arm";
    else if ( left_arm )
        ref = "left_arm";
    else
        return;

    if ( is_true( self.gibbed ) )
        return;

    self.a.gib_ref = ref;

    if ( ref != "right_arm" && ref != "left_arm" )
    {
        self.has_legs = 0;
        self allowedstances( "crouch" );
        self setphysparams( 15, 0, 24 );
        self allowpitchangle( 1 );
        self setpitchorient();
        self thread maps\mp\animscripts\zm_run::needsdelayedupdate();

        if ( isdefined( self.crawl_anim_override ) )
            self [[ self.crawl_anim_override ]]();
    }

    self thread maps\mp\animscripts\zm_death::do_gib();

    if ( isdefined( level.gib_on_damage ) )
        self thread [[ level.gib_on_damage ]]();
}

// self = zombie. BO4's burning (function_ba9e077b, function_faa2e2e5): a first hit of hit (none when undefined), then
// each second a share of its maximum health, smaller in later rounds (60 to 90 % before round 9, 30 to 50 % before
// 16, 20 to 30 % before 29, then 15 to 20 %), for 8 s at most (BO4's on_fire_timeout), credited to player. The fire
// takes only while fewer than 12 enemies burn (mg_burner_add, BO4's level.var_5fcf49dc): over that, only the hit
// lands, and a pool touching it hits it again each frame. A zombie burns once in its life (var_cde645df): a later
// ignition is its hit alone. Burning, it counts as on fire, as vanilla's burning zombies: one killed meanwhile falls
// dead instead of bursting in gore (_zm_spawner zombie_death_event). from: where it caught fire (its first flame).
mg_zombie_ignite( player, weapon, hit, from )
{
    self.mg_lit = 1;
    burn = !is_true( self.mg_burning ) && self mg_burner_add();

    if ( burn )
    {
        self.mg_burning = 1;
        self.is_on_fire = 1;
        self.mg_burn_from = from;    // where it caught fire: its first flame (mg_burn_fx)
        self mg_burn_start();
    }

    if ( isdefined( hit ) )
        mg_magma_dodamage( self, int( hit ), self.origin, player, "MOD_BURNED", weapon, "torso_lower" );    // as function_ba9e077b's

    if ( burn && isalive( self ) )    // an Insta-Kill ignition kills: no burn on the corpse
        self thread mg_zombie_burn( player, weapon );
}

// self = an enemy catching fire. BO4 lets it burn while fewer than 12 enemies are counted burning
// (function_ba9e077b, function_20905835: one counted stays so until it dies); returns whether it may (and counts it).
mg_burner_add()
{
    burners = [];

    foreach ( ai in level.mg_burners )
    {
        if ( isdefined( ai ) && isalive( ai ) )
            burners[burners.size] = ai;
    }

    level.mg_burners = burners;

    if ( level.mg_burners.size >= 12 )
        return 0;

    if ( !isinarray( level.mg_burners, self ) )
        level.mg_burners[level.mg_burners.size] = self;

    return 1;
}

// self = a burning zombie: its fire's damage each second, then the flames out
mg_zombie_burn( player, weapon )
{
    self endon( "death" );
    end = gettime() + 8000;
    wait 0.05;

    while ( gettime() < end )
    {
        mg_throttle_wait();    // BO4's waitinqueue before each tick

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

    self.is_on_fire = 0;
    self thread mg_burn_end();
}

// self = Brutus (or another boss) set alight by a blob, a pool or a burst (BO4's boss in function_ba9e077b): a hit of
// hit; then, his flames not up yet, 2 s on (vanilla's damage_on_fire waits so) they light for 8 s (flame_death_fx,
// on_fire_timeout) while fewer than 12 enemies burn (mg_burner_add). A hit whose 2 s end with his flames up burns him
// as damage_on_fire does: a share of a zombie's health every 1 to 3 s while they last. A pool he touches hits him
// each frame until they light (mg_pool_zombie).
mg_brutus_scorch( player, weapon, hit )
{
    self endon( "death" );
    self.mg_lit = 1;
    mg_magma_dodamage( self, int( hit ), self.origin, player, "MOD_BURNED", weapon, "torso_lower" );    // as function_ba9e077b's

    if ( is_true( self.mg_burning ) )
        return;

    wait 2;

    if ( is_true( self.mg_burning ) )
    {
        self endon( "mg_burn_out" );

        while ( true )
        {
            if ( level.round_number < 6 )
                dmg = level.zombie_health * randomfloatrange( 0.2, 0.3 );
            else if ( level.round_number < 9 )
                dmg = level.zombie_health * randomfloatrange( 0.15, 0.25 );
            else if ( level.round_number < 11 )
                dmg = level.zombie_health * randomfloatrange( 0.1, 0.2 );
            else
                dmg = level.zombie_health * randomfloatrange( 0.1, 0.15 );

            mg_magma_dodamage( self, int( dmg ), self.origin, player, "MOD_BURNED", weapon );
            wait( randomfloatrange( 1.0, 3.0 ) );
        }
    }

    if ( !self mg_burner_add() )
        return;

    self.mg_burning = 1;
    self mg_burn_start();
    wait 8;
    self.mg_burning = undefined;
    self notify( "mg_burn_out" );

    // a blob still on him keeps his flames: the last blob's end puts them out (mg_blob_on_brutus)
    if ( !is_true( self.mg_blobs ) )
        self thread mg_burn_end();
}

// Magmagat damage, credited to its player while he is still here and alive. Under his Insta-Kill it kills outright,
// the head gibbed, as BO4's on every hit, burns too (zm_powerups function_fe6d6eac; vanilla check_for_instakill's
// rules): not Brutus (his instakill_func, BO4's instakill_override too). hitloc, "none" unless given, is BO4's where it
// names one (torso_lower: function_ba9e077b's hit, the burst's 400, function_7f95d262's kill).
mg_magma_dodamage( victim, amount, pos, player, mod, weapon, hitloc )
{
    if ( !isdefined( hitloc ) )
        hitloc = "none";

    // credited only to a living player, as BO4's burns (function_faa2e2e5, function_78f754f7: isalive); a dead one's
    // burns land with no attacker, unscaled on Brutus as vanilla's (mg_brutus_unscaled)
    if ( isdefined( player ) && !isalive( player ) )
        player = undefined;

    if ( mg_insta_kill_on( player, victim ) )
    {
        if ( !is_true( victim.no_gib ) )
            victim thread maps\mp\zombies\_zm_spawner::zombie_head_gib( player, mod );

        amount = victim.health + 666;
    }

    amount = mg_brutus_unscaled( victim, amount, player, mod, weapon );

    if ( isdefined( player ) )
        victim dodamage( amount, pos, player, player, hitloc, mod, 0, weapon );
    else
        victim dodamage( amount, pos, undefined, victim, hitloc, mod, 0, weapon );    // the weapon kept (the burst checks it), as vanilla zombie_damage
}

// Whether a hit of this player kills victim outright, BO4's Insta-Kill test (zm_powerups function_fe6d6eac; vanilla
// check_for_instakill's rules): a living player under his team's or his own Insta-Kill, not on Brutus (instakill_func)
mg_insta_kill_on( player, victim )
{
    return isdefined( player ) && isplayer( player ) && isalive( player ) && ( level.zombie_vars[player.team]["zombie_insta_kill"] || is_true( player.personal_instakill ) ) && !isdefined( victim.instakill_func ) && !is_magic_bullet_shield_enabled( victim );
}

// The Magmagat's burns on Brutus land as BO4's do: vanilla brutus_damage_override (_zm_ai_brutus.gsc) keeps a tenth of
// any body hit (level.brutus_damage_percent, all of it under an insta-kill) and half again from a "spread" weapon,
// where BO4's Brutus lets the Magmagat's burn through (a stuck blob kills him in 3 to 5 s before round 15). So a burn
// (MOD_BURNED: never the override's explosive or head branches) is raised by what the override will take off it, one
// more so that the override's int() takes no point off it. Without its player the burn is unscaled already: vanilla
// actor_damage_override (_zm.gsc) returns a hit with no attacker before the override.
mg_brutus_unscaled( victim, amount, player, mod, weapon )
{
    if ( mod != "MOD_BURNED" || !isdefined( player ) || !isplayer( player ) || !isdefined( victim.animname ) || victim.animname != "brutus_zombie" || !isdefined( level.brutus_damage_percent ) )
        return amount;

    scale = level.brutus_damage_percent;

    if ( isalive( player ) && ( level.zombie_vars[player.team]["zombie_insta_kill"] || is_true( player.personal_instakill ) ) )
        scale = 1.0;

    if ( isdefined( weapon ) && weaponclass( weapon ) == "spread" && isdefined( level.brutus_shotgun_damage_mod ) )
        scale = scale * level.brutus_shotgun_damage_mod;

    return int( amount / scale ) + 1;
}

// self = zombie (vanilla _zm_spawner::zombie_damage, on each hit it survives). Magmagat damage skips vanilla's flame and
// grenade handling, as the remaster's function_93036c27, but pays vanilla's points for the script's own hits as BO4 pays
// its own on every hit (zm_score function_89db94b3): a burn at most every 0.5 s, as vanilla's fire
// (zombie_give_flame_damage_points); Brutus none, as vanilla (no_damage_points). The kill pays as ever.
mg_magma_damage_callback( mod, hit_location, hit_origin, player, amount )
{
    if ( !mg_is_magma_damage( self.damageweapon ) )
        return false;

    if ( is_true( self.no_damage_points ) )
        return true;

    if ( mod == "MOD_BURNED" )
    {
        if ( self maps\mp\zombies\_zm_spawner::zombie_give_flame_damage_points() )
            player maps\mp\zombies\_zm_score::player_add_points( "damage", mod, hit_location, self.isdog, self._race_team );

        return true;
    }

    // only the script's own Magmagat damage pays, as BO4's (its burns above, the burst's 400): the 0-damage carrier
    // bullet (BO4 has none, the weapon is its projectile) and the blob's impact pay nothing. Returning true still keeps
    // vanilla's Insta-Kill off them (check_for_instakill): mg_blob_land kills on the impact itself.
    if ( mod != "MOD_EXPLOSIVE" )
        return true;

    damage_type = "damage_light";

    if ( maps\mp\zombies\_zm_spawner::player_using_hi_score_weapon( player ) )
        damage_type = "damage";

    player maps\mp\zombies\_zm_score::player_add_points( damage_type, mod, hit_location, self.isdog, self._race_team, self.damageweapon );
    return true;
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
    lure = mg_blob_lure( pos, blob, player );

    // live from the landing, as BO4's (the effect spawns after): the oldest of two goes, flagged too, as it may still
    // be waiting for its own effect and miss the notify
    if ( level.mg_pools.size >= 2 )
    {
        level.mg_pools[0].mg_ended = 1;
        level.mg_pools[0] notify( "mg_pool_end" );
    }

    level.mg_pools[level.mg_pools.size] = pool;
    fire = mg_fx_loop( "patch_fire", pos, shown.angles );

    if ( !is_true( pool.mg_ended ) )
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

// self = zombie in a pool (BO4's function_c74dfed4, on each frame's trigger): one not burning yet catches fire for a
// tenth of its health (mg_zombie_ignite); fodder dies; Brutus or another boss is scorched for a tenth of his own
// (mg_brutus_scorch), each frame until his flames light.
mg_pool_zombie()
{
    pool = mg_pool_touched( self );

    if ( !isdefined( pool ) || is_true( self.mg_burning ) || is_true( self.is_on_fire ) )
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

    self mg_zombie_ignite( pool.owner, pool.weapon, self.health * 0.1, pool.origin );
}

// self = player. Only the pool's owner is hurt, as BO4's (function_b1abe6ab): 1 every 0.4 s while he touches it, down
// or not (vanilla spares a downed player the damage itself), with a light rumble. BO4's engine burns the screen for
// MOD_BURNED; T6 needs setburn for it (as vanilla's fire trap).
mg_pool_player()
{
    pool = undefined;

    if ( is_player_valid( self, undefined, 1 ) )
        pool = mg_pool_touched( self );

    if ( !isdefined( pool ) || !isdefined( pool.owner ) || pool.owner != self )
        return;

    if ( isdefined( self.mg_pool_next ) && gettime() < self.mg_pool_next )
        return;

    self.mg_pool_next = gettime() + 400;
    self setburn( 0.5 );
    self dodamage( 1, pool.origin );
    self playrumbleonentity( "damage_light" );
}

// self = zombie. It burns: BO4's ignite and fire loop, and its flames, on 12 zombies at most for T6's effect budget.
mg_burn_start()
{
    if ( !is_true( self.mg_burn_watched ) )
    {
        self.mg_burn_watched = 1;
        self thread mg_burn_death();
    }

    // BO4's (zm_weap_blundergat.csc positional_zombie_fire_fx): it ignites, then burns in a loop. A zombie's only:
    // Brutus burns silently, as BO4's boss fire (flame_death_fx)
    if ( !is_true( self.mg_burn_loop ) && !mg_is_boss( self ) )
    {
        self.mg_burn_loop = 1;
        self playsound( "mg_burn_ignite" );
        self playloopsound( "mg_burn_loop", 1 );
    }

    if ( is_true( self.mg_burn_lit ) || level.mg_burn_fx_count >= 12 )
        return;

    self.mg_burn_lit = 1;
    level.mg_burn_fx_count++;
    self thread mg_burn_fx();
}

// self = zombie. Its flames, laid out as vanilla's flame_death_fx lays a burning body's (zm_death): Mob's torso fire up
// and down the spine and a small fire on an arm and a leg, until mg_burn_end, or 2 s after its death as it lies there
// (the owner's pick over the remaster's BO3 body fire). They light in BO4's order: a zombie's at the tag nearest where
// it caught fire first, then one more every 0.5 s (zm_weap_blundergat.csc positional_zombie_fire_fx); Brutus's torso
// first, an arm or a leg 1 s on, the rest 1 s later (zm_death flame_death_fx).
mg_burn_fx()
{
    elbow = random( array( "J_Elbow_LE", "J_Elbow_RI" ) );
    knee = random( array( "J_Knee_LE", "J_Knee_RI" ) );

    if ( mg_is_boss( self ) )
    {
        tags = array( "J_SpineLower", elbow, knee, "J_SpineUpper" );
        keys = array( "burn", "blob_fire", "blob_fire", "burn" );
        delays = array( 0, 1, 1, 0 );
    }
    else
    {
        tags = array( "J_SpineUpper", "J_SpineLower", elbow, knee );
        keys = array( "burn", "burn", "blob_fire", "blob_fire" );
        delays = array( 0, 0.5, 0.5, 0.5 );

        // nearest first (a short sort of four)
        if ( isdefined( self.mg_burn_from ) )
        {
            for ( i = 0; i < tags.size - 1; i++ )
            {
                for ( j = i + 1; j < tags.size; j++ )
                {
                    if ( distancesquared( self gettagorigin( tags[j] ), self.mg_burn_from ) < distancesquared( self gettagorigin( tags[i] ), self.mg_burn_from ) )
                    {
                        t = tags[i];
                        tags[i] = tags[j];
                        tags[j] = t;
                        k = keys[i];
                        keys[i] = keys[j];
                        keys[j] = k;
                    }
                }
            }
        }
    }

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
        self thread mg_burn_fx_spread( fx, keys, delays );

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

// self = burning enemy. Its flames light one by one, each delays[i] after the one before; they stop spreading when it
// dies or its fire goes out (mg_burn_fx then deletes them all).
mg_burn_fx_spread( fx, keys, delays )
{
    self endon( "death" );
    self endon( "mg_burn_fx_off" );
    self endon( "zombie_delete" );

    for ( i = 0; i < fx.size; i++ )
    {
        if ( delays[i] > 0 )
            wait( delays[i] );

        if ( isdefined( fx[i] ) )
            mg_fx_add( fx[i], keys[i] );
    }
}

// self = zombie whose fire went out: the fire loop fades, the flames go (mg_burn_fx).
mg_burn_end()
{
    self stoploopsound( 2 );
    self.mg_burn_loop = undefined;
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
// Withering), as the remaster's kit does, and the new Acid Gat keeps the Magmagat's ammo (mg_acid_stock_keep). With
// an Acid Gat already, the Magmagat goes in all the same and vanilla refills the Acid Gat, as BO4's kit
// (function_b1347a6) does.
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

    // a Blundergat beside it goes in instead (vanilla's pick, BO4's order)
    if ( !isdefined( magma ) || player hasweapon( "blundergat_zm" ) || player hasweapon( "blundergat_upgraded_zm" ) )
        return 1;

    base = "blundergat_zm";

    if ( magma == "magmagat_upgraded_zm" )
        base = "blundergat_upgraded_zm";

    if ( !player hasweapon( "blundersplat_zm" ) && !player hasweapon( "blundersplat_upgraded_zm" ) )
        player thread mg_acid_stock_keep( self, player getweaponammostock( magma ) );

    player takeweapon( magma );
    player giveweapon( base );
    player switchtoweapon( base );
    self thread mg_acid_station_show( magma, base );
    mg_debug_print( "MG: " + player.name + " hands a " + magma + " to the Acid Gat kit" );
    return 1;
}

// self = the Acid Gat kit's trigger a Magmagat was just handed to (mg_acid_station_validation). Vanilla's station lays
// the gun it takes in the kit as a model of the Blundergat (blundergat_upgrade_station: m_upgrade_machine.worldgun,
// spawn_weapon_model) right after this hook returns, in the same frame, then waits 0.5 s before its animations. At the
// frame's end, before any client saw it, that model becomes the Magmagat (or the Magmus Operandi) going in, as the
// remaster's kit shows (_zm_weap_blundersplat.gsc: spawn_weapon_model of the Magmagat); vanilla still deletes it for
// the Acid Gat's model once the kit is done (blundergat_upgrade_station_inject), and deletes that at the pickup.
mg_acid_station_show( magma, base )
{
    waittillframeend;
    machine = self.m_upgrade_machine;

    // only the Blundergat vanilla has just laid in: none when it took nothing after all
    if ( !isdefined( machine ) || !isdefined( machine.worldgun ) || machine.worldgun.model != getweaponmodel( base ) )
        return;

    machine.worldgun useweaponmodel( magma, getweaponmodel( magma ) );
}

// self = player who handed a Magmagat to the Acid Gat kit (kit). The Acid Gat he takes from it keeps the Magmagat's
// stock, up to its own maximum, as BO4's kit does (function_b1347a6: var_452feb6c); none when the kit times out.
mg_acid_stock_keep( kit, stock )
{
    self endon( "disconnect" );
    kit endon( "acid_timeout" );
    self waittill( "player_obtained_acidgat" );

    foreach ( w in array( "blundersplat_zm", "blundersplat_upgraded_zm" ) )
    {
        if ( self hasweapon( w ) )
            self setweaponammostock( w, int( min( stock, weaponmaxammo( w ) ) ) );
    }
}

// The Mystery Box (vanilla treasure_chest_canplayerreceiveweapon) offers no Blundergat to a player holding any gun of
// its family, the Magmagats and the tempered guns too, nor to one whose Blundergat lies in the quest (in the fireplace
// or on the forge), as BO4's Blood of the Dead (zm_escape.gsc function_3511e2af, var_22b64976); vanilla already
// refuses it beside a Blundergat or an Acid Gat. A hook set before ours runs first.
mg_box_selection( weapon, player, pap_triggers )
{
    if ( isdefined( level.mg_prev_box_selection ) && !( [[ level.mg_prev_box_selection ]]( weapon, player, pap_triggers ) ) )
        return 0;

    if ( weapon != "blundergat_zm" || !isdefined( player ) )
        return 1;

    // his Blundergat is in the quest: in the fire (mg_hearth_place to the take or the loss) or on the forge's bed
    // (mg_forge_place to the take or the 15 s loss, mg_forge_ready_clear)
    if ( ( isdefined( level.mg_hearth_owner ) && level.mg_hearth_owner == player ) || ( isdefined( level.mg_forge_placer ) && level.mg_forge_placer == player ) )
        return 0;

    return !isdefined( mg_has_magma( player ) ) && !player hasweapon( "mg_tempered_zm" ) && !player hasweapon( "mg_tempered_upgraded_zm" );
}
