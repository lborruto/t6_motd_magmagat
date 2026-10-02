#!/usr/bin/perl
# Builds the release: ONE folder the player drops into %LOCALAPPDATA%\Plutonium\storage\t6\mods\, plus its zip.
#   release/mods/zm_magmagat/mod.ff                              props, Magmagat weapons, effects (tools/build_mod.pl)
#   release/mods/zm_magmagat/mod.json                            name, author, description, version
#   release/mods/zm_magmagat/mod.all.sabl, mod.all.sabs         the sound bank (the BO3 remaster's sounds)
#   release/mods/zm_magmagat/scripts/zm/zm_prison/zm_prison_magmagat*.gsc   the quest (tools/pack.pl)
#   release/zm_magmagat-<version>.zip                           mods\zm_magmagat, for the player's t6 folder
# mod/props, mod/weapon, mod/sound and mod/fx must be built first (tools/import_all.pl, tools/build_weapon.pl,
# tools/import_sounds.pl, tools/bo3_fx.pl): tools/build_mod.pl links them.
#
#   perl tools/release.pl
use strict;
use warnings;
use FindBin;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);

my $repo = "$FindBin::Bin/..";
my $rel = "$repo/release";
my $mods = "$rel/mods";
my $dir = "$mods/zm_magmagat";
my $scripts = "$dir/scripts/zm/zm_prison";
sub winpath { my $p = shift; return $p if $p =~ /^[A-Za-z]:/; chomp( my $w = `cygpath -m "$p"` ); $w }

system( 'perl', "$FindBin::Bin/build_mod.pl", '--no-install' ) == 0 or die "release.pl: build_mod.pl failed\n";
my ($version) = do { open my $h, '<', "$repo/mod/out/mod.json" or die "release.pl: no mod/out/mod.json\n"; local $/; <$h> } =~ /"version"\s*:\s*"([^"]+)"/;

remove_tree($mods);
make_path($scripts);
copy( "$repo/mod/out/mod.ff", "$dir/mod.ff" ) or die "release.pl: mod.ff: $!\n";
copy( "$repo/mod/out/mod.json", "$dir/mod.json" ) or die "release.pl: mod.json: $!\n";
for my $bank (qw(mod.all.sabl mod.all.sabs)) {
    copy( "$repo/mod/out/$bank", "$dir/$bank" ) or die "release.pl: $bank: $!\n";
}

# one packed file if it fits, else two, else three (as tools/deploy.pl)
my $parts = 0;
for my $n ( 1 .. 3 ) {
    if ( system( 'perl', "$FindBin::Bin/pack.pl", '--out', "$scripts/zm_prison_magmagat.gsc", '--parts', $n ) == 0 ) {
        $parts = $n;
        last;
    }
    unlink glob("$scripts/zm_prison_magmagat*.gsc");
}
die "release.pl: the scripts did not pack\n" unless $parts;

my $zip = "$rel/zm_magmagat-$version.zip";
unlink $zip;
system( 'powershell', '-NoProfile', '-Command', "Compress-Archive -Path '" . winpath($mods) . "' -DestinationPath '" . winpath($zip) . "'" ) == 0
    or die "release.pl: zip failed\n";
printf "release.pl: %s (%d script file(s)), %s (%.1f MB)\n", $dir, $parts, $zip, ( -s $zip ) / 1048576;
