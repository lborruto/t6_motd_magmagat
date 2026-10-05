#!/usr/bin/perl
# The forge's ghouls' materials, mc/mg_ghoul_<part>: Mob's own Afterlife ghost, the shader its ghostly hands are drawn
# with in Afterlife (mc/mtl_viewarm_zom_ghost, techset mc_sw4_3d_char_ghost2_noscript: see-through, a blue inside and
# rim glow, scrolling sparkle swatches), on each of BO4's ghoul parts with its own normal map (BO4's ghoul is drawn by
# a ghost shader of its own, which T6 does not have: its colour maps are a flat grey). The template, its techset and
# its swatches are so_zclassic_zm_prison's, which Mob loads and tools/build_mod.pl loads too.
#
#   perl tools/build_ghoul_mats.pl <out raw dir> <work dir> <BO4 ximages dir>      (tools/import_all.pl runs it)
# Env: MG_OAT (OpenAssetTools folder), MG_BO2 (the BO2 install).
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use JSON::PP;
use File::Path qw(make_path);
use MgPng;
use MgDds;

my ( $raw, $work, $xi ) = @ARGV;
die "usage: build_ghoul_mats.pl <out raw dir> <work dir> <BO4 ximages dir>\n" unless $raw && $work && $xi;
sub slurp { my $f = shift; open my $h, '<:raw', $f or die "build_ghoul_mats.pl: $f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; open my $h, '>:raw', $f or die "build_ghoul_mats.pl: $f: $!\n"; print $h $s; close $h }
# a texture is in the ximages folder, or in the ghoul model's own _images/<material>/ (Greyhound puts some there)
sub png {
    my $n = shift;
    my ($f) = grep { -f $_ } "$xi/$n.png", glob("$xi/../xmodels/c_t8_zmb_mob_ghoul_body1/_images/*/$n.png");
    die "build_ghoul_mats.pl: $n.png is not in $xi nor the ghoul's _images\n" unless $f;
    MgPng::read($f);
}

# the template, dumped once from so_zclassic_zm_prison.ff
my $dump = "$work/ghost_dump";
my $tmpl_file = "$dump/materials/mc/mtl_viewarm_zom_ghost.json";
if ( !-f $tmpl_file ) {
    my $oat = $ENV{MG_OAT} // 'C:/Games/t6/openassettools';
    my $bo2 = $ENV{MG_BO2} // 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops II';
    system( "$oat/Unlinker.exe", '--include-assets', 'material', '-o', $dump, "$bo2/zone/all/so_zclassic_zm_prison.ff" ) == 0
        or die "build_ghoul_mats.pl: the so_zclassic_zm_prison dump failed\n";
    -f $tmpl_file or die "build_ghoul_mats.pl: no mc/mtl_viewarm_zom_ghost in so_zclassic_zm_prison.ff\n";
}
my $tmpl = decode_json( slurp($tmpl_file) );
make_path( "$raw/images", "$raw/materials/mc" );
my $json = JSON::PP->new->pretty->canonical;

sub material {    # (part, its normal map: an image name or a png to embed)
    my ( $part, $normal ) = @_;
    if ( ref $normal ) {
        MgDds::write( "$raw/images/_mg_ghoul_${part}_n.dds", $normal, 'bc5' );
        $normal = "*mg_ghoul_${part}_n";
    }
    my $m = decode_json( encode_json($tmpl) );
    # the editor's preview map goes (sw_radiant_default is in no zone the Linker loads; the game does not draw it)
    $m->{textures} = [ grep { $_->{name} ne 'radiantDiffuseMap' } @{ $m->{textures} } ];
    $_->{image} = $normal for grep { $_->{name} eq 'Normal_Map' } @{ $m->{textures} };    # the swatches: vanilla's
    spit( "$raw/materials/mc/mg_ghoul_$part.json", $json->encode($m) );
}

material( $_, png("i_c_t8_zmb_mob_ghoul_${_}_n") ) for qw(torso head shirt arms sleeves);
material( 'eyes', 'global_normal_flat_16x16' );
print "build_ghoul_mats.pl: 6 materials, mc/mg_ghoul_* (Mob's Afterlife ghost)\n";
