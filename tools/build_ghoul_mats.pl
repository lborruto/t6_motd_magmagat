#!/usr/bin/perl
# The forge's ghouls' materials, mc/mg_ghoul_<part>: BO4's ghoul (c_t8_zmb_mob_ghoul_body*) is drawn by a ghost shader
# T6 does not have: its colour maps are a flat light grey whose alpha is the cloth / flesh mask, and its look is in its
# glow maps (_e), tinted blue by the shader. So each part goes on the Acid Gat's emberglow shader (as the Magmagat's
# lava, tools/build_magmagat_model.pl), with BO4's own maps: a dark blue body from the mask, the glow map lit pale blue
# and flickering, its normal map. The eyes take BO4's eye glow the same way.
#
#   perl tools/build_ghoul_mats.pl <out raw dir> <zm_prison dump dir> <BO4 ximages dir>      (tools/import_all.pl runs it)
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use JSON::PP;
use File::Path qw(make_path);
use MgPng;
use MgDds;

my ( $raw, $dump, $xi ) = @ARGV;
die "usage: build_ghoul_mats.pl <out raw dir> <zm_prison dump dir> <BO4 ximages dir>\n" unless $raw && $dump && $xi;
sub slurp { my $f = shift; open my $h, '<:raw', $f or die "build_ghoul_mats.pl: $f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; open my $h, '>:raw', $f or die "build_ghoul_mats.pl: $f: $!\n"; print $h $s; close $h }
# a texture is in the ximages folder, or in the ghoul model's own _images/<material>/ (Greyhound puts some there)
sub png {
    my $n = shift;
    my ($f) = grep { -f $_ } "$xi/$n.png", glob("$xi/../xmodels/c_t8_zmb_mob_ghoul_body1/_images/*/$n.png");
    die "build_ghoul_mats.pl: $n.png is not in $xi nor the ghoul's _images\n" unless $f;
    MgPng::read($f);
}
sub map_px {    # (image, fn(r, g, b, a) -> (r, g, b, a)) -> a new image
    my ( $img, $fn ) = @_;
    my @src = @{ $img->{px} };
    my @px;
    for ( my $i = 0; $i < @src; $i += 4 ) { push @px, map { my $v = int( $_ + 0.5 ); $v < 0 ? 0 : $v > 255 ? 255 : $v } $fn->( @src[ $i .. $i + 3 ] ) }
    return { w => $img->{w}, h => $img->{h}, px => \@px };
}
sub lum { 0.3 * $_[0] + 0.59 * $_[1] + 0.11 * $_[2] }
my $glow = sub { my $t = lum(@_) / 255; ( 45 * $t**2.2, 120 * $t**1.3, 255 * $t**0.6, 255 ) };    # deep blue -> pale blue

my $tmpl = decode_json( slurp("$dump/materials/mc/mtl_t6_wpn_zmb_blundergat_acid.json") );
my %const = ( Emissiver_Amount => 6, Flicker_Min => 0.7, Flicker_Max => 1.25, Heat_Scale => 1, Ember_Scale => 1,
    Heat_Direction => [ 0.02, 0.05 ], Ember_Direction => [ 0, 0.03 ] );
make_path( "$raw/images", "$raw/materials/mc" );
my $json = JSON::PP->new->pretty->canonical;

sub material {
    my ( $part, %img ) = @_;
    my %name;
    for my $slot ( sort keys %img ) {
        my ( $image, $format ) = @{ $img{$slot} };
        next unless ref $image;
        ( my $k = lc $slot ) =~ s/_map$//;
        $name{$slot} = "*mg_ghoul_${part}_$k";
        MgDds::write( "$raw/images/_mg_ghoul_${part}_$k.dds", $image, $format );
    }
    $name{$_} = $img{$_}[0] for grep { !ref $img{$_}[0] } keys %img;    # an engine image, by name
    my $m = decode_json( encode_json($tmpl) );
    for my $t ( @{ $m->{textures} } ) { $t->{image} = $name{ $t->{name} } if defined $t->{name} && exists $name{ $t->{name} } }    # heat map, rim mask: vanilla
    for my $c ( @{ $m->{constants} || [] } ) {
        my $v = $const{ $c->{name} } // next;
        my @v = ref $v ? @$v : ($v);
        $c->{literal}[$_] = $v[$_] for 0 .. $#v;
    }
    spit( "$raw/materials/mc/mg_ghoul_$part.json", $json->encode($m) );
}

my $spec = { w => 4, h => 4, px => [ ( 20, 26, 40, 70 ) x 16 ] };
for my $part (qw(torso head shirt arms sleeves)) {
    my $c = png("i_c_t8_zmb_mob_ghoul_${part}_c");
    my $e = png("i_c_t8_zmb_mob_ghoul_${part}_e");
    material( $part,
        Diffuse_Map => [ map_px( $c, sub { my $a = $_[3] / 255; ( 6 + 14 * $a, 10 + 24 * $a, 22 + 50 * $a, 255 ) } ), 'bc1' ],
        Ember_Map => [ map_px( $e, $glow ), 'bc1' ],
        EmberGlow_Reveal_Map => [ map_px( $e, sub { my $l = lum(@_); ( $l, $l, $l, 255 ) } ), 'bc1' ],
        Normal_Map => [ png("i_c_t8_zmb_mob_ghoul_${part}_n"), 'bc5' ],
        SpecularAndGloss => [ $spec, 'bc3' ] );
}
my $eye = png('i_mtl_c_t8_zmb_eye_glow');
material( 'eyes',
    Diffuse_Map => [ { w => 4, h => 4, px => [ ( 4, 8, 20, 255 ) x 16 ] }, 'bc1' ],
    Ember_Map => [ map_px( $eye, $glow ), 'bc1' ],
    EmberGlow_Reveal_Map => [ map_px( $eye, sub { my $l = lum(@_); ( $l, $l, $l, 255 ) } ), 'bc1' ],
    Normal_Map => [ 'global_normal_flat_16x16' ],
    SpecularAndGloss => [ $spec, 'bc3' ] );
print "build_ghoul_mats.pl: 6 materials, mc/mg_ghoul_*\n";
