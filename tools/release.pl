#!/usr/bin/perl
# Builds the release: ONE folder the player drops into %LOCALAPPDATA%\Plutonium\storage\t6\mods\, plus its zip.
#   release/mods/zm_magmagat/mod.ff                              props, Magmagat weapons, effects (tools/build_mod.pl)
#   release/mods/zm_magmagat/mod.json                            name, author, description, version
#   release/mods/zm_magmagat/mod.all.sabl, mod.all.sabs         the sound bank (BO4's Magmagat sounds, the remaster's quest sounds)
#   release/mods/zm_magmagat/scripts/zm/zm_prison/zm_prison_magmagat*.gsc   the quest (tools/pack.pl)
#   release/mods/zm_magmagat/scripts/zm/zm_prison/zm_prison_magmagat.csc    the client script (csc/)
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
die "release.pl: no version in mod/out/mod.json\n" unless $version;

remove_tree($mods);
make_path($scripts);
copy( "$repo/mod/out/mod.ff", "$dir/mod.ff" ) or die "release.pl: mod.ff: $!\n";
copy( "$repo/mod/out/mod.json", "$dir/mod.json" ) or die "release.pl: mod.json: $!\n";
for my $bank (qw(mod.all.sabl mod.all.sabs)) {
    copy( "$repo/mod/out/$bank", "$dir/$bank" ) or die "release.pl: $bank: $!\n";
}

# one packed file if it fits, else two, else three (as tools/deploy.pl; a duplicate function name, pack.pl's exit 2,
# stops at once)
my $parts = 0;
for my $n ( 1 .. 3 ) {
    if ( system( 'perl', "$FindBin::Bin/pack.pl", '--out', "$scripts/zm_prison_magmagat.gsc", '--parts', $n ) == 0 ) {
        $parts = $n;
        last;
    }
    unlink glob("$scripts/zm_prison_magmagat*.gsc");
    last if ( $? >> 8 ) == 2;
}
die "release.pl: the scripts did not pack\n" unless $parts;

# every name a pack may use, the unused ones as empty placeholders: a player copies the new release on top of the old
# one, and an old release's part this one no longer uses would load beside it (its functions twice: a fatal duplicate)
for my $n ( '', '_1', '_2', '_3' ) {
    my $f = "$scripts/zm_prison_magmagat$n.gsc";
    next if -f $f;
    open my $h, '>', $f or die "release.pl: $f: $!\n";
    print $h "// Magmagat $version: empty on purpose, it replaces a script part an older release had\n";
    close $h;
}

# the client script, beside them: Plutonium runs it on the client
for my $c ( glob("$repo/csc/*.csc") ) {
    copy( $c, "$scripts/" . ( $c =~ s{.*/}{}r ) ) or die "release.pl: $c: $!\n";
}

my $zip = "$rel/zm_magmagat-$version.zip";
unlink $zip;
system( 'powershell', '-NoProfile', '-Command', "Compress-Archive -Path '" . winpath($mods) . "' -DestinationPath '" . winpath($zip) . "'" ) == 0
    or die "release.pl: zip failed\n";
printf "release.pl: %s (%d script file(s)), %s (%.1f MB)\n", $dir, $parts, $zip, ( -s $zip ) / 1048576;
