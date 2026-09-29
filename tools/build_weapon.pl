#!/usr/bin/perl
# Builds the Magmagat weapons into mod/weapon (generated from game files, so never committed) from BO2's own
# Blundergat: every animation and sound stays the Blundergat's (no tool turns BO3 animations into T6 ones), the look,
# the effects and the name change:
#   magmagat_zm           = blundergat_zm with the lava tanks shown (the Acid Gat's tank tags), a charred body
#   magmagat_upgraded_zm  = blundergat_upgraded_zm (the Sweeper, armour attached) in the same colours: Magmus Operandi
# Steps: dump zm_prison once (tools/dump_game.pl, into mod/work/dump),
# recolour the Blundergat textures (tools/recolor.pl), clone its materials / xmodels / weapon files under our names
# (lava glow turned up on the emberglow materials, fire muzzle flashes, BO2's red LMG tracer on every pellet:
# OpenAssetTools loads no new tracer), write the display names (english/localizedstrings/mg_weapons.str) and the
# zone lines.
#
#   perl tools/build_weapon.pl [--redump]
# Env: MG_OAT, MG_BO2 (see tools/dump_game.pl).
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

# 2. textures: [ source image, our image, recolor.pl options ]
my @recolors = (
    [ '~-gmtl_t6_wpn_zmb_blundergat_col', 'mg_magmagat_col', '--sat', '0.45', '--gain', '0.75', '--tint', '1.25,0.82,0.62' ],
    [ '~-gmtl_t6_wpn_zmb_blundergat_acid_col', 'mg_magmagat_tank_col', '--hue', '120:18', '--sat', '0.9', '--tint', '1.2,0.62,0.42' ],
    [ 'mtl_t6_wpn_zmb_blundergat_acid_ember', 'mg_magmagat_ember', '--hue', '120:20' ],
    [ '~-gmtl_t6_wpn_zmb_blundergat_armor_col', 'mg_magmagat_armor_col', '--sat', '0.6', '--tint', '1.2,0.8,0.65' ],
    [ 'mtl_t6_wpn_zmb_blundergat_armor_ember', 'mg_magmagat_armor_ember', '--hue', '120:20' ],
);
my %image_of;    # vanilla image -> ours ('*' = embedded in mod.ff)
for my $r (@recolors) {
    my ( $src, $ours, @opt ) = @$r;
    my $dds = "$raw/images/_$ours.dds";
    make_path("$raw/images");
    system( 'perl', "$FindBin::Bin/recolor.pl", "$dump/images/$src.dds", $dds, @opt ) == 0 or die "build_weapon.pl: recolour of $src failed\n";
    $image_of{$src} = "*$ours";
}

# 3. materials: the Blundergat's, under our names, with our images (the rest - normal, gloss, masks - stay vanilla)
my %material_of = (
    'mc/mtl_t6_wpn_zmb_blundergat' => 'mc/mtl_mg_magmagat',
    'mc/mtl_t6_wpn_zmb_blundergat_acid' => 'mc/mtl_mg_magmagat_tank',
    'mc/mtl_t6_wpn_zmb_blundergat_armor' => 'mc/mtl_mg_magmagat_armor',
    'mc/mtl_t6_wpn_zmb_blundergat_armor_ember' => 'mc/mtl_mg_magmagat_armor_ember',
);
# the emberglow shader (the Acid Gat's tanks) flickers and scrolls its heat map: hotter, livelier lava
my %lava = ( Emissiver_Amount => 16, Flicker_Min => 0.6, Flicker_Max => 1.45, Heat_Scale => 1.8,
    Heat_Direction => [ 0.05, 0.08 ], Ember_Direction => [ -0.03, -0.06 ] );
for my $src ( sort keys %material_of ) {
    my $m = decode_json( slurp("$dump/materials/$src.json") );
    for my $t ( @{ $m->{textures} } ) { $t->{image} = $image_of{ $t->{image} } // $t->{image} }
    for my $c ( @{ $m->{constants} || [] } ) {
        my $v = $lava{ $c->{name} } // next;
        my @v = ref $v ? @$v : ($v);
        $c->{literal}[$_] = $v[$_] for 0 .. $#v;
    }
    spit( "$raw/materials/$material_of{$src}.json", $json->encode($m) );
}

# 4. xmodels: same meshes and bones, our materials
my %model_of = (
    t6_wpn_zmb_blundergat_view => 'mg_magmagat_view',
    t6_wpn_zmb_blundergat_world => 'mg_magmagat_world',
    t6_wpn_zmb_blundergat_armor_view => 'mg_magmagat_armor_view',
    t6_wpn_zmb_blundergat_armor_world => 'mg_magmagat_armor_world',
);
for my $src ( sort keys %model_of ) {
    my $ours = $model_of{$src};
    my $x = decode_json( slurp("$dump/xmodel/$src.json") );
    for my $k ( 0 .. $#{ $x->{lods} } ) {
        my $g = decode_json( slurp("$dump/$x->{lods}[$k]{file}") );
        $_->{name} = $material_of{ $_->{name} } // $_->{name} for @{ $g->{materials} };
        my $file = "model_export/${ours}_lod$k.gltf";
        spit( "$raw/$file", encode_json($g) );
        $x->{lods}[$k]{file} = $file;
    }
    spit( "$raw/xmodel/$ours.json", $json->encode($x) );
}

# 5. weapon files: [ ours, the vanilla one it copies, field overrides ]; the effects are zm_prison's own (no new fx can be
#    built): the orange buckshot flashes, lmg_enemy = the thick red tracer, drawn for every pellet
my $tank_tags = join "\n", qw(j_ammo_ri_bo j_ammo_ri_up j_ammo_le_bo j_ammo_le_up tag_muzzle tag_barrel_le_in tag_barrel_ri_in);
my @weapons = (
    [ 'magmagat_zm', 'blundergat_zm', { displayName => 'ZMWEAPON_MAGMAGAT', gunModel => 'mg_magmagat_view',
        worldModel => 'mg_magmagat_world', hideTags => $tank_tags, tracerType => 'lmg_enemy',
        viewFlashEffect => 'weapon/muzzleflashes/fx_muz_lg_gas_flash_buck_1p',
        worldFlashEffect => 'weapon/muzzleflashes/fx_muz_lg_gas_flash_buck_3p' } ],
    [ 'magmagat_upgraded_zm', 'blundergat_upgraded_zm', { displayName => 'ZMWEAPON_MAGMAGAT_UPGRADED', gunModel => 'mg_magmagat_view',
        worldModel => 'mg_magmagat_world', attachViewModel6 => 'mg_magmagat_armor_view', attachWorldModel6 => 'mg_magmagat_armor_world',
        hideTags => "$tank_tags\ntag_sights", tracerType => 'lmg_enemy',
        viewFlashEffect => 'weapon/muzzleflashes/fx_muz_xlg_gas_flash_1p',
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
my @lines = ( 'localize,mg_weapons', ( map { "xmodel,$_" } sort values %model_of ),
    ( map { "weapon,$_->[0]" } @weapons ) );
$z =~ s/\s*\z/\n/;
$z .= "\n// weapon (tools/build_weapon.pl)\n" . join( "\n", @lines ) . "\n// end weapon\n";
spit( $zone, $z );
printf "build_weapon.pl: %d weapons, %d models, %d materials, %d textures\n", scalar @weapons, scalar keys %model_of,
    scalar keys %material_of, scalar @recolors;
