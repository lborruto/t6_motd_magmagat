package MgPng;
# Minimal PNG reader / writer for the mod tools (8-bit grey, grey+alpha, RGB, RGBA; not interlaced).
#   my $img = MgPng::read($path);   # { w, h, px => [ r, g, b, a, r, g, b, a, ... ] }
#   MgPng::write($path, $img);      # RGBA, filter 0
use strict;
use warnings;
use Compress::Zlib;

my %BPP = ( 0 => 1, 4 => 2, 2 => 3, 6 => 4 );

sub read {
    my $in = shift;
    open my $h, '<:raw', $in or die "$in: $!\n";
    local $/;
    my $png = <$h>;
    close $h;
    die "$in: not a PNG\n" unless substr( $png, 0, 8 ) eq "\x89PNG\r\n\x1a\n";
    my ( $w, $ht, $depth, $ctype, $interlace, $idat ) = ( 0, 0, 0, 0, 0, '' );
    my $p = 8;
    while ( $p < length $png ) {
        my ( $len, $type ) = unpack( 'N a4', substr( $png, $p, 8 ) );
        my $data = substr( $png, $p + 8, $len );
        if ( $type eq 'IHDR' ) { ( $w, $ht, $depth, $ctype, undef, undef, $interlace ) = unpack( 'N N C C C C C', $data ) }
        elsif ( $type eq 'IDAT' ) { $idat .= $data }
        elsif ( $type eq 'IEND' ) { last }
        $p += 12 + $len;
    }
    my $bpp = $BPP{$ctype};
    die "$in: only 8-bit grey/RGB(A) non-interlaced PNGs (depth $depth type $ctype interlace $interlace)\n"
        unless $depth == 8 && $bpp && !$interlace;
    my $raw = uncompress($idat);
    die "$in: bad zlib data\n" unless defined $raw;

    my $stride = $w * $bpp;
    my @prev = (0) x $stride;
    my @px;
    for my $y ( 0 .. $ht - 1 ) {
        my $f = ord( substr( $raw, $y * ( $stride + 1 ), 1 ) );
        my @cur = unpack( 'C*', substr( $raw, $y * ( $stride + 1 ) + 1, $stride ) );
        if ($f) {
            for my $i ( 0 .. $stride - 1 ) {
                my $a = $i >= $bpp ? $cur[ $i - $bpp ] : 0;
                my $b = $prev[$i];
                if    ( $f == 1 ) { $cur[$i] = ( $cur[$i] + $a ) & 255 }
                elsif ( $f == 2 ) { $cur[$i] = ( $cur[$i] + $b ) & 255 }
                elsif ( $f == 3 ) { $cur[$i] = ( $cur[$i] + ( ( $a + $b ) >> 1 ) ) & 255 }
                elsif ( $f == 4 ) {
                    my $c = $i >= $bpp ? $prev[ $i - $bpp ] : 0;
                    my $pp = $a + $b - $c;
                    my ( $pa, $pb, $pc ) = ( abs( $pp - $a ), abs( $pp - $b ), abs( $pp - $c ) );
                    $cur[$i] = ( $cur[$i] + ( ( $pa <= $pb && $pa <= $pc ) ? $a : ( $pb <= $pc ? $b : $c ) ) ) & 255;
                }
            }
        }
        for ( my $x = 0; $x < $w; $x++ ) {
            my $o = $x * $bpp;
            if    ( $bpp == 4 ) { push @px, @cur[ $o .. $o + 3 ] }
            elsif ( $bpp == 3 ) { push @px, @cur[ $o .. $o + 2 ], 255 }
            elsif ( $bpp == 2 ) { push @px, ( $cur[$o] ) x 3, $cur[ $o + 1 ] }
            else                { push @px, ( $cur[$o] ) x 3, 255 }
        }
        @prev = @cur;
    }
    return { w => $w, h => $ht, px => \@px };
}

sub write {
    my ( $out, $img ) = @_;
    my ( $w, $h, $px ) = @$img{qw(w h px)};
    my $raw = '';
    for my $y ( 0 .. $h - 1 ) { $raw .= "\0" . pack( 'C*', @$px[ $y * $w * 4 .. ( $y + 1 ) * $w * 4 - 1 ] ) }
    my $chunk = sub { my ( $t, $d ) = @_; pack( 'N', length $d ) . $t . $d . pack( 'N', crc32( $t . $d ) ) };
    open my $o, '>:raw', $out or die "$out: $!\n";
    print $o "\x89PNG\r\n\x1a\n", $chunk->( 'IHDR', pack( 'N N C C C C C', $w, $h, 8, 6, 0, 0, 0 ) ),
        $chunk->( 'IDAT', compress($raw) ), $chunk->( 'IEND', '' );
    close $o;
}

1;
