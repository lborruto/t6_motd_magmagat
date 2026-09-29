#!/usr/bin/perl
# Builds the mod's sound bank sources from the BO3 remaster's own sounds (tools/assets/bo3_sounds.tsv):
#   - the Workshop map's zone data (mod/work/bo3/zm_prison.bin, inflated once from its zm_prison.ff) names its aliases:
#     every record holds the alias hash and, 0x30 after it, the bank entry it plays (tools/MgBo3.pm)
#   - each entry is copied out of snd/all/zm_prison.all.sabl / .sabs (plain FLAC, 48 kHz): a "loaded" alias is decoded
#     to a PCM WAV (tools/flac2wav.pl), a "streamed" one stays FLAC, as BO2 stores its own
#   - mod/sound/soundbank/mod.all.aliases.csv (every variant a row of our alias) and the zone block `soundbank,mod.all`
# The Linker then writes mod.all.sabl / mod.all.sabs next to mod.ff (tools/build_mod.pl installs them).
# mod/sound is generated from the game's files: never committed.
#
#   perl tools/import_sounds.pl
# Env: MG_BO3_MAP (the Workshop map folder).
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use File::Path qw(make_path remove_tree);
use MgBo3;

my $map = $ENV{MG_BO3_MAP} // 'C:/Program Files (x86)/Steam/steamapps/workshop/content/311210/3373649394';
my $repo = "$FindBin::Bin/..";
my $out = "$repo/mod/sound";
my $work = "$repo/mod/work/bo3";
die "import_sounds.pl: no BO3 map at $map (set MG_BO3_MAP)\n" unless -f "$map/zm_prison.ff";

# the zone data, once
make_path($work);
my $bin = "$work/zm_prison.bin";
if ( !-f $bin ) {
    print "import_sounds.pl: inflating the map's zm_prison.ff (once)\n";
    MgBo3::inflate_ff( "$map/zm_prison.ff", $bin );
}
my $zone = do { open my $h, '<:raw', $bin or die "$bin: $!\n"; local $/; <$h> };

# the banks: entry id -> [ bank, entry ]
my %by_id;
for my $b ( map { MgBo3::open_bank("$map/snd/all/zm_prison.all.$_") } qw(sabl sabs) ) {
    $by_id{ $_->{id} } = [ $b, $_ ] for @{ $b->{entries} };
}
my %entry_by_id = map { $_ => $by_id{$_}[1] } keys %by_id;

# the manifest
my @rows;
open my $m, '<', "$FindBin::Bin/assets/bo3_sounds.tsv" or die "import_sounds.pl: no tools/assets/bo3_sounds.tsv\n";
while (<$m>) {
    next if /^#/ || !/\S/;
    chomp;
    my @c = split /\t/;
    die "import_sounds.pl: bo3_sounds.tsv line $.: 9 columns expected\n" unless @c >= 8;
    push @rows, { ours => $c[0], bo3 => $c[1], storage => $c[2], pan => $c[3], loop => $c[4], vol => $c[5], dmin => $c[6], dmax => $c[7] };
}
close $m;

remove_tree($out);
make_path( "$out/soundbank", "$out/sound/magmagat" );
my @head = qw(Name FileSource Secondary Storage Bus VolumeGroup DuckGroup Duck ReverbSend CenterSend VolMin VolMax DistMin
    DistMaxDry DistMaxWet DryMinCurve DryMaxCurve WetMinCurve WetMaxCurve LimitCount EntityLimitCount LimitType EntityLimitType
    PitchMin PitchMax PriorityMin PriorityMax PriorityThresholdMin PriorityThresholdMax PanType Pan Looping RandomizeType Probability
    StartDelay EnvelopMin EnvelopMax EnvelopPercent OcclusionLevel IsBig DistanceLpf FluxType FluxTime Subtitle Doppler
    ContextType ContextValue Timescale IsMusic IsCinematic FadeIn FadeOut Pauseable StopOnEntDeath StopOnPlay DopplerScale
    FutzPatch VoiceLimit IgnoreMaxDist NeverPlayTwice);
my @csv = ( join( ',', @head ) );
my $files = 0;
for my $r (@rows) {
    my @e = MgBo3::alias_entries( \$zone, $r->{bo3}, \%entry_by_id );
    die "import_sounds.pl: $r->{bo3} plays no entry of the map's banks\n" unless @e;
    for my $k ( 0 .. $#e ) {
        my ( $bank, $entry ) = @{ $by_id{ $e[$k]{id} } };
        my $flac = MgBo3::bank_bytes( $bank, $entry );
        die "import_sounds.pl: $r->{bo3} variant $k is not FLAC\n" unless substr( $flac, 0, 4 ) eq 'fLaC';
        my $name = "$r->{ours}_$k";
        my $file;
        if ( $r->{storage} eq 'loaded' ) {
            my $tmp = "$work/$name.flac";
            open my $o, '>:raw', $tmp or die "$tmp: $!\n";
            print $o $flac;
            close $o;
            $file = "sound/magmagat/$name.wav";
            system( 'perl', "$FindBin::Bin/flac2wav.pl", $tmp, "$out/$file" ) == 0 or die "import_sounds.pl: decoding $name failed\n";
            unlink $tmp;
        }
        else {
            $file = "sound/magmagat/$name.flac";
            open my $o, '>:raw', "$out/$file" or die "$out/$file: $!\n";
            print $o $flac;
            close $o;
        }
        $files++;
        my %v = ( Name => $r->{ours}, FileSource => $file, Secondary => '', Storage => $r->{storage}, Bus => 'bus_fx',
            VolumeGroup => 'grp_hdrfx', DuckGroup => 'snp_hdrfx', Duck => '', ReverbSend => 70, CenterSend => 0,
            VolMin => $r->{vol}, VolMax => $r->{vol}, DistMin => $r->{dmin}, DistMaxDry => $r->{dmax} || 5000,
            DistMaxWet => $r->{dmax} || 5000, DryMinCurve => 'default', DryMaxCurve => 'default', WetMinCurve => 'allon',
            WetMaxCurve => 'allon', LimitCount => 4, EntityLimitCount => 2, LimitType => 'oldest', EntityLimitType => 'oldest',
            PitchMin => 0, PitchMax => 0, PriorityMin => 60, PriorityMax => 90, PriorityThresholdMin => 0,
            PriorityThresholdMax => 1, PanType => $r->{pan}, Pan => 'default', Looping => $r->{loop}, RandomizeType => 'volume',
            Probability => 1, StartDelay => 0, EnvelopMin => 0, EnvelopMax => 0, EnvelopPercent => 0,
            OcclusionLevel => $r->{pan} eq '3d' ? 0.25 : 0, IsBig => 'no', DistanceLpf => $r->{pan} eq '3d' ? 'yes' : 'no',
            FluxType => 'none', FluxTime => 0, Subtitle => '', Doppler => 'no', ContextType => '', ContextValue => '',
            Timescale => 'yes', IsMusic => 'no', IsCinematic => 'no', FadeIn => 0, FadeOut => 0, Pauseable => 'yes',
            StopOnEntDeath => 'no', StopOnPlay => '', DopplerScale => 0, FutzPatch => '', VoiceLimit => 'no',
            IgnoreMaxDist => $r->{pan} eq '2d' ? 'yes' : 'no', NeverPlayTwice => 'no' );
        push @csv, join( ',', map { $v{$_} } @head );
    }
    printf "import_sounds.pl: %-16s <- %-30s %d variant(s), %s\n", $r->{ours}, $r->{bo3}, scalar @e, $r->{storage};
}
open my $o, '>:raw', "$out/soundbank/mod.all.aliases.csv" or die;
print $o join( "\n", @csv ), "\n";
close $o;

# the zone: our sounds block, in place when it exists
my $zf = "$repo/mod/zone_source/mod.zone";
my $z = do { open my $h, '<:raw', $zf or die "$zf: $!\n"; local $/; <$h> };
$z =~ s/\r\n/\n/g;    # a checkout may hand it over with CRLF endings
my $block = "// sounds (tools/import_sounds.pl)\nsoundbank,mod.all\n// end sounds\n";
if ( $z !~ s/\/\/ sounds \(tools\/import_sounds\.pl\).*?\/\/ end sounds\n/$block/s ) { $z =~ s/\s*\z/\n/; $z .= "\n$block" }
open $o, '>:raw', $zf or die;
print $o $z;
close $o;
printf "import_sounds.pl: %d aliases, %d files\n", scalar @rows, $files;
