package MgSnap;
# Reads a tools/bo3mem/Bo3Snapshot.exe snapshot: the assets (header address, size, name) and the memory copied from
# the running game, addressed as the game had it.
use strict;
use warnings;

sub open_snapshot {
    my $file = shift;
    open my $h, '<:raw', $file or die "$file: $!\n";
    local $/;
    my $d = <$h>;
    close $h;
    die "$file: not a Bo3Snapshot file\n" unless substr( $d, 0, 8 ) eq 'BO3SNAP1';
    my $n = unpack 'V', substr( $d, 8, 4 );
    my $o = 12;
    my ( @assets, %by_name );
    for ( 1 .. $n ) {
        my ( $addr, $size, $len ) = unpack 'Q< V v', substr( $d, $o, 14 );
        my $name = substr( $d, $o + 14, $len );
        $o += 14 + $len;
        push @assets, { addr => $addr, size => $size, name => $name };
        $by_name{$name} //= $assets[-1];
    }
    my @regions;
    while ( $o < length $d ) {
        my ( $addr, $len ) = unpack 'Q< V', substr( $d, $o, 12 );
        push @regions, [ $addr, $o + 12, $len ];
        $o += 12 + $len;
    }
    @regions = sort { $a->[0] <=> $b->[0] } @regions;
    return bless { data => \$d, assets => \@assets, by_name => \%by_name, regions => \@regions }, __PACKAGE__;
}

sub assets { @{ $_[0]{assets} } }
sub asset  { $_[0]{by_name}{ $_[1] } }

# len bytes at addr, or undef when the snapshot does not hold all of them
sub read {
    my ( $self, $addr, $len ) = @_;
    my $r = $self->{regions};
    my ( $lo, $hi, $best ) = ( 0, $#$r, undef );
    while ( $lo <= $hi ) {
        my $mid = int( ( $lo + $hi ) / 2 );
        if ( $r->[$mid][0] <= $addr ) { $best = $mid; $lo = $mid + 1 }
        else                         { $hi = $mid - 1 }
    }
    # the longest region starting at or before addr that covers it (regions may overlap)
    for ( my $i = $best // -1; $i >= 0 && $i > ( $best // 0 ) - 64; $i-- ) {
        my ( $base, $off, $rlen ) = @{ $r->[$i] };
        return substr( ${ $self->{data} }, $off + $addr - $base, $len ) if $addr + $len <= $base + $rlen;
    }
    return undef;
}

sub u64 { my ( $s, $a ) = @_; my $b = $s->read( $a, 8 ); defined $b ? unpack( 'Q<', $b ) : undef }

sub cstr {
    my ( $s, $a ) = @_;
    return undef unless $a;
    for my $len ( 256, 64, 16 ) {
        my $b = $s->read( $a, $len ) // next;
        my $z = index( $b, "\0" );
        next if $z < 0;
        my $str = substr( $b, 0, $z );
        return $str =~ /^[\x20-\x7e]*$/ ? $str : undef;
    }
    return undef;
}

# the name of the asset a pointer points at (its first field is its name)
sub name_at { my ( $s, $a ) = @_; return undef unless $a; $s->cstr( $s->u64($a) // 0 ) }

1;
