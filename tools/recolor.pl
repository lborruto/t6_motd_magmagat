#!/usr/bin/perl
# Recolours a texture (DDS or PNG in, uncompressed DDS out) for the Magmagat's reskin of the Blundergat.
#   --hue FROM:TO   pixels whose hue is within 70 degrees of FROM turn to TO (e.g. the Acid Gat's green 120 -> lava 22)
#   --sat S         saturation factor, --gain G value factor, --tint R,G,B channel factors (applied last)
#   --format F      rgba (default), bc1, bc3 or bc5 (tools/MgDds.pm)
#
#   perl tools/recolor.pl in.dds out.dds [--hue 120:22] [--sat 0.5] [--gain 0.7] [--tint 1.2,0.8,0.6]
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use MgPng;
use MgDds;
use Getopt::Long;

my ( $hue, $sat, $gain, $tint, $format ) = ( '', 1, 1, '1,1,1', 'rgba' );
GetOptions( 'hue=s' => \$hue, 'sat=f' => \$sat, 'gain=f' => \$gain, 'tint=s' => \$tint, 'format=s' => \$format ) or die "recolor.pl: bad options\n";
my ( $in, $out ) = @ARGV;
die "usage: recolor.pl in.dds|in.png out.dds [--hue FROM:TO] [--sat S] [--gain G] [--tint R,G,B] [--format F]\n" unless $in && $out;
my ( $h_from, $h_to ) = $hue =~ /^(\d+(?:\.\d+)?):(\d+(?:\.\d+)?)$/;
die "recolor.pl: --hue takes FROM:TO in degrees\n" if $hue ne '' && !defined $h_to;
my @tint = split /,/, $tint;
die "recolor.pl: --tint takes three factors\n" unless @tint == 3;

my $img = $in =~ /\.png$/i ? MgPng::read($in) : MgDds::read($in);
my $px = $img->{px};
for ( my $i = 0; $i < @$px; $i += 4 ) {
    my ( $r, $g, $b ) = map { $_ / 255 } @$px[ $i .. $i + 2 ];
    # RGB -> HSV
    my ( $mx, $mn ) = ( $r > $g ? ( $r > $b ? $r : $b ) : ( $g > $b ? $g : $b ), $r < $g ? ( $r < $b ? $r : $b ) : ( $g < $b ? $g : $b ) );
    my $v = $mx;
    my $d = $mx - $mn;
    my $s = $mx > 0 ? $d / $mx : 0;
    my $h = 0;
    if ( $d > 0 ) {
        if    ( $mx == $r ) { $h = 60 * ( ( $g - $b ) / $d ) }
        elsif ( $mx == $g ) { $h = 60 * ( ( $b - $r ) / $d + 2 ) }
        else                { $h = 60 * ( ( $r - $g ) / $d + 4 ) }
        $h += 360 if $h < 0;
    }
    if ( defined $h_to && $s > 0.12 ) {
        my $dist = abs( $h - $h_from );
        $dist = 360 - $dist if $dist > 180;
        $h = $h_to if $dist <= 70;
    }
    $s *= $sat;
    $s = 1 if $s > 1;
    $v *= $gain;
    # HSV -> RGB
    my $c = $v * $s;
    my $x = $c * ( 1 - abs( ( ( $h / 60 ) - 2 * int( $h / 120 ) ) - 1 ) );
    my $m = $v - $c;
    my @rgb = $h < 60 ? ( $c, $x, 0 ) : $h < 120 ? ( $x, $c, 0 ) : $h < 180 ? ( 0, $c, $x ) : $h < 240 ? ( 0, $x, $c ) : $h < 300 ? ( $x, 0, $c ) : ( $c, 0, $x );
    for my $k ( 0 .. 2 ) {
        my $o = ( $rgb[$k] + $m ) * $tint[$k] * 255;
        $px->[ $i + $k ] = $o > 255 ? 255 : $o < 0 ? 0 : int( $o + 0.5 );
    }
}
my $mips = MgDds::write( $out, $img, $format );
printf "recolor.pl: %s -> %s (%dx%d, %d mips)\n", $in, $out, $img->{w}, $img->{h}, $mips;
