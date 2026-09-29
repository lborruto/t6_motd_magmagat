#!/usr/bin/perl
# Rebuilds every BO3 prop the mod ships from the Greyhound export, then the zone's xmodel list:
# mod/props is generated (from game files, so never committed) and never edited by hand.
#
#   perl tools/import_all.pl
# Env: MG_GREYHOUND (the Greyhound folder).
use strict;
use warnings;
use FindBin;
use File::Path qw(make_path remove_tree);

my $gh = $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0';
my $xm = "$gh/exported_files/black_ops_3_sp/xmodels";
my $xi = "$gh/exported_files/black_ops_3/ximages";
my $repo = "$FindBin::Bin/..";
my $raw = "$repo/mod/props";
my $work = "$repo/mod/work";

# The blue barrels of the temper run: BO3 paints this one with two tiled layers through a mask, T6 gets them baked.
my $blue = "$xm/p7_slu_barrel_metal_02_blue_dmg";
my $blue_layers = "$blue/_images/mtl_p7_slu_barrel_metal_02_dmg_blue";
my @bakes = (
    [ "$work/mg_barrel_blue_c.png",
        '--mask', "$xi/i_mtl_p7_slu_barrel_metal_02_dmg_m.png",
        '--base', "$blue_layers/i_t7_micro_metal_painted_02_c.png",
        '--top', "$blue_layers/i_t7_micro_metal_rust_heavy_01_c.png",
        '--tint', '0.30,0.48,0.78', '--tile', '4' ],
);

# [ our xmodel, BO3 model, importer options ]
my @props = (
    [ 'mg_barrel_blue', 'p7_slu_barrel_metal_02_blue_dmg',
        '--skip', 'transparency', '--skip', 'decal', '--color', "dmg_blue=$work/mg_barrel_blue_c.png" ],
    [ 'mg_skull', 'p7_zm_zod_skull' ],
);

system( 'perl', "$FindBin::Bin/dump_game.pl" ) == 0 or die "import_all.pl: the dump failed\n";    # the material template
remove_tree($raw);
make_path($work);
for my $b (@bakes) {
    my ( $out, @opt ) = @$b;
    system( 'perl', "$FindBin::Bin/bake_layers.pl", @opt, '--out', $out ) == 0 or die "import_all.pl: bake $out failed\n";
}

for my $p (@props) {
    my ( $name, $model, @opt ) = @$p;
    system( 'perl', "$FindBin::Bin/import_prop.pl", @opt, "$xm/$model", $name, $xi ) == 0 or die "import_all.pl: $name failed\n";
}

# the zone: our props block replaces the previous one
my $zone = "$repo/mod/zone_source/mod.zone";
open my $h, '<:raw', $zone or die "$zone: $!\n";
my $z = do { local $/; <$h> };
close $h;
$z =~ s/\n?\/\/ props \(tools\/import_all\.pl\).*?\/\/ end props\n//s;
$z =~ s/\s*\z/\n/;
$z .= "\n// props (tools/import_all.pl)\n" . join( '', map { "xmodel,$_->[0]\n" } @props ) . "// end props\n";
open $h, '>:raw', $zone or die "$zone: $!\n";
print $h $z;
close $h;
printf "import_all.pl: %d props\n", scalar @props;
