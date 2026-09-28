#!/usr/bin/perl
# Builds the Magmagat fastfile mod (mod/zone_source/mod.zone -> mod/out/mod.ff) with OpenAssetTools' Linker and
# installs it where Plutonium's Mods menu finds it:
#   %LOCALAPPDATA%\Plutonium\storage\t6\mods\zm_magmagat\mod.ff (+ mod.json)
# The zm_prison and common_zm zones are loaded first, so our assets can reuse their techsets, materials and images
# (a material we copy from a vanilla template keeps its techniqueSet reference).
#
#   perl tools/build_mod.pl            build + install
#   perl tools/build_mod.pl --no-install
#
# Env overrides: MG_OAT (the OpenAssetTools folder), MG_BO2 (the BO2 install).
use strict;
use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path);
use FindBin;

my $repo = "$FindBin::Bin/..";
my $install = !grep { $_ eq '--no-install' } @ARGV;
my $oat = $ENV{MG_OAT} // 'C:/Games/t6/openassettools';
my $bo2 = $ENV{MG_BO2} // 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops II';
my $zones = "$bo2/zone/all";

die "build_mod.pl: no Linker at $oat/Linker.exe (set MG_OAT)\n" unless -f "$oat/Linker.exe";
die "build_mod.pl: no BO2 zones at $zones (set MG_BO2)\n" unless -f "$zones/zm_prison.ff";

chdir "$repo/mod" or die "build_mod.pl: no mod/ folder\n";
my @cmd = ( "$oat/Linker.exe", '--base-folder', '.', '--output-folder', 'out',
    '--load', "$zones/common_zm.ff", '--load', "$zones/zm_prison.ff", 'mod' );
system(@cmd) == 0 or die "build_mod.pl: the Linker failed (exit " . ( $? >> 8 ) . ")\n";
-f 'out/mod.ff' or die "build_mod.pl: no out/mod.ff after the build\n";
printf "build_mod.pl: mod/out/mod.ff, %d bytes\n", -s 'out/mod.ff';
exit 0 unless $install;

my $local = $ENV{LOCALAPPDATA} or die "build_mod.pl: LOCALAPPDATA is not set\n";
my $dest = "$local/Plutonium/storage/t6/mods/zm_magmagat";
make_path($dest);
copy( 'out/mod.ff', "$dest/mod.ff" ) or die "build_mod.pl: copy failed: $!\n";
copy( 'mod.json', "$dest/mod.json" ) if -f 'mod.json';
print "build_mod.pl: installed to $dest (pick \"zm_magmagat\" in the Mods menu, then load Mob of the Dead)\n";
