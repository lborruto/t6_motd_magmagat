#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include scripts\zm\zm_prison\mg_systems;
#include scripts\zm\zm_prison\mg_coords;
#include scripts\zm\zm_prison\mg_quest;
#include scripts\zm\zm_prison\mg_hearth;
#include scripts\zm\zm_prison\mg_run;
#include scripts\zm\zm_prison\mg_forge;
#include scripts\zm\zm_prison\mg_weapon;
#include scripts\zm\zm_prison\mg_debug;

// Magmagat for Mob of the Dead (Plutonium T6, zm_prison). Entry point, boot order, `!mg` chat commands.
init()
{
    if ( !isdefined( level.script ) || level.script != "zm_prison" )
        return;

    if ( isdefined( level.mg_active ) )
        return;

    level.mg_active = 1;
    level.mg_version = "1.0.2";
    mg_fx_init();
    mg_precache();
    mg_weapon_precache();
    level thread mg_boot();
}

mg_boot()
{
    level endon( "end_game" );
    flag_wait( "start_zombie_round_logic" );
    mg_coords_init();
    level thread mg_systems_boot();
    mg_quest_init();
    mg_hearth_init();
    mg_run_init();
    mg_forge_init();
    mg_weapon_init();
    mg_debug_init();
    level thread mg_chat_listener();
    print( "[MG] Magmagat " + level.mg_version + " loaded\n" );
}

mg_chat_listener()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "say", message, player );

        if ( !isdefined( player ) || !isplayer( player ) || !isdefined( message ) )
            continue;

        if ( message.size < 3 || tolower( getsubstr( message, 0, 3 ) ) != "!mg" )
            continue;

        if ( getdvarint( "mg_debug" ) != 1 )
        {
            player mg_out( "MG: debug commands need console `set mg_debug 1`" );
            continue;
        }

        args = strtok( message, " " );
        sub = "help";
        arg = undefined;

        if ( args.size > 1 )
            sub = tolower( args[1] );

        if ( args.size > 2 )
            arg = args[2];

        player thread mg_command( sub, arg, args );
    }
}

// self = the player who typed
mg_command( sub, arg, args )
{
    self endon( "disconnect" );

    switch ( sub )
    {
        case "status":
            foreach ( line in mg_status_lines() )
                self mg_out( line );

            return;

        case "goto":
            if ( !isdefined( arg ) )
            {
                self mg_out( "Usage: !mg goto <locked|ready|souls|pickup|run|forge|done>" );
                return;
            }

            self mg_goto( tolower( arg ) );
            return;

        case "spots":
            foreach ( key in mg_coords_keys() )
                self mg_out( mg_coord_line( key ) );

            return;

        case "help":
            self mg_help();
            return;
    }

    if ( self mg_debug_command( sub, arg, args ) )
        return;

    self mg_out( "MG: unknown command `!mg " + sub + "`" );
    self mg_help();
}

mg_help()
{
    self mg_out( "!mg commands (chat, needs `set mg_debug 1`; every answer is also a [MG] console line):" );
    self mg_out( "  status | goto <locked|ready|souls|pickup|run|forge|done> | spots | help" );
    self mg_out( "  tour (every step's effects and sounds, in place) | lockdown (the blue walls and door clip, 10 s) | zone (the souls' kill zone marked, 15 s) | bridge (meet the bridge requirement) | give (a Blundergat) | magma (the gun in hand becomes its Magmagat) | shock (zap every shock box and panel now) | shock gun (pistol zaps what you shoot)" );
    self mg_out( "  fx [<n>|<name>|next|prev|stop] | snd [<n>|<name>|next|prev]" );
    self mg_out( "  grab <KEY> (prop follows your crosshair; FIRE place, MELEE cancel, ADS freeze, 1/2 turn, 3/4 raise, F surface/float) | drop | cancel | rot <deg> | up <units> | show [KEY] | hide | tp <KEY>" );
}
