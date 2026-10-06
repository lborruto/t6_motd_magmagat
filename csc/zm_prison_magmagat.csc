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
