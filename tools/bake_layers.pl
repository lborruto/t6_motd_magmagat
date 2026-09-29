#!/usr/bin/perl
# Bakes a BO3 two-layer material into one T6 colour map. BO3 blends a tiled "micro" base layer (paint) and a tiled
# top layer (rust) through a per-model mask on the model's own UVs; T6 samples one colour map, so the blend is
# done here, in the mask's UV space:
#   out(u, v) = lerp( base(u * tile, v * tile) * tint, top(u * tile, v * tile), mask(u, v) )
#
#   perl tools/bake_layers.pl --mask m.png --base paint_c.png --top rust_c.png --out baked.png [--tint 0.40,0.62,0.95] [--tile 4]
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use MgPng;
use Getopt::Long;

my ( $mask_f, $base_f, $top_f, $out, $tint, $tile ) = ( '', '', '', '', '1,1,1', 4 );
GetOptions( 'mask=s' => \$mask_f, 'base=s' => \$base_f, 'top=s' => \$top_f, 'out=s' => \$out, 'tint=s' => \$tint, 'tile=f' => \$tile )
    && $mask_f && $base_f && $top_f && $out
    or die "usage: bake_layers.pl --mask m.png --base paint.png --top rust.png --out baked.png [--tint r,g,b] [--tile n]\n";
my @tint = split /,/, $tint;
die "bake_layers.pl: --tint takes three factors\n" unless @tint == 3;

my ( $m, $b, $t ) = map { MgPng::read($_) } $mask_f, $base_f, $top_f;
my ( $w, $h ) = @$m{qw(w h)};
my @out;
for my $y ( 0 .. $h - 1 ) {
    my $v = ( $y + 0.5 ) / $h * $tile;
    my $by = int( ( $v - int $v ) * $b->{h} );
    my $ty = int( ( $v - int $v ) * $t->{h} );
    for my $x ( 0 .. $w - 1 ) {
        my $u = ( $x + 0.5 ) / $w * $tile;
        my $bo = ( $by * $b->{w} + int( ( $u - int $u ) * $b->{w} ) ) * 4;
        my $to = ( $ty * $t->{w} + int( ( $u - int $u ) * $t->{w} ) ) * 4;
        my $k = $m->{px}[ ( $y * $w + $x ) * 4 ] / 255;
        for my $c ( 0 .. 2 ) {
            my $base = $b->{px}[ $bo + $c ] * $tint[$c];
            my $v = $base + ( $t->{px}[ $to + $c ] - $base ) * $k;
            push @out, $v > 255 ? 255 : int( $v + 0.5 );
        }
        push @out, 255;
    }
}
MgPng::write( $out, { w => $w, h => $h, px => \@out } );
printf "bake_layers.pl: %s (%dx%d, tile %g, tint %s)\n", $out, $w, $h, $tile, $tint;
