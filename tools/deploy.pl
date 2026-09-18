#!/usr/bin/perl
# deploy.pl - install Magmagat into the game folder.
#
#   perl tools/deploy.pl                packed: ONE file if it fits, else two, else three (tools/pack.pl decides)
#   perl tools/deploy.pl --parts N      force N packed files
#   perl tools/deploy.pl --multi        the sources side by side (development install: !mg debug)
#   perl tools/deploy.pl --game DIR     install somewhere else
#
# Game folder: %localappdata%\Plutonium\storage\t6\scripts\zm\zm_prison
# Plutonium auto-loads every *.gsc in that folder, so the layouts must never coexist: each mode removes what the
# others installed (two copies of a function = a fatal duplicate at load).
#
# Why "one file if it fits": a T6 script addresses every function and import name as a 16-bit offset into its
# string block, so that block cannot pass 65535 bytes (measured with tools/gsc_header.pl on the compiled binary;
# over it the game reads names from the wrong place and refuses the file). pack.pl refuses an oversized file
# (exit 3); this tool then packs the same sources as two files, then three.
use strict;
use warnings;
use File::Basename qw(dirname basename);
use File::Copy qw(copy);
use File::Spec;

my $tools = dirname( File::Spec->rel2abs( $0 ) );
my $repo  = dirname( $tools );

my $local = $ENV{LOCALAPPDATA};
die "deploy.pl: LOCALAPPDATA is not set (this tool installs into %LOCALAPPDATA%\\Plutonium\\storage\\t6)\n" unless defined $local && length $local;
$local =~ s/\x5c/\//g;

my $game = "$local/Plutonium/storage/t6/scripts/zm/zm_prison";
my $packed_base = 'zm_prison_magmagat';
my $mode = 'single';
my $forced_parts = 0;

for ( my $i = 0; $i < @ARGV; $i++ ) {
    my $a = $ARGV[$i];
    if    ( $a eq '--multi' )  { $mode = 'multi' }
    elsif ( $a eq '--single' ) { $mode = 'single' }
    elsif ( $a eq '--parts' && defined $ARGV[$i+1] ) { $mode = 'single'; $forced_parts = int( $ARGV[++$i] ) }
    elsif ( $a eq '--game' && defined $ARGV[$i+1] )  { $game = $ARGV[++$i]; $game =~ s/\x5c/\//g }
    else  { die "deploy.pl: unknown option $a\n" }
}

die "deploy.pl: game folder not found: $game\n" unless -d $game;

my @sources = sort glob("$repo/mg_*.gsc");
die "deploy.pl: no mg_*.gsc in $repo\n" unless @sources;

# everything this tool may have installed before
sub clean_game {
    my $n = 0;

    for my $f ( glob("$game/mg_*.gsc"), glob("$game/$packed_base*.gsc") ) {
        unlink $f and $n++;
    }

    return $n;
}

if ( $mode eq 'multi' ) {
    my $removed = clean_game();
    my $copied = 0;

    for my $f ( @sources ) {
        copy( $f, "$game/" . basename($f) ) or die "deploy.pl: cannot copy $f: $!\n";
        $copied++;
    }

    print "deploy.pl: multi-file mode: $copied source(s) installed, $removed old file(s) removed\n";
    print "deploy.pl: in game: set mg_debug 1, then chat !mg status\n";
    exit 0;
}

# packed: stage in release/, only touch the game folder once a pack succeeded
my $stage = "$repo/release";
unlink $_ for glob("$stage/$packed_base*.gsc");

my @try = $forced_parts > 0 ? ( $forced_parts ) : ( 1, 2, 3 );
my $ok_parts = 0;

for my $parts ( @try ) {
    my $rc = system( 'perl', "$tools/pack.pl", '--out', "$stage/$packed_base.gsc", '--parts', $parts );

    if ( $rc == 0 ) {
        $ok_parts = $parts;
        last;
    }

    unlink $_ for glob("$stage/$packed_base*.gsc");
    print "deploy.pl: $parts file(s) did not fit, trying " . ( $parts + 1 ) . "\n" if $parts < 3 && $forced_parts == 0;
}

if ( !$ok_parts ) {
    print "deploy.pl: pack failed for every layout, the game folder was left alone\n";
    exit 1;
}

my @packed = sort glob("$stage/$packed_base*.gsc");
my $removed = clean_game();

for my $f ( @packed ) {
    copy( $f, "$game/" . basename($f) ) or die "deploy.pl: cannot copy $f: $!\n";
}

printf "deploy.pl: packed mode: %d file(s) installed (%s), %d old file(s) removed\n",
    scalar @packed, join( ', ', map { basename($_) } @packed ), $removed;
print "deploy.pl: in game: set mg_debug 1, then chat !mg status\n";
exit 0;
