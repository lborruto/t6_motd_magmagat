#!/usr/bin/perl
# The lava material, mc/mg_lava: the BO3 remaster's own lava (i_pbr_lava_magma_emissive_1_mtl: rock colour, molten
# emission, normal) on the Acid Gat's emberglow shader, which flickers and scrolls the heat. The Magmagat's blob and the
# remaster's magma splats wear it (tools/import_all.pl --material: their BO3 shader is procedural).
#
#   perl tools/gen_lava_mat.pl <out raw dir> <zm_prison dump dir>      (tools/build_weapon.pl runs it)
# Env: MG_GREYHOUND (the Greyhound folder).
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use JSON::PP;
use File::Path qw(make_path);
use MgPng;
use MgDds;

my ( $raw, $dump ) = @ARGV;
die "usage: gen_lava_mat.pl <out raw dir> <zm_prison dump dir>\n" unless $raw && $dump;
my $gh = $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0';
my $xi = "$gh/exported_files/black_ops_3/ximages";
sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; ( my $d = $f ) =~ s{/[^/]+$}{}; make_path($d); open my $h, '>:raw', $f or die "$f: $!\n"; print $h $s; close $h }
my $json = JSON::PP->new->pretty->canonical;

sub png { my $n = shift; my $f = "$xi/$n.png"; die "gen_lava_mat.pl: $n.png is not in $xi\n" unless -f $f; MgPng::read($f) }
make_path("$raw/images");
my $col = png('i_pbr_lava_magma_emissive_1_mtl_c');
my $emi = png('i_pbr_lava_magma_emissive_1_mtl_e');
MgDds::write( "$raw/images/_mg_lava_c.dds", $col, 'bc1' );
MgDds::write( "$raw/images/_mg_lava_e.dds", $emi, 'bc1' );
MgDds::write( "$raw/images/_mg_lava_n.dds", png('i_pbr_lava_magma_emissive_1_mtl_n'), 'bc5' );
{    # the glow shows where the emission is bright
    my @px = @{ $emi->{px} };
    for ( my $i = 0; $i < @px; $i += 4 ) { my $l = int( 0.3 * $px[$i] + 0.59 * $px[ $i + 1 ] + 0.11 * $px[ $i + 2 ] ); @px[ $i .. $i + 2 ] = ( $l, $l, $l ) }
    MgDds::write( "$raw/images/_mg_lava_reveal.dds", { %$emi, px => \@px }, 'bc1' );
    MgDds::write( "$raw/images/_mg_lava_s.dds", { w => 4, h => 4, px => [ ( 30, 22, 18, 90 ) x 16 ] }, 'bc3' );
}
my $mat = decode_json( slurp("$dump/materials/mc/mtl_t6_wpn_zmb_blundergat_acid.json") );
my %img = ( Diffuse_Map => '*mg_lava_c', Ember_Map => '*mg_lava_e', EmberGlow_Reveal_Map => '*mg_lava_reveal', Normal_Map => '*mg_lava_n',
    SpecularAndGloss => '*mg_lava_s' );
for my $t ( @{ $mat->{textures} } ) { $t->{image} = $img{ $t->{name} } if defined $t->{name} && exists $img{ $t->{name} } }
my %lava = ( Emissiver_Amount => 20, Flicker_Min => 0.55, Flicker_Max => 1.5, Heat_Scale => 2, Ember_Scale => 1,
    Heat_Direction => [ 0.06, 0.1 ], Ember_Direction => [ -0.04, -0.07 ] );
for my $c ( @{ $mat->{constants} || [] } ) {
    my $v = $lava{ $c->{name} } // next;
    my @v = ref $v ? @$v : ($v);
    $c->{literal}[$_] = $v[$_] for 0 .. $#v;
}
spit( "$raw/materials/mc/mg_lava.json", $json->encode($mat) );
