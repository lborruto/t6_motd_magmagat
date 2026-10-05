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
use File::Copy qw(copy);
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
# and its colours: most of its materials draw a light-grey map or none, tinted by BO3 colour constants that Greyhound does
# not export, read from a BO3 snapshot taken by the machine (tools/bo3mem: Bo3Snapshot.exe mod/work/bo3mem/models.bin
# --models=p8_zm_esc_machinery_01; tools/model_tints.pl). Without it the machine comes out light grey.
my $models_snap = "$work/bo3mem/models.bin";
my $press_tints = "$work/tints_p8_zm_esc_machinery_01.tsv";
if ( -f $models_snap ) {
    system( 'perl', "$FindBin::Bin/model_tints.pl", $models_snap, 'p8_zm_esc_machinery_01', $press_tints ) == 0 or die "import_all.pl: the press tints failed\n";
    push @press_decals, '--tints', $press_tints;
}
else { warn "import_all.pl: no $models_snap: the forge machine keeps Greyhound's untinted maps\n" }
my @props = (
    # the temper run's drums: the remaster stands this one at each of its five str_barrel_fire spots (only the flame is blue)
    [ 'mg_barrel_green', 'p7_zm_gen_barrel_metal_55gal_green_drk_lod', '--offset', '0,0,-22.37', '--color', "green_drk=$work/i_mtl_p7_barrel_metal_55gal_green_drk_c.png" ],    # p6_zm_al_wood_barrel_01 pivots at mid height
    [ 'mg_skull', 'p7_zm_zod_skull', '--offset', '0,0,-3.51' ],    # BO2's own skull mesh; p6_zm_al_skull pivots at its centre
    # the lava splat meshes the remaster's magma effects throw (tools/bo3_fx.pl names them mg_<BO3 name>), and BO4's lava
    # blob: their BO3 shader is procedural, so they take the mod's own lava (mc/mg_lava, the BO3 lava texture)
    [ 'mg_fx_magma_splat02_mesh', 'fx_magma_splat02_mesh', '--material', 'mc/mg_lava' ],
    [ 'mg_fx_magma_splat03_mesh', 'fx_magma_splat03_mesh', '--material', 'mc/mg_lava' ],
    [ 'mg_magma_blob', 'p8_fxp_magma_blob', '--material', 'mc/mg_lava', '--scale', '0.65' ],    # 65 %: the owner's call
    # the remaster's press (p8_zm_esc_machinery_01) in two parts, so script plays its animations: the body and the ram
    # (j_press: 74.5 cm down onto the bed and back; the model has no mesh on its lever bone)
    [ 'mg_press_body', 'p8_zm_esc_machinery_01', '--bones', '!j_press,j_switch', @press_decals ],
    [ 'mg_press_ram', 'p8_zm_esc_machinery_01', '--bones', 'j_press', @press_decals ],
);

# Black Ops 4's own forge, from its Blood of the Dead export (Greyhound, BO4 running on the map): the scene
# aib_vign_zm_mob_smelter_ghost (ate47/bo4-source, scriptbundle/scene) plays the smelter machine and two ghouls
# (aitype spawner_zm_ghost: c_t8_zmb_mob_ghoul1..3) together. The smelter itself is too big for the Generator Room and
# its BO4 materials do not carry over, so the remaster's press stays; it takes the smelter's lever, which BO4's press is
# the same machine as at 0.755 scale (its smasher and our ram are one mesh, 1136 triangles): the shaft handel_1_jnt
# and its two grips (handel_1/2_release_jnt), pivot at handel_1_jnt (100.71, 80.02, 59.49 in, BO4's centimetres / 2.54)
# moved to the origin. The ghouls are skinned (script plays their xanims); BO4's ghost shader does not exist in T6, so
# their parts wear Mob's Afterlife ghost with BO4's own normal maps (tools/build_ghoul_mats.pl, mc/mg_ghoul_<part>).
# Their ghost tail (below 30 in, the waist) is drawn to half its length and tapers to a wisp: Mob's ghost shader has no
# fade of its own to hide it with.
# Greyhound names an xanim it cannot resolve xanim_<fnv1a-64 of the name, 60 bits>; ours are named after the scene.
my $xm4 = "$gh/exported_files/black_ops_4_sp/xmodels";
my $xi4 = "$gh/exported_files/black_ops_4_sp/ximages";
my $xa4 = "$gh/exported_files/black_ops_4_sp/xanims";
my $lever_scale = 0.755;
my @bo4_props = (
    # the lever's materials are the press's (the two machines share them: xmaterial_88a8bd4005d4b05, ...), so it takes
    # the press's BO3 tints too; its grips drawn 2 units each closer to the middle (the owner's fit: 64.4 -> 62.4)
    [ 'mg_press_lever', 'p8_fxanim_zm_esc_smelter_ghost_mod', '--bones', 'handel_1_jnt,handel_1_release_jnt,handel_2_release_jnt', @press_decals,
        '--scale', $lever_scale, '--offset', join( ',', map { sprintf '%.3f', -$_ * $lever_scale } 100.71, 80.02, 59.49 ), '--stretch', '1,0.969,1' ],
    # BO4's mantle skulls (dvar mg_bo4 "skulls"): its quest stands three plain ones and swaps each for the Afterlife skull
    # as it fills (script_2ba3951675c7ee1c, function_9689b55c); that one is our remaster skull's mesh. Pivot at mid height, as mg_skull's.
    [ 'mg_skull_bo4', 'p8_zm_esc_skull_sgl', '--offset', '0,0,-3.51' ],
    [ 'mg_skull_bo4_lit', 'p8_zm_esc_skull_afterlife', '--offset', '0,0,-3.51' ],
    [ 'mg_ghoul1', 'c_t8_zmb_mob_ghoul_body1', '--skinned', '--tail', '30,0.5,0.35', '--material-rename', 'mtl_c_t8_zmb_mob_ghoul_(\w+)=mc/mg_ghoul_$1' ],
    [ 'mg_ghoul2', 'c_t8_zmb_mob_ghoul_body2', '--skinned', '--tail', '30,0.5,0.35', '--material-rename', 'mtl_c_t8_zmb_mob_ghoul_(\w+)=mc/mg_ghoul_$1' ],
);
my @bo4_anims = (    # [ our xanim, Greyhound's (Direct XAnim, BO1 compatibility: the version 19 OpenAssetTools reads) ]
    [ 'mg_ghoul_smelter_1', 'xanim_2d21557dbf41b9b' ],   # the scene's fakeactor 1, 11.4 s (the smelter's start: its levers at 3.4 s, its smasher down at 4.0 s)
    [ 'mg_ghoul_smelter_2', 'xanim_2d21657dbf41d4e' ],   # fakeactor 2
);

system( 'perl', "$FindBin::Bin/dump_game.pl" ) == 0 or die "import_all.pl: the dump failed\n";    # the material template
remove_tree($raw);
make_path($work);
for my $p (@paints) {
    my ( $out, $img, $tint ) = @$p;
    system( 'perl', "$FindBin::Bin/paint_mask.pl", "$xi/$img.png", $out, '--tint', $tint ) == 0 or die "import_all.pl: paint $out failed\n";
}

if ( -d $xi4 ) {
    system( 'perl', "$FindBin::Bin/build_ghoul_mats.pl", $raw, $work, $xi4 ) == 0 or die "import_all.pl: the ghouls' materials failed
";
}

# a model Greyhound exported empty (import_prop.pl exits 3) is left out; what uses it falls back on a vanilla one
my @built;
for my $p ( ( map { [ $xm, $xi, @$_ ] } @props ), ( map { [ $xm4, $xi4, @$_ ] } @bo4_props ) ) {
    my ( $models, $images, $name, $model, @opt ) = @$p;
    if ( !-d "$models/$model" ) { warn "import_all.pl: $name left out (no $model in $models)\n"; next }
    my $rc = system( 'perl', "$FindBin::Bin/import_prop.pl", @opt, "$models/$model", $name, $images ) >> 8;
    if ( $rc == 3 ) { warn "import_all.pl: $name left out ($model exported empty)\n"; next }
    $rc == 0 or die "import_all.pl: $name failed\n";
    push @built, $name;
}

# the xanims, as Greyhound wrote them: the Linker reads xanim/<name> from the search path
my @anims;
make_path("$raw/xanim");
for my $a (@bo4_anims) {
    my ( $name, $file ) = @$a;
    if ( !-f "$xa4/$file" ) { warn "import_all.pl: xanim $name left out (no $xa4/$file)\n"; next }
    copy( "$xa4/$file", "$raw/xanim/$name" ) or die "import_all.pl: xanim $name: $!\n";
    push @anims, $name;
}

# Script models all share ONE animtree (scriptmodelsuseanimtree is global, server and client), and Mob's own scripts
# set it to fxanim_props (its fan trap, the gondola chains): ours join that tree rather than replace it. mod.ff
# carries patch_zm's animtrees/fxanim_props.atr with ours appended (patch_zm's is the full one: common_zm's lacks Mob's
# own, zm_prison.ff only references it, and a tree without Mob's refuses the map: "animation
# 'fxanim_zom_al_bodybag_crane_anim' not defined in anim tree 'fxanim_props'"). mod.ff loads after both and overrides
# them, so #using_animtree("fxanim_props") resolves ours (an animtree is the list of the xanims it may play, by name).
my $atr;
if (@anims) {
    my $oat = $ENV{MG_OAT} // 'C:/Games/t6/openassettools';
    my $bo2 = $ENV{MG_BO2} // 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops II';
    my $rawdump = "$work/rawfile_patch_zm";
    my $vanilla = "$rawdump/animtrees/fxanim_props.atr";
    if ( !-f $vanilla ) {
        system( "$oat/Unlinker.exe", '--include-assets', 'rawfile', '-o', $rawdump, "$bo2/zone/all/patch_zm.ff" ) == 0 or die "import_all.pl: the rawfile dump failed\n";
        -f $vanilla or die "import_all.pl: no animtrees/fxanim_props.atr in patch_zm.ff\n";
    }
    open my $vh, '<:raw', $vanilla or die "$vanilla: $!\n";
    my $tree = do { local $/; <$vh> };
    close $vh;
    $tree =~ s/\r\n/\n/g;
    $tree =~ s/\s*\z/\n\n/;
    $tree .= "//MAGMAGAT (zm_magmagat: BO4's forge)\n" . join( '', map { "$_\n" } @anims );
    make_path("$raw/animtrees");
    open my $th, '>:raw', "$raw/animtrees/fxanim_props.atr" or die "import_all.pl: animtree: $!\n";
    print $th $tree;
    close $th;
    $atr = 'animtrees/fxanim_props.atr';
}

# the zone: our props block replaces the previous one
my $zone = "$repo/mod/zone_source/mod.zone";
open my $h, '<:raw', $zone or die "$zone: $!\n";
my $z = do { local $/; <$h> };
$z =~ s/\r\n/\n/g;    # a checkout may hand it over with CRLF endings
close $h;
my $block = "// props (tools/import_all.pl)\n" . join( '', map { "xmodel,$_\n" } @built ) . join( '', map { "xanim,$_\n" } @anims )
    . ( $atr ? "rawfile,$atr\n" : '' ) . "// end props\n";
# in place when the block exists (the zone keeps its order), else appended
if ( $z !~ s/\/\/ props \(tools\/import_all\.pl\).*?\/\/ end props\n/$block/s ) { $z =~ s/\s*\z/\n/; $z .= "\n$block" }
open $h, '>:raw', $zone or die "$zone: $!\n";
print $h $z;
close $h;
printf "import_all.pl: %d props, %d xanims\n", scalar @built, scalar @anims;
