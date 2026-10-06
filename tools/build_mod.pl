#!/usr/bin/perl
# Builds the Magmagat fastfile mod (mod/zone_source/mod.zone -> mod/out/mod.ff) with OpenAssetTools' Linker and
# installs it where Plutonium's Mods menu finds it:
#   %LOCALAPPDATA%\Plutonium\storage\t6\mods\zm_magmagat\mod.ff (+ mod.json)
# The zm_prison and common_zm zones are loaded first, so our assets can reuse their techsets, materials and images
# (a material we copy from a vanilla template keeps its techniqueSet reference), and so_zclassic_zm_prison, which
# holds the Afterlife ghost shader the forge's ghouls wear (tools/build_ghoul_mats.pl; Mob loads it too).
#
#   perl tools/build_mod.pl            build + install (tools/deploy.pl installs the scripts beside it)
#   perl tools/build_mod.pl --no-install
# mod/props, mod/weapon, mod/sound and mod/fx must exist: tools/import_all.pl, tools/build_weapon.pl,
# tools/import_sounds.pl and tools/bo3_fx.pl write them. The sound bank comes out as mod.all.sabl / mod.all.sabs beside mod.ff: they are installed with it.
# mod.json gets the version of mg_main.gsc (level.mg_version), written to mod/out/mod.json.
#
# mod/fx (tools/bo3_fx.pl) holds the BO3 effects: they need the mod's OpenAssetTools build, whose Linker loads T6
# effects (upstream's has no effect loader; docs/PORTING_BO3_ASSETS.md).
#
# csc/ holds client scripts carried in mod.ff (compiled with gsc-tool, MG_GSC_TOOL).
#
# Env overrides: MG_OAT_FX (that OpenAssetTools build), MG_BO2 (the BO2 install), MG_GSC_TOOL (gsc-tool.exe).
use strict;
use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);
use FindBin;

my $repo = "$FindBin::Bin/..";
my $install = !grep { $_ eq '--no-install' } @ARGV;
my $oat = $ENV{MG_OAT_FX} // 'C:/Games/t6/oat-src/build/bin/Release_x86';
my $bo2 = $ENV{MG_BO2} // 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops II';
my $zones = "$bo2/zone/all";
my $gsc_tool = $ENV{MG_GSC_TOOL} // 'C:/Games/t6/gsc-tools/gsc-tool.exe';

die "build_mod.pl: no Linker at $oat/Linker.exe (set MG_OAT_FX)\n" unless -f "$oat/Linker.exe";
die "build_mod.pl: no BO2 zones at $zones (set MG_BO2)\n" unless -f "$zones/zm_prison.ff";

chdir "$repo/mod" or die "build_mod.pl: no mod/ folder\n";
-d 'props' or die "build_mod.pl: no mod/props: run perl tools/import_all.pl first\n";
-d 'weapon' or die "build_mod.pl: no mod/weapon: run perl tools/build_weapon.pl first\n";
-d 'sound' or die "build_mod.pl: no mod/sound: run perl tools/import_sounds.pl first\n";
-d 'fx' or die "build_mod.pl: no mod/fx: run perl tools/bo3_fx.pl first\n";

# the client scripts (csc/): compiled with gsc-tool into mod/csc at their asset path (the bytecode holds no name of
# its own: the zone names it) and listed in the zone's client script block (the asset type is "script")
my @csc = map { s{^\Q$repo\E/csc/}{}r } grep { -f } glob("$repo/csc/clientscripts/*/*/*.csc $repo/csc/clientscripts/*/*.csc");
remove_tree('csc');
for my $c (@csc) {
    my $base = $c =~ s{^.*/}{}r;
    remove_tree('compiled');
    system( $gsc_tool, '-m', 'comp', '-g', 't6', '-s', 'pc', '-i', 'client', "$repo/csc/$c" ) == 0
        or die "build_mod.pl: gsc-tool failed on csc/$c\n";
    -f "compiled/t6/$base" or die "build_mod.pl: no compiled csc/$c\n";
    make_path( 'csc/' . ( $c =~ s{/[^/]+$}{}r ) );
    copy( "compiled/t6/$base", "csc/$c" ) or die "build_mod.pl: $c: $!\n";
    remove_tree('compiled');
}
my $zf = 'zone_source/mod.zone';
my $z = do { open my $h, '<:raw', $zf or die "$zf: $!\n"; local $/; <$h> };
$z =~ s/\r\n/\n/g;
my $block = "// client scripts (tools/build_mod.pl, from csc/)\n" . join( '', map { "script,$_\n" } @csc ) . "// end client scripts\n";
if ( $z !~ s/\/\/ client scripts \(tools\/build_mod\.pl, from csc\/\).*?\/\/ end client scripts\n/$block/s ) { $z =~ s/\s*\z/\n/; $z .= "\n$block" }
open my $zh, '>:raw', $zf or die "build_mod.pl: $zf: $!\n";
print $zh $z;
close $zh;

my @cmd = ( "$oat/Linker.exe", '--base-folder', '.', '--output-folder', 'out',
    '--load', "$zones/common_zm.ff", '--load', "$zones/zm_prison.ff", '--load', "$zones/so_zclassic_zm_prison.ff",
    '--add-asset-search-path', '?base?/props;?base?/weapon;?base?/sound;?base?/fx;?base?/csc', 'mod' );
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
