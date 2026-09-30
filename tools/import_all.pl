#!/usr/bin/perl
# Rebuilds every prop the mod ships (the BO3 remaster's models and BO4's p8_* ones it carries) from the Greyhound
# export, then the zone's xmodel list:
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

# BO3 paint tints to bake into the colour map ([ out png, source ximage, sRGB tint ]): the green drum's material
# (mc/mtl_p7_barrel_metal_55gal_green_drk) tints its paint mask by linear (0.0352, 0.0467, 0.0325)
my @paints = ( [ "$work/i_mtl_p7_barrel_metal_55gal_green_drk_c.png", 'i_mtl_p7_barrel_metal_55gal_blue_c', '0.207,0.239,0.198' ] );

# [ our xmodel, BO3 model, importer options ]. The owner's anchors were placed with the vanilla props these replace, so
# each mesh is moved to put its pivot where that prop had it (the BO3 models pivot at their base).
# the press's decal layers (rust grunge, dirt, bolts, truck decals): BO3 blends them over the machine, T6's lit
# template would draw them as opaque patches
my @press_decals = ( '--skip-color', 'decal|grunge|dirty' );
my @props = (
    # the temper run's drums: the remaster stands this one at each of its five str_barrel_fire spots (only the flame is blue)
    [ 'mg_barrel_green', 'p7_zm_gen_barrel_metal_55gal_green_drk_lod', '--offset', '0,0,-22.37', '--color', "green_drk=$work/i_mtl_p7_barrel_metal_55gal_green_drk_c.png" ],    # p6_zm_al_wood_barrel_01 pivots at mid height
    [ 'mg_skull', 'p7_zm_zod_skull', '--offset', '0,0,-3.51' ],    # BO2's own skull mesh; p6_zm_al_skull pivots at its centre
    # the lava splat meshes the remaster's magma effects throw (tools/bo3_fx.pl names them mg_<BO3 name>), and BO4's lava
    # blob: their BO3 shader is procedural, so they take the mod's own lava (mc/mg_lava, the BO3 lava texture)
    [ 'mg_fx_magma_splat02_mesh', 'fx_magma_splat02_mesh', '--material', 'mc/mg_lava' ],
    [ 'mg_fx_magma_splat03_mesh', 'fx_magma_splat03_mesh', '--material', 'mc/mg_lava' ],
    [ 'mg_magma_blob', 'p8_fxp_magma_blob', '--material', 'mc/mg_lava' ],
    # the remaster's press (p8_zm_esc_machinery_01) in two parts, so script plays its animations: the body and the ram
    # (j_press: 74.5 cm down onto the bed and back; the model has no mesh on its lever bone)
    [ 'mg_press_body', 'p8_zm_esc_machinery_01', '--bones', '!j_press,j_switch', @press_decals ],
    [ 'mg_press_ram', 'p8_zm_esc_machinery_01', '--bones', 'j_press', @press_decals ],
);

system( 'perl', "$FindBin::Bin/dump_game.pl" ) == 0 or die "import_all.pl: the dump failed\n";    # the material template
remove_tree($raw);
make_path($work);
for my $p (@paints) {
    my ( $out, $img, $tint ) = @$p;
    system( 'perl', "$FindBin::Bin/paint_mask.pl", "$xi/$img.png", $out, '--tint', $tint ) == 0 or die "import_all.pl: paint $out failed\n";
}

# a model Greyhound exported empty (import_prop.pl exits 3) is left out; what uses it falls back on a vanilla one
my @built;
for my $p (@props) {
    my ( $name, $model, @opt ) = @$p;
    my $rc = system( 'perl', "$FindBin::Bin/import_prop.pl", @opt, "$xm/$model", $name, $xi ) >> 8;
    if ( $rc == 3 ) { warn "import_all.pl: $name left out ($model exported empty)\n"; next }
    $rc == 0 or die "import_all.pl: $name failed\n";
    push @built, $p;
}

# the zone: our props block replaces the previous one
my $zone = "$repo/mod/zone_source/mod.zone";
open my $h, '<:raw', $zone or die "$zone: $!\n";
my $z = do { local $/; <$h> };
$z =~ s/\r\n/\n/g;    # a checkout may hand it over with CRLF endings
close $h;
my $block = "// props (tools/import_all.pl)\n" . join( '', map { "xmodel,$_->[0]\n" } @built ) . "// end props\n";
# in place when the block exists (the zone keeps its order), else appended
if ( $z !~ s/\/\/ props \(tools\/import_all\.pl\).*?\/\/ end props\n/$block/s ) { $z =~ s/\s*\z/\n/; $z .= "\n$block" }
open $h, '>:raw', $zone or die "$zone: $!\n";
print $h $z;
close $h;
printf "import_all.pl: %d props\n", scalar @built;
