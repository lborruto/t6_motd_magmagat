#!/usr/bin/perl
# The forge's ghouls' flight, BO4's: its scene aib_vign_zm_mob_smelter_ghost moves each ghoul by its xanim's
# tag_origin track (the body hangs 103.5 cm under it, j_mainroot), relative to the smelter's origin. T6 plays no
# tag_origin motion on a script_model, so script moves the ghoul along it: this samples the track every $STEP frames
# from Greyhound's SEAnim export and writes it, brought onto the remaster's press, into mg_forge.gsc (between its
# "ghoul paths" markers): one string a ghoul, "x,y,z,pitch,yaw,roll" keys joined by "|", read by mg_ghoul_path().
#   The mapping, the lever's (tools/import_all.pl): BO4's smelter is the remaster's press at 0.755 scale with its
# smasher on our ram, turned 180 degrees about it (the owner turned the press to face as BO4's: the remaster's model
# faces the other way). So a point p (cm, the smelter's frame) lands at
#   ram + R180( p * 0.755 / 2.54 - smasher )   on x, y;   p.z / 2.54   up (from the floor: the ghoul keeps its size, its
#   body hanging a fixed 103.5 cm under tag_origin, so its height is BO4's own)
# with the smelter's smasher centre (42.54, 60.40) and our ram's centre (5.4, -0.25) in inches, and a rotation q at
# R180 * q, written as the angles (pitch, yaw, roll) of the press's frame.
#
#   perl tools/ghoul_path.pl <ghoul 1 .seanim> <ghoul 2 .seanim>
use strict;
use warnings;
use FindBin;
use Math::Trig qw(pi);

my $STEP = 6;    # frames (30 fps): 0.2 s
my $SCALE = 0.755 / 2.54;
my @SMASHER = ( 42.54, 60.40 );
my @RAM = ( 5.4, -0.25 );

sub read_root {    # SEAnim file -> ( frame count, { frame => [x y z] }, { frame => [x y z w] } ) of tag_origin
    my $f = shift;
    open my $h, '<:raw', $f or die "ghoul_path.pl: $f: $!\n";
    local $/;
    my $d = <$h>;
    my ( $pres, $prop ) = unpack( 'C C', substr( $d, 12, 2 ) );
    my ( $fc, $bc ) = unpack( 'V V', substr( $d, 20, 8 ) );
    my $mods = unpack( 'C', substr( $d, 28, 1 ) );
    my $o = 36;
    my @names;
    for ( 1 .. $bc ) { my $e = index( $d, "\0", $o ); push @names, substr( $d, $o, $e - $o ); $o = $e + 1 }
    my $isz = $fc <= 0xFF ? 1 : $fc <= 0xFFFF ? 2 : 4;
    my $fmt = { 1 => 'C', 2 => 'v', 4 => 'V' }->{$isz};
    $o += $mods * ( ( $bc <= 0xFF ? 1 : $bc <= 0xFFFF ? 2 : 4 ) + 1 );
    my ( $fl, $ff ) = ( $prop & 1 ) ? ( 8, 'd' ) : ( 4, 'f' );
    for my $b ( 0 .. $bc - 1 ) {
        $o++;
        my ( %t, %r );
        if ( $pres & 1 ) { my $n = unpack( $fmt, substr( $d, $o, $isz ) ); $o += $isz; for ( 1 .. $n ) { my $k = unpack( $fmt, substr( $d, $o, $isz ) ); $o += $isz; $t{$k} = [ unpack( "$ff$ff$ff", substr( $d, $o, 3 * $fl ) ) ]; $o += 3 * $fl } }
        if ( $pres & 2 ) { my $n = unpack( $fmt, substr( $d, $o, $isz ) ); $o += $isz; for ( 1 .. $n ) { my $k = unpack( $fmt, substr( $d, $o, $isz ) ); $o += $isz; $r{$k} = [ unpack( "$ff$ff$ff$ff", substr( $d, $o, 4 * $fl ) ) ]; $o += 4 * $fl } }
        if ( $pres & 4 ) { my $n = unpack( $fmt, substr( $d, $o, $isz ) ); $o += $isz; $o += $n * ( $isz + 3 * $fl ) }
        return ( $fc, \%t, \%r ) if $names[$b] eq 'tag_origin';
    }
    die "ghoul_path.pl: no tag_origin in $f\n";
}

sub at {    # keys, frame -> the value there, linear between the keys around it (normalised for a quaternion)
    my ( $keys, $f ) = @_;
    my @k = sort { $a <=> $b } keys %$keys;
    my ( $lo, $hi ) = ( $k[0], $k[-1] );
    for (@k) { $lo = $_ if $_ <= $f; if ( $_ >= $f ) { $hi = $_; last } }
    my ( $a, $b ) = ( $keys->{$lo}, $keys->{$hi} );
    return [@$a] if $hi == $lo;
    my $t = ( $f - $lo ) / ( $hi - $lo );
    my $sgn = @$a == 4 && ( $a->[0] * $b->[0] + $a->[1] * $b->[1] + $a->[2] * $b->[2] + $a->[3] * $b->[3] ) < 0 ? -1 : 1;
    my @v = map { $a->[$_] + ( $sgn * $b->[$_] - $a->[$_] ) * $t } 0 .. $#$a;
    if ( @v == 4 ) { my $n = sqrt( $v[0]**2 + $v[1]**2 + $v[2]**2 + $v[3]**2 ); @v = map { $_ / $n } @v }
    return \@v;
}

sub angles {    # quaternion (x y z w), turned 180 degrees about z -> (pitch, yaw, roll) degrees, R = Rz(yaw) Ry(pitch) Rx(roll)
    my ( $x, $y, $z, $w ) = @{ $_[0] };
    ( $x, $y, $z, $w ) = ( -$y, $x, $w, -$z );    # (0 0 1 0) * q: 180 degrees about z, first
    my @m = (
        [ 1 - 2 * ( $y * $y + $z * $z ), 2 * ( $x * $y - $z * $w ), 2 * ( $x * $z + $y * $w ) ],
        [ 2 * ( $x * $y + $z * $w ), 1 - 2 * ( $x * $x + $z * $z ), 2 * ( $y * $z - $x * $w ) ],
        [ 2 * ( $x * $z - $y * $w ), 2 * ( $y * $z + $x * $w ), 1 - 2 * ( $x * $x + $y * $y ) ],
    );
    my $s = -$m[2][0];
    $s = 1 if $s > 1;
    $s = -1 if $s < -1;
    my $pitch = atan2( $s, sqrt( 1 - $s * $s ) );
    return map { $_ * 180 / pi } ( $pitch, atan2( $m[1][0], $m[0][0] ), atan2( $m[2][1], $m[2][2] ) );
}

die "usage: ghoul_path.pl <ghoul 1 .seanim> <ghoul 2 .seanim>\n" unless @ARGV == 2;
my @data;
for my $g ( 0 .. 1 ) {
    my ( $fc, $t, $r ) = read_root( $ARGV[$g] );
    my @keys;
    for ( my $f = 0; $f < $fc; $f += $STEP ) {
        my $p = at( $t, $f );
        my @s = map { $_ * $SCALE } @$p;
        my $t_z = $p->[2] / 2.54;    # its height unscaled: the body hangs a fixed 103.5 cm under it
        push @keys, sprintf( '%.1f,%.1f,%.1f,%.0f,%.0f,%.0f', $RAM[0] - ( $s[0] - $SMASHER[0] ), $RAM[1] - ( $s[1] - $SMASHER[1] ), $t_z, angles( at( $r, $f ) ) );
    }
    push @data, join( '|', @keys );
}
my $gsc = "$FindBin::Bin/../mg_forge.gsc";
open my $h, '<:raw', $gsc or die "ghoul_path.pl: $gsc: $!\n";
my $src = do { local $/; <$h> };
close $h;
my $nl = $src =~ /\r\n/ ? "\r\n" : "\n";
my $block = join( $nl, '// ghoul paths (tools/ghoul_path.pl: BO4\'s, a key every 0.2 s; do not edit by hand)', 'mg_ghoul_path_data( i )', '{',
    '    if ( i == 0 )', "        return \"$data[0]\";", '', "    return \"$data[1]\";", '}', '// end ghoul paths' );
$src =~ s{// ghoul paths \(tools/ghoul_path\.pl.*?// end ghoul paths}{$block}s or die "ghoul_path.pl: no \"ghoul paths\" markers in mg_forge.gsc\n";
open $h, '>:raw', $gsc or die "ghoul_path.pl: $gsc: $!\n";
print $h $src;
close $h;
printf "ghoul_path.pl: 2 paths, %d and %d keys, into mg_forge.gsc\n", scalar( split /\|/, $data[0] ), scalar( split /\|/, $data[1] );
