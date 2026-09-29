#!/usr/bin/perl
# Bakes a BO3 paint tint into a T6 colour map. BO3 tints a painted prop in the material: its colour map's alpha is the
# paint mask (255 on the paint, 0 on rust and bare metal) and the material's colour constant multiplies the painted
# part; T6 samples the colour map alone, so the tint is baked here (alpha comes out 255):
#   out = lerp( rgb, rgb * tint, alpha )
# The tint is the constant as sRGB factors (BO3 stores it linear: s = 1.055 * l ^ (1 / 2.4) - 0.055).
#
#   perl tools/paint_mask.pl in.png out.png --tint 0.207,0.239,0.198
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use MgPng;
use Getopt::Long;

my $tint = '';
GetOptions( 'tint=s' => \$tint ) or die "paint_mask.pl: bad options\n";
my ( $in, $out ) = @ARGV;
my @tint = split /,/, $tint;
die "usage: paint_mask.pl in.png out.png --tint r,g,b\n" unless $in && $out && @tint == 3;

my $img = MgPng::read($in);
my $px = $img->{px};
for ( my $i = 0; $i < @$px; $i += 4 ) {
    my $a = $px->[ $i + 3 ] / 255;
    for my $c ( 0 .. 2 ) {
        my $v = $px->[ $i + $c ] * ( 1 + ( $tint[$c] - 1 ) * $a );
        $px->[ $i + $c ] = $v > 255 ? 255 : int( $v + 0.5 );
    }
    $px->[ $i + 3 ] = 255;
}
MgPng::write( $out, $img );
printf "paint_mask.pl: %s -> %s (%dx%d, tint %s)\n", $in, $out, $img->{w}, $img->{h}, $tint;
