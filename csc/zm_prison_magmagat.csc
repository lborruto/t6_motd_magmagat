// The Magmagat mod's client script, installed beside its server scripts (mods\zm_magmagat\scripts\zm\zm_prison\):
// Plutonium runs every *.csc there on the client, as it runs the *.gsc on the server. It only does what a server
// script can't: an effect on the view model. The Tempered Blundergat's flame burns at its muzzle in first person as
// the remaster's does (_zm_weap_magmagat.csc function_b92b7bda): while the tempered gun is in hand, its blue flame,
// a 1 s one-shot, replays on tag_muzzle_acid every 0.1 s. Others see it on the world model (mg_run.gsc).
#include clientscripts\mp\_utility;

init()
{
    level._effect["mg_tempered_flame"] = loadfx( "mg/fx_alcatraz_blue_flame_vm" );
    level thread mg_tempered_flame_start();
}

// a watcher per local client (split screen has more than one)
mg_tempered_flame_start()
{
    setdvar( "mg_csc", "started" );

    // the first client's snapshot (vanilla's waitforallclients waits on level.localplayers, which the map's own client
    // scripts set and this one, loaded beside them, never sees)
    while ( !clienthassnapshot( 0 ) )
        wait 0.05;

    n = getlocalplayers().size;

    if ( n < 1 )
        n = 1;

    setdvar( "mg_csc", "clients " + n );

    for ( i = 0; i < n; i++ )
        level thread mg_tempered_flame( i );
}

mg_tempered_flame( localclientnum )
{
    played = 0;

    while ( true )
    {
        // as vanilla's polls (_zm_weap_thundergun.csc): no weapon to read before the client has a snapshot
        while ( !clienthassnapshot( localclientnum ) )
            wait 0.05;

        weapon = getcurrentweapon( localclientnum );

        if ( weapon == "mg_tempered_zm" || weapon == "mg_tempered_upgraded_zm" )
        {
            playviewmodelfx( localclientnum, level._effect["mg_tempered_flame"], "tag_muzzle_acid" );
            played++;
        }

        // what it sees, for the console (type mg_csc): its effect, the weapon in hand, the flames played
        if ( localclientnum == 0 )
            setdvar( "mg_csc", "fx " + level._effect["mg_tempered_flame"] + " weapon " + weapon + " played " + played );

        wait 0.1;
    }
}
