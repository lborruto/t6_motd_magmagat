#!/usr/bin/perl
# flac2wav.pl <in.flac> <out.wav> [target_rate]
# Pure-Perl FLAC decoder (core modules only) -> PCM16 WAV with a canonical 44-byte header
# (exactly what OpenAssetTools' T6 SoundBankWriter::LoadWavFile expects for "loaded" sounds).
# Supports: CONSTANT / VERBATIM / FIXED / LPC subframes, rice + rice2 residuals (incl. escape),
# independent / left-side / right-side / mid-side stereo, wasted bits, 8..24 bit input (output 16 bit).
# Every frame's CRC-16 is verified.
use strict; use warnings; use integer;

my ($in, $out) = @ARGV; die "usage: $0 in.flac out.wav\n" unless $out;
open(my $fh, '<:raw', $in) or die "$in: $!\n"; local $/; my $data = <$fh>; close $fh;
die "not a FLAC file\n" unless substr($data, 0, 4) eq 'fLaC';

my ($rate, $nch, $bps, $total);
my $p = 4;
while (1) {
    my ($hb, $l1, $l2, $l3) = unpack('C4', substr($data, $p, 4));
    my $len = ($l1 << 16) | ($l2 << 8) | $l3; my $type = $hb & 0x7f;
    if ($type == 0) {
        my $si = substr($data, $p + 4, 34);
        my $b = unpack('B*', substr($si, 10, 8));
        $rate = oct('0b' . substr($b, 0, 20)); $nch = oct('0b' . substr($b, 20, 3)) + 1;
        $bps = oct('0b' . substr($b, 23, 5)) + 1; $total = oct('0b' . substr($b, 28, 36));
    }
    $p += 4 + $len; last if $hb & 0x80;
}
my $B = unpack('B*', substr($data, $p)); my $pos = 0; my $NB = length $B;

sub rd { my $n = shift; return 0 unless $n; my $v = oct('0b' . substr($B, $pos, $n)); $pos += $n; $v }
sub rds { my $n = shift; my $v = rd($n); $v -= (1 << $n) if $n && ($v >> ($n - 1)) & 1; $v }
sub unary { my $i = index($B, '1', $pos); die "unary overrun\n" if $i < 0; my $q = $i - $pos; $pos = $i + 1; $q }

my @crc16; for my $i (0 .. 255) { my $c = $i << 8; for (1 .. 8) { $c = ($c & 0x8000) ? (($c << 1) ^ 0x8005) : ($c << 1); $c &= 0xffff } $crc16[$i] = $c }
sub crc16 { my $s = shift; my $c = 0; $c = (($c << 8) & 0xffff) ^ $crc16[(($c >> 8) ^ $_) & 0xff] for unpack('C*', $s); $c }

my @BS = (0, 192, 576, 1152, 2304, 4608, 0, 0, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768);
my @SS = (0, 8, 12, 0, 16, 20, 24, 0);

sub residual {
    my ($bs, $order, $res) = @_;
    my $method = rd(2); my $pbits = $method ? 5 : 4; my $esc = $method ? 31 : 15;
    my $porder = rd(4); my $parts = 1 << $porder;
    for my $pi (0 .. $parts - 1) {
        my $n = $porder ? ($bs >> $porder) : $bs; $n -= $order if $pi == 0;
        my $k = rd($pbits);
        if ($k == $esc) { my $w = rd(5); push @$res, rds($w) for 1 .. $n; next }
        for (1 .. $n) {
            my $i = index($B, '1', $pos); my $q = $i - $pos; $pos = $i + 1;
            my $u = $k ? (($q << $k) | oct('0b' . substr($B, $pos, $k))) : $q; $pos += $k;
            push @$res, ($u & 1) ? -(($u >> 1) + 1) : ($u >> 1);
        }
    }
}

sub subframe {
    my ($bs, $sbps) = @_;
    rd(1); my $t = rd(6); my $wasted = 0;
    if (rd(1)) { $wasted = unary() + 1; $sbps -= $wasted }
    my @s;
    if ($t == 0) { my $v = rds($sbps); @s = ($v) x $bs }
    elsif ($t == 1) { push @s, rds($sbps) for 1 .. $bs }
    elsif ($t >= 8 && $t <= 12) {
        my $o = $t - 8; push @s, rds($sbps) for 1 .. $o;
        my @r; residual($bs, $o, \@r);
        for my $e (@r) {
            my $n = @s;
            if    ($o == 0) { push @s, $e }
            elsif ($o == 1) { push @s, $e + $s[$n-1] }
            elsif ($o == 2) { push @s, $e + 2*$s[$n-1] - $s[$n-2] }
            elsif ($o == 3) { push @s, $e + 3*$s[$n-1] - 3*$s[$n-2] + $s[$n-3] }
            else            { push @s, $e + 4*$s[$n-1] - 6*$s[$n-2] + 4*$s[$n-3] - $s[$n-4] }
        }
    } elsif ($t >= 32) {
        my $o = $t - 31; push @s, rds($sbps) for 1 .. $o;
        my $prec = rd(4) + 1; my $shift = rds(5); my @c; push @c, rds($prec) for 1 .. $o;
        my @r; residual($bs, $o, \@r);
        for my $e (@r) {
            my $n = @s; my $sum = 0;
            for my $j (0 .. $o - 1) { $sum += $c[$j] * $s[$n - 1 - $j] }
            push @s, $e + ($sum >> $shift);
        }
    } else { die "reserved subframe type $t at bit $pos\n" }
    if ($wasted) { $_ <<= $wasted for @s }
    return \@s;
}

my @pcm; my $frames = 0;
while ($pos + 32 < $NB) {
    my $fstart = $pos;
    die sprintf("lost sync at byte %d\n", $pos / 8) unless substr($B, $pos, 15) eq '111111111111100';
    $pos += 16;
    my $bsc = rd(4); my $src = rd(4); my $ca = rd(4); my $ssc = rd(3); rd(1);
    my $b0 = rd(8); my $extra = 0; if ($b0 & 0x80) { my $m = $b0; while ($m & 0x40) { $extra++; $m <<= 1 } } rd(8) for 1 .. $extra;
    my $bs = $BS[$bsc]; $bs = rd(8) + 1 if $bsc == 6; $bs = rd(16) + 1 if $bsc == 7;
    if ($src == 12) { rd(8) } elsif ($src == 13 || $src == 14) { rd(16) }
    rd(8); # header crc8
    my $fb = $SS[$ssc] || $bps;
    my $ch = $ca < 8 ? $ca + 1 : 2;
    my @chs;
    for my $c (0 .. $ch - 1) {
        my $sb = $fb; $sb++ if ($ca == 8 && $c == 1) || ($ca == 9 && $c == 0) || ($ca == 10 && $c == 1);
        push @chs, subframe($bs, $sb);
    }
    $pos += (8 - $pos % 8) % 8;
    my $fbytes = substr($data, $p + $fstart / 8, ($pos - $fstart) / 8);
    my $crc = rd(16);
    die "CRC16 mismatch in frame $frames\n" if crc16($fbytes) != $crc;
    my ($a, $b) = @chs;
    if ($ca == 8) { for my $i (0 .. $bs-1) { $b->[$i] = $a->[$i] - $b->[$i] } }
    elsif ($ca == 9) { for my $i (0 .. $bs-1) { $a->[$i] = $a->[$i] + $b->[$i] } }
    elsif ($ca == 10) { for my $i (0 .. $bs-1) { my $m = ($a->[$i] << 1) | ($b->[$i] & 1); my $s = $b->[$i]; $a->[$i] = ($m + $s) >> 1; $b->[$i] = ($m - $s) >> 1 } }
    my $sh = $fb - 16;
    for my $i (0 .. $bs - 1) { for my $c (0 .. $ch - 1) { my $v = $chs[$c][$i]; $v = $sh > 0 ? $v >> $sh : $v << -$sh; push @pcm, $v } }
    $frames++;
    last if $total && @pcm / $nch >= $total;
}
my $samples = @pcm / $nch;
my $bin = pack('s<*', @pcm);
open(my $o, '>:raw', $out) or die "$out: $!\n";
print $o pack('A4 V A4 A4 V v v V V v v A4 V', 'RIFF', 36 + length $bin, 'WAVE', 'fmt ', 16, 1, $nch, $rate, $rate * $nch * 2, $nch * 2, 16, 'data', length $bin), $bin;
close $o;
printf "%s: %d Hz, %d ch, %d bit -> %d frames, %d samples (streaminfo %d), %.3f s, all CRC16 OK\n", $in, $rate, $nch, $bps, $frames, $samples, $total, do { no integer; $samples / $rate };
