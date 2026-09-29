package MgDds;
# DDS reader / writer for the mod tools.
#   my $img = MgDds::read($path);   # top mip as { w, h, px => [ r, g, b, a, ... ] }
#                                   # (BC1 / BC3 / BC5 as FourCC or DX10, and uncompressed 32-bit)
#   MgDds::write($path, $img);      # uncompressed A8B8G8R8 with a full box-filtered mip chain, which the
#                                   # OpenAssetTools Linker embeds for a '*' image
use strict;
use warnings;

sub _rgb565 { my $c = shift; ( ( ( $c >> 11 ) & 31 ) * 255 / 31, ( ( $c >> 5 ) & 63 ) * 255 / 63, ( $c & 31 ) * 255 / 31 ) }

sub _bc1_block {    # 8 bytes -> 16 [r, g, b, a]
    my ( $blk, $alpha_ok ) = @_;
    my ( $c0, $c1, $bits ) = unpack( 'v v V', $blk );
    my @a = _rgb565($c0);
    my @b = _rgb565($c1);
    my @pal = ( [ @a, 255 ], [ @b, 255 ] );
    if ( $c0 > $c1 || !$alpha_ok ) {
        push @pal, [ map( { ( 2 * $a[$_] + $b[$_] ) / 3 } 0 .. 2 ), 255 ], [ map( { ( $a[$_] + 2 * $b[$_] ) / 3 } 0 .. 2 ), 255 ];
    }
    else {
        push @pal, [ map( { ( $a[$_] + $b[$_] ) / 2 } 0 .. 2 ), 255 ], [ 0, 0, 0, 0 ];
    }
    return map { $pal[ ( $bits >> ( 2 * $_ ) ) & 3 ] } 0 .. 15;
}

sub _bc4_block {    # 8 bytes -> 16 values
    my $blk = shift;
    my ( $a0, $a1 ) = unpack( 'C C', $blk );
    my @idx = unpack( 'C6', substr( $blk, 2, 6 ) );
    my $bits = 0;
    $bits |= $idx[$_] << ( 8 * $_ ) for 0 .. 5;
    my @pal = ( $a0, $a1 );
    if ( $a0 > $a1 ) { push @pal, map { ( ( 7 - $_ ) * $a0 + $_ * $a1 ) / 7 } 1 .. 6 }
    else             { push @pal, ( map { ( ( 5 - $_ ) * $a0 + $_ * $a1 ) / 5 } 1 .. 4 ), 0, 255 }
    return map { $pal[ ( $bits >> ( 3 * $_ ) ) & 7 ] } 0 .. 15;
}

sub read {
    my $in = shift;
    open my $h, '<:raw', $in or die "$in: $!\n";
    local $/;
    my $d = <$h>;
    close $h;
    die "$in: not a DDS\n" unless substr( $d, 0, 4 ) eq 'DDS ';
    my ( $ht, $w ) = unpack( 'V V', substr( $d, 12, 8 ) );
    my $fourcc = substr( $d, 84, 4 );
    my ( $bits, $rm, $gm, $bm, $am ) = unpack( 'V5', substr( $d, 88, 20 ) );
    my $off = 128;
    my $fmt;
    if ( $fourcc eq 'DX10' ) {
        my $dxgi = unpack( 'V', substr( $d, 128, 4 ) );
        $off = 148;
        $fmt = { 71 => 'bc1', 72 => 'bc1', 77 => 'bc3', 78 => 'bc3', 83 => 'bc5', 84 => 'bc5', 28 => 'rgba', 87 => 'bgra' }->{$dxgi}
            or die "$in: DXGI format $dxgi not supported\n";
    }
    elsif ( $fourcc eq 'DXT1' ) { $fmt = 'bc1' }
    elsif ( $fourcc eq 'DXT5' ) { $fmt = 'bc3' }
    elsif ( $fourcc eq 'ATI2' ) { $fmt = 'bc5' }
    elsif ( $bits == 32 ) { $fmt = $rm == 0xff ? 'rgba' : 'bgra' }
    else { die "$in: DDS format not supported\n" }

    my @px = (0) x ( $w * $ht * 4 );
    if ( $fmt eq 'rgba' || $fmt eq 'bgra' ) {
        my @b = unpack( 'C*', substr( $d, $off, $w * $ht * 4 ) );
        for ( my $i = 0; $i < @b; $i += 4 ) {
            @px[ $i .. $i + 3 ] = $fmt eq 'rgba' ? @b[ $i .. $i + 3 ] : ( $b[ $i + 2 ], $b[ $i + 1 ], $b[$i], $b[ $i + 3 ] );
        }
        return { w => $w, h => $ht, px => \@px };
    }
    my $bsz = $fmt eq 'bc1' ? 8 : 16;
    my ( $bw, $bh ) = ( int( ( $w + 3 ) / 4 ), int( ( $ht + 3 ) / 4 ) );
    for my $by ( 0 .. $bh - 1 ) {
        for my $bx ( 0 .. $bw - 1 ) {
            my $blk = substr( $d, $off + ( $by * $bw + $bx ) * $bsz, $bsz );
            my @t;
            if ( $fmt eq 'bc1' ) { @t = _bc1_block( $blk, 1 ) }
            elsif ( $fmt eq 'bc3' ) {
                my @a = _bc4_block( substr( $blk, 0, 8 ) );
                @t = _bc1_block( substr( $blk, 8, 8 ), 0 );
                $t[$_] = [ @{ $t[$_] }[ 0 .. 2 ], $a[$_] ] for 0 .. 15;
            }
            else {    # bc5: red + green channels (a normal map's X / Y); blue rebuilt from them
                my @r = _bc4_block( substr( $blk, 0, 8 ) );
                my @g = _bc4_block( substr( $blk, 8, 8 ) );
                for my $i ( 0 .. 15 ) {
                    my ( $x, $y ) = ( $r[$i] / 127.5 - 1, $g[$i] / 127.5 - 1 );
                    my $z = 1 - $x * $x - $y * $y;
                    $t[$i] = [ $r[$i], $g[$i], ( ( $z > 0 ? sqrt $z : 0 ) + 1 ) * 127.5, 255 ];
                }
            }
            for my $i ( 0 .. 15 ) {
                my ( $x, $y ) = ( $bx * 4 + $i % 4, $by * 4 + int( $i / 4 ) );
                next if $x >= $w || $y >= $ht;
                my $o = ( $y * $w + $x ) * 4;
                @px[ $o .. $o + 3 ] = map { int( $_ + 0.5 ) } @{ $t[$i] };
            }
        }
    }
    return { w => $w, h => $ht, px => \@px };
}

sub write {
    my ( $out, $img ) = @_;
    my @levels = ( [ $img->{w}, $img->{h}, $img->{px} ] );
    while ( $levels[-1][0] > 1 || $levels[-1][1] > 1 ) {
        my ( $pw, $ph, $src ) = @{ $levels[-1] };
        my ( $nw, $nh ) = ( $pw > 1 ? int( $pw / 2 ) : 1, $ph > 1 ? int( $ph / 2 ) : 1 );
        my @dst;
        for my $y ( 0 .. $nh - 1 ) {
            for my $x ( 0 .. $nw - 1 ) {
                my @sum = ( 0, 0, 0, 0 );
                my $n = 0;
                for my $dy ( 0, 1 ) {
                    for my $dx ( 0, 1 ) {
                        my ( $sx, $sy ) = ( $x * 2 + $dx, $y * 2 + $dy );
                        next if $sx >= $pw || $sy >= $ph;
                        my $o = ( $sy * $pw + $sx ) * 4;
                        $sum[$_] += $src->[ $o + $_ ] for 0 .. 3;
                        $n++;
                    }
                }
                push @dst, map { int( $_ / $n + 0.5 ) } @sum;
            }
        }
        push @levels, [ $nw, $nh, \@dst ];
    }
    # DDSD_CAPS|HEIGHT|WIDTH|PITCH|PIXELFORMAT|MIPMAPCOUNT, 32-bit RGBA (bytes R G B A: the uncompressed layout the
    # Linker maps to a T6 image format)
    my ( $w, $h ) = ( $img->{w}, $img->{h} );
    my $hdr = pack( 'a4 V7 V11', 'DDS ', 124, 0x1 | 0x2 | 0x4 | 0x8 | 0x1000 | 0x20000, $h, $w, $w * 4, 0, scalar @levels, (0) x 11 );
    $hdr .= pack( 'V8', 32, 0x41, 0, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000 );
    $hdr .= pack( 'V5', 0x1000 | 0x400000 | 0x8, 0, 0, 0, 0 );
    open my $o, '>:raw', $out or die "$out: $!\n";
    print $o $hdr;
    print $o pack( 'C*', @{ $_->[2] } ) for @levels;
    close $o;
    return scalar @levels;
}

1;
