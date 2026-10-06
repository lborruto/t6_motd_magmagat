// Mob of the Dead's own client script for the Acid Gat's dart (vanilla's, plutoniummod/t6-scripts
// ZM/Maps/Mob of the Dead/clientscripts/mp/zombies/_zm_weap_blundersplat.csc), carried in mod.ff (tools/build_mod.pl
// compiles it) with one addition: the Tempered Blundergat's flame in first person. A server script can't put an
// effect on the view model, so this client script does it as the remaster does (_zm_weap_magmagat.csc
// function_b92b7bda): while the tempered gun is in hand, its blue flame replays on tag_muzzle_acid every 0.1 s.
// Others see the flame on the world model (mg_run.gsc).
#include clientscripts\mp\_utility;
#include clientscripts\mp\_fx;
#include clientscripts\mp\_music;
#include clientscripts\mp\_audio;

init()
{
    level._effect["dart_light"] = loadfx( "weapon/crossbow/fx_trail_crossbow_blink_grn_os" );
    level._effect["mg_tempered_flame"] = loadfx( "mg/fx_alcatraz_blue_flame_vm" );
    level thread mg_tempered_flame_start();
}

spawned( localclientnum )
{
    player = getlocalplayer( localclientnum );
    enemy = 0;
    self.fxtagname = "tag_origin";

    if ( self.team != player.team )
        enemy = 1;

    self thread loop_local_sound( localclientnum, "wpn_blundersplat_alert", 0.3, level._effect["dart_light"] );
    self thread sndfuseloop();
}

loop_local_sound( localclientnum, alias, interval, fx )
{
    self endon( "entityshutdown" );
    wait 0.1;

    while ( true )
    {
        n_id = playfxontag( localclientnum, fx, self, self.fxtagname );
        wait( interval );
        stopfx( localclientnum, n_id );
        interval = interval / 1.2;

        if ( interval < 0.1 )
            interval = 0.1;
    }
}

sndfuseloop()
{
    location = self.origin;
    soundloopemitter( "wpn_blundersplat_fuse", location );
    self waittill( "entityshutdown" );
    soundstoploopemitter( "wpn_blundersplat_fuse", location );
}

// a watcher per local client (split screen has more than one)
mg_tempered_flame_start()
{
    waitforallclients();

    for ( i = 0; i < getlocalplayers().size; i++ )
        level thread mg_tempered_flame( i );
}

mg_tempered_flame( localclientnum )
{
    while ( true )
    {
        // as vanilla's polls (_zm_weap_thundergun.csc): no weapon to read before the client has a snapshot
        while ( !clienthassnapshot( localclientnum ) )
            wait 0.05;

        weapon = getcurrentweapon( localclientnum );

        if ( weapon == "mg_tempered_zm" || weapon == "mg_tempered_upgraded_zm" )
            playviewmodelfx( localclientnum, level._effect["mg_tempered_flame"], "tag_muzzle_acid" );

        wait 0.1;
    }
}
