#!/usr/bin/perl
# Builds the Magmagat weapons into mod/weapon (generated from game files, so never committed):
#   magmagat_zm           the real BO4 Magmagat model (tools/build_magmagat_model.pl) on BO2's Blundergat rig, so it
#                         plays the Blundergat's animations; its lava tanks are the Acid Gat's bones, shown
#   magmagat_upgraded_zm  the Magmus Operandi: the same model with the BO4 armour kit
# Steps: dump zm_prison once (tools/dump_game.pl, into mod/work/dump); the BO4 view models and the near world models
# with their materials (tools/build_magmagat_model.pl); the lava ball and pool meshes (tools/gen_lava_fx.pl); the far
# world LODs (1, 2) are BO2's Blundergat recoloured (tools/recolor.pl); the weapon files copy the Blundergat's
# (animations, sounds) with our models, fire muzzle flashes and BO2's red LMG tracer on every pellet (OpenAssetTools
# loads no new fx or tracer); the display names (english/localizedstrings/mg_weapons.str) and the zone lines.
#
#   perl tools/build_weapon.pl [--redump]
# Env: MG_OAT, MG_BO2 (see tools/dump_game.pl), MG_GREYHOUND (see tools/build_magmagat_model.pl).
use strict;
use warnings;
use FindBin;
use File::Path qw(make_path remove_tree);
use JSON::PP;

my $redump = grep { $_ eq '--redump' } @ARGV;
my $repo = "$FindBin::Bin/..";
my $raw = "$repo/mod/weapon";
my $dump = "$repo/mod/work/dump";

sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; ( my $d = $f ) =~ s{/[^/]+$}{}; make_path($d); open my $h, '>:raw', $f or die "$f: $!\n"; print $h $s; close $h }
my $json = JSON::PP->new->pretty->canonical;

# 1. the dump (tools/dump_game.pl, once)
system( 'perl', "$FindBin::Bin/dump_game.pl", $redump ? '--redump' : () ) == 0 or die "build_weapon.pl: the dump failed\n";
remove_tree($raw);

# 2. the BO4 models, their materials and textures; the lava ball and pool meshes (BO4's effects are meshes too)
system( 'perl', "$FindBin::Bin/build_magmagat_model.pl", $raw, $dump ) == 0 or die "build_weapon.pl: the BO4 model failed\n";
system( 'perl', "$FindBin::Bin/gen_lava_fx.pl", $raw, $dump ) == 0 or die "build_weapon.pl: the lava meshes failed\n";

# 3. the far world LODs: BO2's Blundergat world model, recoloured. [ source image, our image, recolor.pl options ]
my @recolors = (
    [ '~-gmtl_t6_wpn_zmb_blundergat_col', 'mg_magmagat_col', '--sat', '0.45', '--gain', '0.75', '--tint', '1.25,0.82,0.62' ],
    [ '~-gmtl_t6_wpn_zmb_blundergat_acid_col', 'mg_magmagat_tank_col', '--hue', '120:18', '--sat', '0.9', '--tint', '1.2,0.62,0.42' ],
    [ 'mtl_t6_wpn_zmb_blundergat_acid_ember', 'mg_magmagat_ember', '--hue', '120:20' ],
);
my %image_of;    # vanilla image -> ours ('*' = embedded in mod.ff)
for my $r (@recolors) {
    my ( $src, $ours, @opt ) = @$r;
    make_path("$raw/images");
    system( 'perl', "$FindBin::Bin/recolor.pl", "$dump/images/$src.dds", "$raw/images/_$ours.dds", '--format', 'bc1', @opt ) == 0
        or die "build_weapon.pl: recolour of $src failed\n";
    $image_of{$src} = "*$ours";
}
my %material_of = ( 'mc/mtl_t6_wpn_zmb_blundergat' => 'mc/mtl_mg_magmagat', 'mc/mtl_t6_wpn_zmb_blundergat_acid' => 'mc/mtl_mg_magmagat_tank' );
for my $src ( sort keys %material_of ) {
    my $m = decode_json( slurp("$dump/materials/$src.json") );
    for my $t ( @{ $m->{textures} } ) { $t->{image} = $image_of{ $t->{image} } // $t->{image} }
    spit( "$raw/materials/$material_of{$src}.json", $json->encode($m) );
}
my $world = decode_json( slurp("$dump/xmodel/t6_wpn_zmb_blundergat_world.json") );
for my $k ( 1 .. $#{ $world->{lods} } ) {
    my $g = decode_json( slurp("$dump/$world->{lods}[$k]{file}") );
    $_->{name} = $material_of{ $_->{name} } // $_->{name} for @{ $g->{materials} };
    spit( "$raw/model_export/mg_magmagat_world_lod$k.gltf", encode_json($g) );
}

# 4. xmodels: the view models (one LOD, as the Blundergat's), the world models (BO4 near, recoloured BO2 far)
my $view = decode_json( slurp("$dump/xmodel/t6_wpn_zmb_blundergat_view.json") );
for my $ours (qw(mg_magmagat_view mg_magmus_view)) {
    my $x = decode_json( encode_json($view) );
    $x->{lods} = [ { distance => $view->{lods}[0]{distance}, file => "model_export/${ours}_lod0.gltf" } ];
    spit( "$raw/xmodel/$ours.json", $json->encode($x) );
}
for my $ours (qw(mg_magmagat_world mg_magmus_world)) {
    my $x = decode_json( encode_json($world) );
    $x->{lods}[0]{file} = "model_export/${ours}_lod0.gltf";
    $x->{lods}[$_]{file} = "model_export/mg_magmagat_world_lod$_.gltf" for 1 .. $#{ $x->{lods} };
    spit( "$raw/xmodel/$ours.json", $json->encode($x) );
}
my @models = qw(mg_magmagat_view mg_magmagat_world mg_magmus_view mg_magmus_world mg_lava_blob mg_lava_pool);

# 5. weapon files: [ ours, the vanilla one it copies, field overrides ]; the effects are zm_prison's own (no new fx can be
#    built): the orange buckshot flashes, lmg_enemy = the thick red tracer, drawn for every pellet. hideTags = the Acid
#    Gat's: the plain shells and muzzle go, the lava set (the acid bones) shows
my $tank_tags = join "\n", qw(j_ammo_ri_bo j_ammo_ri_up j_ammo_le_bo j_ammo_le_up tag_muzzle tag_barrel_le_in tag_barrel_ri_in);
my @weapons = (
    [ 'magmagat_zm', 'blundergat_zm', { displayName => 'ZMWEAPON_MAGMAGAT', gunModel => 'mg_magmagat_view',
        worldModel => 'mg_magmagat_world', hideTags => $tank_tags, tracerType => 'lmg_enemy',
        viewFlashEffect => 'weapon/muzzleflashes/fx_muz_lg_gas_flash_buck_1p',
        worldFlashEffect => 'weapon/muzzleflashes/fx_muz_lg_gas_flash_buck_3p' } ],
    [ 'magmagat_upgraded_zm', 'blundergat_upgraded_zm', { displayName => 'ZMWEAPON_MAGMAGAT_UPGRADED', gunModel => 'mg_magmus_view',
        worldModel => 'mg_magmus_world', attachViewModel6 => '', attachWorldModel6 => '', hideTags => "$tank_tags\ntag_sights",
        tracerType => 'lmg_enemy', viewFlashEffect => 'weapon/muzzleflashes/fx_muz_xlg_gas_flash_1p',
        worldFlashEffect => 'weapon/muzzleflashes/fx_muz_xlg_gas_flash_3p' } ],
);
for my $w (@weapons) {
    my ( $ours, $src, $set ) = @$w;
    my @kv = split /\\/, slurp("$dump/weapons/$src"), -1;
    my $magic = shift @kv;
    die "build_weapon.pl: $src is not a WEAPONFILE\n" unless $magic eq 'WEAPONFILE';
    my %left = %$set;
    for ( my $i = 0; $i < $#kv; $i += 2 ) {
        next unless exists $left{ $kv[$i] };
        $kv[ $i + 1 ] = delete $left{ $kv[$i] };
    }
    die "build_weapon.pl: $src has no field " . join( ', ', sort keys %left ) . "\n" if %left;
    spit( "$raw/weapons/$ours", join( '\\', $magic, @kv ) );
}

# 6. display names
my %names = ( ZMWEAPON_MAGMAGAT => 'Magmagat', ZMWEAPON_MAGMAGAT_UPGRADED => 'Magmus Operandi' );
my $str = qq{VERSION             "1"\nCONFIG              "C:\\\\trees\\\\cod3\\\\cod3\\\\bin\\\\StringEd.cfg"\nFILENOTES           "Magmagat mod"\n};
$str .= qq{\nREFERENCE           $_\nLANG_ENGLISH        "$names{$_}"\n} for sort keys %names;
$str .= "\nENDMARKER\n";
spit( "$raw/english/localizedstrings/mg_weapons.str", $str );

# 7. the zone: our weapon block replaces the previous one
my $zone = "$repo/mod/zone_source/mod.zone";
my $z = slurp($zone);
$z =~ s/\n?\/\/ weapon \(tools\/build_weapon\.pl\).*?\/\/ end weapon\n//s;
my @lines = ( 'localize,mg_weapons', ( map { "xmodel,$_" } @models ), ( map { "weapon,$_->[0]" } @weapons ) );
$z =~ s/\s*\z/\n/;
$z .= "\n// weapon (tools/build_weapon.pl)\n" . join( "\n", @lines ) . "\n// end weapon\n";
spit( $zone, $z );
printf "build_weapon.pl: %d weapons, %d models\n", scalar @weapons, scalar @models;
