#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;

// The Magmagat is the Blundergat with a script personality (spec section 4): each shot also launches a lava
// ball; a zombie that catches it burns 0.6 s and explodes (150 units); a miss leaves an 8 s magma patch.

mg_weapon_init()
{
    level.mg_patches = [];
    // chained, not replaced: vanilla _zm_ai_brutus.gsc:127 installs its own hook on this map (paid unlock of a
    // Brutus-locked table); ours only adds the Magmagat refusal on the Acid Gat station
    level.mg_prev_craftable_validation = level.custom_craftable_validation;
    level.custom_craftable_validation = ::mg_acid_station_validation;
    level thread mg_weapon_connect_watch();
}

mg_weapon_connect_watch()
{
    level endon( "end_game" );

    foreach ( player in getplayers() )
        player thread mg_weapon_player_watch();

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread mg_weapon_player_watch();
    }
}

mg_is_magma( player, weapon )
{
    return isdefined( player ) && isdefined( weapon ) && isdefined( player.mg_magma ) && is_true( player.mg_magma[weapon] );
}

mg_weapon_grant( player, weapon )
{
    if ( !isdefined( player ) || !isdefined( weapon ) )
        return;

    if ( !isdefined( player.mg_magma ) )
        player.mg_magma = [];

    player.mg_magma[weapon] = 1;
    player.mg_magma_any = 1;
    title = "Magmagat";

    if ( weapon == "blundergat_upgraded_zm" )
        title = "Magmus Operandi";

    player thread mg_hud_title( title, 3 );
    player mg_snd_player( "zmb_hellbox_arrive" );
    mg_debug_print( "MG: " + player.name + " holds a " + title + " (" + weapon + ")" );
}

// self = player. Shots, Pack-a-Punch carry-over, loss of the weapon.
mg_weapon_player_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( is_true( self.mg_weapon_watched ) )
        return;

    self.mg_weapon_watched = 1;
    self.mg_balls = 0;
    self thread mg_weapon_shot_loop();

    while ( true )
    {
        wait 0.5;

        if ( !isdefined( self.mg_magma ) )
            continue;

        // Pack-a-Punch: the plain flag moves to the upgraded name when the Sweeper appears
        if ( is_true( self.mg_magma["blundergat_zm"] ) && !self hasweapon( "blundergat_zm" ) && self hasweapon( "blundergat_upgraded_zm" ) )
        {
            self.mg_magma["blundergat_zm"] = 0;
            self.mg_magma["blundergat_upgraded_zm"] = 1;
            self thread mg_hud_title( "Magmus Operandi", 3 );
        }

        // both gone (box swap, wall buy, death without Tombstone): the personality is lost
        any = 0;

        foreach ( name, on in self.mg_magma )
        {
            if ( is_true( on ) && self hasweapon( name ) )
                any = 1;
        }

        if ( !any && is_true( self.mg_magma_any ) )
        {
            self.mg_magma = [];
            self.mg_magma_any = 0;
            mg_debug_print( "MG: " + self.name + " lost the Magmagat" );
        }
    }
}

// self = player
mg_weapon_shot_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    while ( true )
    {
        self waittill( "weapon_fired", weapon );

        if ( !mg_is_magma( self, weapon ) )
            continue;

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

// self = the craftable trigger vanilla is validating (_zm_craftables / zm_alcatraz_utility call
// `trigger [[ level.custom_craftable_validation ]]( player )`). Vanilla's own hook runs first; then only the
// Acid Gat station (targetname blundergat_upgrade) refuses a Magmagat (spec section 4).
mg_acid_station_validation( player )
{
    if ( isdefined( level.mg_prev_craftable_validation ) )
    {
        if ( !( self [[ level.mg_prev_craftable_validation ]]( player ) ) )
            return 0;
    }

    if ( !isdefined( self.targetname ) || self.targetname != "blundergat_upgrade" )
        return 1;

    if ( !isdefined( player ) )
        return 1;

    weapon = mg_has_blundergat( player );

    if ( isdefined( weapon ) && mg_is_magma( player, weapon ) )
    {
        player thread mg_hud_title( "The forge already claimed this gun", 2 );
        player mg_snd_player( "zmb_quest_nixie_count" );
        return 0;
    }

    return 1;
}
