#!/usr/bin/perl
# Builds the Magmagat fastfile mod (mod/zone_source/mod.zone -> mod/out/mod.ff) with OpenAssetTools' Linker and
# installs it where Plutonium's Mods menu finds it:
#   %LOCALAPPDATA%\Plutonium\storage\t6\mods\zm_magmagat\mod.ff (+ mod.json)
# The zm_prison and common_zm zones are loaded first, so our assets can reuse their techsets, materials and images
# (a material we copy from a vanilla template keeps its techniqueSet reference).
#
#   perl tools/build_mod.pl            build + install (tools/deploy.pl installs the scripts beside it)
#   perl tools/build_mod.pl --no-install
# mod/props, mod/weapon and mod/sound must exist: tools/import_all.pl, tools/build_weapon.pl and tools/import_sounds.pl
# write them. The sound bank comes out as mod.all.sabl / mod.all.sabs beside mod.ff: they are installed with it.
# mod.json gets the version of mg_main.gsc (level.mg_version), written to mod/out/mod.json.
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
-d 'props' or die "build_mod.pl: no mod/props: run perl tools/import_all.pl first\n";
-d 'weapon' or die "build_mod.pl: no mod/weapon: run perl tools/build_weapon.pl first\n";
-d 'sound' or die "build_mod.pl: no mod/sound: run perl tools/import_sounds.pl first\n";
my @cmd = ( "$oat/Linker.exe", '--base-folder', '.', '--output-folder', 'out',
    '--load', "$zones/common_zm.ff", '--load', "$zones/zm_prison.ff",
    '--add-asset-search-path', '?base?/props;?base?/weapon;?base?/sound', 'mod' );
system(@cmd) == 0 or die "build_mod.pl: the Linker failed (exit " . ( $? >> 8 ) . ")\n";
-f 'out/mod.ff' or die "build_mod.pl: no out/mod.ff after the build\n";
printf "build_mod.pl: mod/out/mod.ff, %d bytes\n", -s 'out/mod.ff';
my ($version) = do { open my $h, '<', "$repo/mg_main.gsc" or die "build_mod.pl: no mg_main.gsc\n"; local $/; <$h> } =~ /level\.mg_version\s*=\s*"([^"]+)"/;
die "build_mod.pl: no level.mg_version in mg_main.gsc\n" unless $version;
{
    open my $h, '<', 'mod.json' or die "build_mod.pl: no mod/mod.json\n";
    local $/;
    my $j = <$h>;
    $j =~ s/("version"\s*:\s*")[^"]*"/$1$version"/ or die "build_mod.pl: mod.json has no version\n";
    open my $o, '>', 'out/mod.json' or die "build_mod.pl: out/mod.json: $!\n";
    print $o $j;
}
exit 0 unless $install;

my $local = $ENV{LOCALAPPDATA} or die "build_mod.pl: LOCALAPPDATA is not set\n";
my $dest = "$local/Plutonium/storage/t6/mods/zm_magmagat";
make_path($dest);
copy( 'out/mod.ff', "$dest/mod.ff" ) or die "build_mod.pl: copy failed: $!\n";
for my $bank (qw(mod.all.sabl mod.all.sabs)) {
    copy( "out/$bank", "$dest/$bank" ) or die "build_mod.pl: copy of $bank failed: $!\n";
}
copy( 'out/mod.json', "$dest/mod.json" ) or die "build_mod.pl: copy of mod.json failed: $!\n";
print "build_mod.pl: installed to $dest (pick \"zm_magmagat\" in the Mods menu, then load Mob of the Dead)\n";
