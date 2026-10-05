package MgDds;
# DDS reader / writer for the mod tools.
#   my $img = MgDds::read($path);   # top mip as { w, h, px => [ r, g, b, a, ... ] }
#                                   # (BC1 / BC3 / BC5 as FourCC or DX10, and uncompressed 32-bit)
#   MgDds::write($path, $img [, 'rgba'|'bc1'|'bc3'|'bc5']);   # with a full box-filtered mip chain (default rgba),
#                                   # which the OpenAssetTools Linker embeds for a '*' image
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

# the mip chain, 2x2 box filtered, down to 1x1
sub _mips {
    my $img = shift;
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
    return @levels;
}

sub _to565 { my ( $r, $g, $b ) = @_; ( int( $r * 31 / 255 + 0.5 ) << 11 ) | ( int( $g * 63 / 255 + 0.5 ) << 5 ) | int( $b * 31 / 255 + 0.5 ) }

# 16 [r, g, b] -> 8 bytes: bounding-box endpoints (inset by 1/16), 4-colour mode, nearest palette entry
sub _bc1_encode {
    my @p = @_;
    my ( @mn, @mx );
    @mn = ( 255, 255, 255 );
    @mx = ( 0, 0, 0 );
    for my $c (@p) { for my $k ( 0 .. 2 ) { $mn[$k] = $c->[$k] if $c->[$k] < $mn[$k]; $mx[$k] = $c->[$k] if $c->[$k] > $mx[$k] } }
    for my $k ( 0 .. 2 ) { my $i = ( $mx[$k] - $mn[$k] ) / 16; $mn[$k] += $i; $mx[$k] -= $i }
    my ( $c0, $c1 ) = ( _to565(@mx), _to565(@mn) );
    ( $c0, $c1 ) = ( $c1, $c0 ) if $c0 < $c1;
    return pack( 'v v V', $c0, $c0, 0 ) if $c0 == $c1;
    my @a = _rgb565($c0);
    my @b = _rgb565($c1);
    my @pal = ( \@a, \@b, [ map { ( 2 * $a[$_] + $b[$_] ) / 3 } 0 .. 2 ], [ map { ( $a[$_] + 2 * $b[$_] ) / 3 } 0 .. 2 ] );
    my $bits = 0;
    for my $i ( 0 .. 15 ) {
        my ( $best, $bd ) = ( 0, 1e18 );
        for my $k ( 0 .. 3 ) {
            my $d = ( $p[$i][0] - $pal[$k][0] )**2 + ( $p[$i][1] - $pal[$k][1] )**2 + ( $p[$i][2] - $pal[$k][2] )**2;
            ( $best, $bd ) = ( $k, $d ) if $d < $bd;
        }
        $bits |= $best << ( 2 * $i );
    }
    return pack( 'v v V', $c0, $c1, $bits );
}

# 16 values -> 8 bytes: max / min endpoints, 8-level mode
sub _bc4_encode {
    my @v = @_;
    my ( $a0, $a1 ) = ( 0, 255 );
    for (@v) { $a0 = $_ if $_ > $a0; $a1 = $_ if $_ < $a1 }
    return pack( 'C C', $a0, $a0 ) . ( "\0" x 6 ) if $a0 == $a1;
    my $bits = 0;
    for my $i ( 0 .. 15 ) {
        my $k = int( ( $a0 - $v[$i] ) / ( $a0 - $a1 ) * 7 + 0.5 );
        my $idx = $k == 0 ? 0 : $k == 7 ? 1 : $k + 1;
        $bits |= $idx << ( 3 * $i );
    }
    my $idx = '';
    $idx .= chr( ( $bits >> ( 8 * $_ ) ) & 255 ) for 0 .. 5;
    return pack( 'C C', $a0, $a1 ) . $idx;
}

# MgDds::write($path, $img [, $format]): 'rgba' (uncompressed, default), 'bc1' (colour), 'bc3' (colour + alpha) or
# 'bc5' (a normal map: red = X, green = Y), with a full box-filtered mip chain. The Linker embeds any of them for a
# '*' image; the block formats keep the fastfile small.
sub write {
    my ( $out, $img, $format ) = @_;
    $format //= 'rgba';
    my @levels = _mips($img);
    my ( $w, $h ) = ( $img->{w}, $img->{h} );
    my ( $pf, $body );
    if ( $format eq 'rgba' ) {
        $pf = pack( 'V8', 32, 0x41, 0, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000 );
        $body = join '', map { pack( 'C*', @{ $_->[2] } ) } @levels;
    }
    else {
        my %cc = ( bc1 => 'DXT1', bc3 => 'DXT5', bc5 => 'ATI2' );
        die "MgDds: unknown format $format\n" unless $cc{$format};
        $pf = pack( 'V2 a4 V5', 32, 0x4, $cc{$format}, 0, 0, 0, 0, 0 );
        for my $l (@levels) {
            my ( $lw, $lh, $px ) = @$l;
            for my $by ( 0 .. int( ( $lh + 3 ) / 4 ) - 1 ) {
                for my $bx ( 0 .. int( ( $lw + 3 ) / 4 ) - 1 ) {
                    my @blk;
                    for my $i ( 0 .. 15 ) {
                        my ( $x, $y ) = ( $bx * 4 + $i % 4, $by * 4 + int( $i / 4 ) );
                        $x = $lw - 1 if $x >= $lw;
                        $y = $lh - 1 if $y >= $lh;
                        my $o = ( $y * $lw + $x ) * 4;
                        push @blk, [ @$px[ $o .. $o + 3 ] ];
                    }
                    if ( $format eq 'bc1' ) { $body .= _bc1_encode(@blk) }
                    elsif ( $format eq 'bc3' ) { $body .= _bc4_encode( map { $_->[3] } @blk ) . _bc1_encode(@blk) }
                    else { $body .= _bc4_encode( map { $_->[0] } @blk ) . _bc4_encode( map { $_->[1] } @blk ) }
                }
            }
        }
    }
    my $flags = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | ( $format eq 'rgba' ? 0x8 : 0x80000 );
    my $pitch = $format eq 'rgba' ? $w * 4 : length( $body ) > 0 ? int( ( $w + 3 ) / 4 ) * int( ( $h + 3 ) / 4 ) * ( $format eq 'bc1' ? 8 : 16 ) : 0;
    my $hdr = pack( 'a4 V7 V11', 'DDS ', 124, $flags, $h, $w, $pitch, 0, scalar @levels, (0) x 11 ) . $pf;
    $hdr .= pack( 'V5', 0x1000 | 0x400000 | 0x8, 0, 0, 0, 0 );
    open my $o, '>:raw', $out or die "$out: $!\n";
    print $o $hdr, $body;
    close $o;
    return scalar @levels;
}

1;
