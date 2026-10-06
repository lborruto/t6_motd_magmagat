#!/usr/bin/perl
# Builds the mod's sound bank sources from the BO3 remaster's own sounds (tools/assets/bo3_sounds.tsv):
#   - the Workshop map's zone data (mod/work/bo3/zm_prison.bin, inflated once from its zm_prison.ff) names its aliases:
#     every record holds the alias hash and, 0x30 after it, the bank entry it plays (tools/MgBo3.pm)
#   - each entry is copied out of snd/all/zm_prison.all.sabl / .sabs (plain FLAC, 48 kHz): a "loaded" alias is decoded
#     to a PCM WAV (tools/flac2wav.pl), a "streamed" one stays FLAC, as BO2 stores its own
# and the Magmagat's own from Black Ops 4 (tools/assets/bo4_sounds.tsv): each variant a file of BO4's zm_escape /
# zm_common banks (the same 2UX# banks, version 21, FLAC), found by its id (MgBo3::bo4_file_id), with BO4's layering
# (Secondary), volume and distances
#   - mod/sound/soundbank/mod.all.aliases.csv (every variant a row of our alias) and the zone block `soundbank,mod.all`
# The Linker then writes mod.all.sabl / mod.all.sabs next to mod.ff (tools/build_mod.pl installs them).
# mod/sound is generated from the game's files: never committed.
#
#   perl tools/import_sounds.pl
# Env: MG_BO3_MAP (the Workshop map folder), MG_BO4_SND (a folder holding BO4's zm_escape.all.sabl / .sabs and
# zm_common.all.sabl / .sabs, taken out of its zone/snd/all with CascView; default <MG_GREYHOUND>/sabs/zone/snd/all).
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
my $bo4 = $ENV{MG_BO4_SND} // ( $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0' ) . '/sabs/zone/snd/all';
my @bo4_banks = map { "$bo4/$_" } qw(zm_escape.all.sabl zm_escape.all.sabs zm_common.all.sabl zm_common.all.sabs);
die "import_sounds.pl: no BO4 sound banks in '$bo4' (set MG_BO4_SND: zm_escape.all.sabl and zm_common.all.sabl / .sabs)\n"
    if grep { !-f } @bo4_banks;

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
    die "import_sounds.pl: bo3_sounds.tsv line $.: 8 tab-separated columns expected (a 9th, what for, is optional)\n" unless @c >= 8;
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

# one variant of our alias: its file written (a "loaded" one decoded to WAV, a "streamed" one kept FLAC) and its row
sub add_variant {
    my ( $r, $k, $flac ) = @_;
    die "import_sounds.pl: $r->{ours} variant $k is not FLAC\n" unless substr( $flac, 0, 4 ) eq 'fLaC';
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
    my %v = ( Name => $r->{ours}, FileSource => $file, Secondary => $r->{sec} // '', Storage => $r->{storage}, Bus => 'bus_fx',
        VolumeGroup => 'grp_hdrfx', DuckGroup => 'snp_hdrfx', Duck => '', ReverbSend => 70, CenterSend => 0,
        VolMin => $r->{vol}, VolMax => $r->{vol}, DistMin => $r->{dmin}, DistMaxDry => $r->{dmax} || 5000,
        DistMaxWet => $r->{dwet} || $r->{dmax} || 5000, DryMinCurve => 'default', DryMaxCurve => 'default', WetMinCurve => 'allon',
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

for my $r (@rows) {
    my @e = MgBo3::alias_entries( \$zone, $r->{bo3}, \%entry_by_id );
    die "import_sounds.pl: $r->{bo3} plays no entry of the map's banks\n" unless @e;
    add_variant( $r, $_, MgBo3::bank_bytes( @{ $by_id{ $e[$_]{id} } } ) ) for 0 .. $#e;
    printf "import_sounds.pl: %-16s <- %-30s %d variant(s), %s\n", $r->{ours}, $r->{bo3}, scalar @e, $r->{storage};
}

# Black Ops 4's: the banks' entries by id, every manifest row a variant
my %bo4_entry;
for my $b ( map { MgBo3::open_bank($_) } @bo4_banks ) {
    $bo4_entry{ $_->{id} } //= [ $b, $_ ] for @{ $b->{entries} };
}
my ( %bo4_count, @bo4_order );
open $m, '<', "$FindBin::Bin/assets/bo4_sounds.tsv" or die "import_sounds.pl: no tools/assets/bo4_sounds.tsv\n";
while (<$m>) {
    next if /^#/ || !/\S/;
    s/\r?\n\z//;
    my @c = split /\t/, $_, -1;
    die "import_sounds.pl: bo4_sounds.tsv line $.: 10 tab-separated columns expected (an 11th, what for, is optional)\n" unless @c >= 10;
    my $r = { ours => $c[0], sec => $c[2], storage => $c[3], pan => $c[4], loop => $c[5], vol => $c[6], dmin => $c[7], dmax => $c[8],
        dwet => $c[9] };
    my $id = $c[1] =~ /^#([0-9a-f]+)$/ ? $1 : MgBo3::bo4_file_id( join chr(92), split m{/}, $c[1] );    # the bank names it with backslashes
    my $e = $bo4_entry{$id} or die "import_sounds.pl: $c[1] ($id) is in none of BO4's banks\n";
    push @bo4_order, $c[0] unless $bo4_count{ $c[0] };
    add_variant( $r, $bo4_count{ $c[0] }++, MgBo3::bank_bytes(@$e) );
}
close $m;
printf "import_sounds.pl: %-18s <- BO4, %d variant(s)\n", $_, $bo4_count{$_} for @bo4_order;
open my $o, '>:raw', "$out/soundbank/mod.all.aliases.csv" or die "import_sounds.pl: $out/soundbank/mod.all.aliases.csv: $!\n";
print $o join( "\n", @csv ), "\n";
close $o;

# the zone: our sounds block, in place when it exists
my $zf = "$repo/mod/zone_source/mod.zone";
my $z = do { open my $h, '<:raw', $zf or die "$zf: $!\n"; local $/; <$h> };
$z =~ s/\r\n/\n/g;    # a checkout may hand it over with CRLF endings
my $block = "// sounds (tools/import_sounds.pl)\nsoundbank,mod.all\n// end sounds\n";
if ( $z !~ s/\/\/ sounds \(tools\/import_sounds\.pl\).*?\/\/ end sounds\n/$block/s ) { $z =~ s/\s*\z/\n/; $z .= "\n$block" }
open $o, '>:raw', $zf or die "import_sounds.pl: $zf: $!\n";
print $o $z;
close $o;
printf "import_sounds.pl: %d aliases, %d files\n", @rows + @bo4_order, $files;
