package MgBo3;
# Black Ops III data for the mod tools (core modules only).
#   MgBo3::inflate_ff($ff, $out)          a BO3 PC fastfile ("TAff0000") -> its raw zone data (zlib blocks from 0x248;
#                                         a block of size 0 pads to the next 8 MB boundary)
#   my $bank = MgBo3::open_bank($path)    a .sabl / .sabs sound bank ('2UX#', version 15 BO3 / 14 T6 / 21 BO4)
#   MgBo3::bank_bytes($bank, $entry)      the audio of one entry (FLAC in every BO3 and BO4 bank)
#   MgBo3::bo4_file_id($file)             a BO4 bank entry's id: fnv1a-64 of its file name (backslashes, as
#                                         wpn\zmb\magma_gat\ignite_zmb\ignite_00.ln100.pc.snd), its low 60 bits in hex
#   MgBo3::snd_hash($name)                the sound alias hash (SND_HashName, shared by T6 and BO3)
#   MgBo3::alias_entries($zone, $name, \%entry_by_id)   every bank entry an alias plays (all its variants): in the
#                                         zone data each alias record holds its hash, and 0x30 after it the entry id
use strict;
use warnings;
no warnings 'portable';    # 64-bit hex masks
use Compress::Raw::Zlib;

my @RATES = ( 8000, 12000, 16000, 24000, 32000, 44100, 48000, 96000, 192000 );

sub inflate_ff {
    my ( $in, $out ) = @_;
    open my $h, '<:raw', $in or die "$in: $!\n";
    open my $o, '>:raw', $out or die "$out: $!\n";
    my $magic;
    read( $h, $magic, 8 ) == 8 && $magic eq 'TAff0000' or die "$in: not a BO3 fastfile\n";
    seek $h, 0x248, 0;
    my $n = 0;
    while ( read( $h, my $hdr, 16 ) == 16 ) {
        my ( $csz, $dsz, $bsz ) = unpack( 'V3', $hdr );
        last if !$csz && !$dsz;
        if ( !$dsz ) { seek $h, ( int( tell($h) / 0x800000 ) + 1 ) * 0x800000, 0; next }
        read( $h, my $data, $bsz ) == $bsz or last;
        my ( $z, $st ) = Compress::Raw::Zlib::Inflate->new( -WindowBits => MAX_WBITS );
        my $buf;
        $st = $z->inflate( substr( $data, 0, $csz ), $buf );
        die "$in: block $n does not inflate ($st)\n" if $st != Z_OK && $st != Z_STREAM_END;
        print $o $buf;
        $n++;
    }
    close $o;
    return $n;
}

sub open_bank {
    my $f = shift;
    open my $fh, '<:raw', $f or die "$f: $!\n";
    read( $fh, my $h, 0x48 ) == 0x48 or die "$f: short\n";
    my ( $magic, $ver, $esz, undef, undef, $cnt, undef, undef, undef, $eoff ) = unpack( 'V8 Q< Q<', $h );
    die "$f: not a sound bank\n" unless $magic == 0x23585532;
    seek $fh, $eoff, 0;
    read( $fh, my $tab, $cnt * $esz ) == $cnt * $esz or die "$f: short entry table\n";
    my @e;
    for my $i ( 0 .. $cnt - 1 ) {
        my $r = substr( $tab, $i * $esz, $esz );
        my %x;
        if ( $esz == 36 ) { @x{qw(id size frames unk offset rate ch loop fmt)} = unpack( 'V V V V Q< C C C C', $r ) }
        elsif ( $esz == 20 ) { @x{qw(id size offset frames rate ch loop fmt)} = unpack( 'V V V V C C C C', $r ) }
        elsif ( $esz == 48 ) {
            # BO4: the file's 60-bit id (bo4_file_id), its offset, size and frame count
            @x{qw(id offset size frames)} = unpack( 'Q< x8 Q< V V', $r );
            $x{id} = sprintf '%x', $x{id} & 0x0FFFFFFFFFFFFFFF;
        }
        else { die "$f: entry size $esz unknown\n" }
        $x{hz} = defined $x{rate} && $RATES[ $x{rate} ] || 48000;
        push @e, \%x;
    }
    return { fh => $fh, path => $f, entries => \@e };
}

sub bank_bytes {
    my ( $bank, $e ) = @_;
    seek $bank->{fh}, $e->{offset}, 0;
    read( $bank->{fh}, my $d, $e->{size} ) == $e->{size} or die "$bank->{path}: short entry\n";
    return $d;
}

sub bo4_file_id {
    my $h = -3750763034362895579;    # fnv1a-64's basis, 0xcbf29ce484222325
    {
        use integer;    # 64-bit multiplication that wraps
        ( $h ^= $_ ) *= 1099511628211 for unpack 'C*', shift;
    }
    return sprintf '%x', $h & 0x0FFFFFFFFFFFFFFF;
}

sub snd_hash {
    my $r = 0x1505;
    $r = ( ord($_) + 0x1003F * $r ) & 0xffffffff for split //, lc shift;
    return $r || 1;
}

sub alias_entries {
    my ( $zone, $name, $by_id ) = @_;
    my $h = pack( 'V', snd_hash($name) );
    my ( @out, %seen );
    my $p = 0;
    while ( ( $p = index( $$zone, $h, $p ) ) >= 0 ) {
        my $id = unpack( 'V', substr( $$zone, $p + 0x30, 4 ) );
        push @out, $by_id->{$id} if $by_id->{$id} && !$seen{$id}++;
        $p++;
    }
    return @out;
}

1;
