use strict;
use warnings;
use File::Basename qw(dirname);

# lint_sounds.pl: every sound alias the mg_*.gsc sources play must exist in the game's real alias tables
# (tools/assets/soundbank/*.aliases.csv, dumped from common_zm.ff / patch_zm.ff / zmb_alcatraz.all with the
# OAT Unlinker, --include-assets soundbank). An alias that is in no bank is silent in game.
# vox_* aliases live in the english bank whose table the unlinker does not resolve: they are accepted only when
# added by name to %vox_ok below (starts empty; no vanilla prison vox alias verified yet).
# Exit code 1 on any unknown alias. Also prints the range of every 3D alias played with playsoundatposition so a
# 150-unit alias at a prop is caught by eye.
my $tools = dirname(__FILE__);
my $repo  = "$tools/..";

my %alias;
my %info;
for my $csv ( glob("$tools/assets/soundbank/*.aliases.csv") ) {
    open my $h, '<', $csv or die "$csv: $!";
    my $head = <$h>;
    chomp $head;
    my @cols = split /,/, $head;
    my %ix;
    $ix{ $cols[$_] } = $_ for 0 .. $#cols;
    while (<$h>) {
        chomp;
        my @f = split /,/, $_, -1;
        my $n = $f[ $ix{Name} ];
        next unless length $n;
        $alias{$n} = 1;
        $info{$n} //= sprintf( '%s %s-%s', $f[ $ix{PanType} ], $f[ $ix{DistMin} ], $f[ $ix{DistMaxDry} ] );
    }
    close $h;
}
die "lint_sounds.pl: no alias tables under tools/assets/soundbank\n" unless %alias;

# vox aliases played by vanilla prison scripts (english bank, not in the dumped tables) verified by hand
my %vox_ok = ();

my $bad = 0;
my %seen;
for my $f ( sort glob("$repo/mg_*.gsc") ) {
    open my $h, '<', $f or die;
    my $ln = 0;
    while ( my $line = <$h> ) {
        $ln++;
        next if $line =~ m{^\s*//};
        my @found;
        # direct calls
        while ( $line =~ /\b(playsound|playsoundtoplayer|playsoundatposition|playloopsound|playlocalsound|play_sound_at_pos|playsoundwithnotify|mg_snd_near|mg_a1_tone_near|mg_vox_once|mg_maxis_vox|mg_rich_vox|mg_lamp_hum_set)\s*\(\s*(?:[a-z_.\[\]0-9]+\s*,\s*)?"([a-z0-9_]+)"/gi ) {
            push @found, $2;
        }
        # alias tables filled by assignment
        while ( $line =~ /\b(mg_[a-z0-9_]*snd[a-z0-9_]*|mg_[a-z0-9_]*alias[a-z0-9_]*)\s*(?:\[[^\]]*\])?\s*=\s*"([a-z0-9_]+)"/gi ) {
            push @found, $2;
        }
        for my $a (@found) {
            next if $seen{"$f:$a"}++;
            my $name = $f;
            $name =~ s{.*/}{};
            if ( $alias{$a} ) {
                if ( $line =~ /playsoundatposition/ && $info{$a} =~ /3d (\d+)-(\d+)/ && $2 < 300 ) {
                    printf "range  %-16s %5d  %-34s 3D fades out at %s units when played AT a position\n", $name, $ln, $a, $2;
                }
                next;
            }
            if ( $a =~ /^vox_/ ) {
                next if $vox_ok{$a};
                printf "vox?   %-16s %5d  %s  (not a vanilla TranZit vox alias, unverified)\n", $name, $ln, $a;
                next;
            }
            printf "SILENT %-16s %5d  %s  is in no TranZit sound bank\n", $name, $ln, $a;
            $bad++;
        }
    }
    close $h;
}

if ($bad) { print "lint_sounds.pl: $bad silent alias(es)\n"; exit 1 }
print "sounds ok\n";
