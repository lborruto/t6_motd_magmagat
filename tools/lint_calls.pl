use strict;
use warnings;
use File::Basename qw(dirname);

# lint_calls.pl: every function called in the mg_*.gsc sources must exist somewhere: defined in a mg_*.gsc, or used by
# name in the vanilla T6 zombies scripts (which covers every engine builtin and every utility helper the game really
# has). A name found nowhere is almost surely a helper from another CoD (array_remove, 2026-09-11: "Unresolved
# external" at load, the compiler cannot know). Exit 1 on any unknown name.
my $tools   = dirname(__FILE__);
my $repo    = "$tools/..";
my $vanilla = 'C:/Games/t6/t6-scripts/t6-scripts-main/ZM';

my %known = ( notifyonplayercommand => 1 ); # a real T6 builtin the ZM scripts never use (MP ones do)
my %keyword = map { $_ => 1 } qw(if else while for foreach switch case return wait waittill waittillmatch waittillframeend
  endon notify thread call self level game anim undefined true false break continue default in isdefined);

# vanilla names: every identifier followed by "(" in any ZM gsc (calls and definitions alike)
my @files;
sub walk {
    my ($d) = @_;
    opendir my $dh, $d or return;
    for my $e ( readdir $dh ) {
        next if $e eq '.' || $e eq '..';
        my $p = "$d/$e";
        if ( -d $p ) { walk($p) } elsif ( $p =~ /\.gsc$/ ) { push @files, $p }
    }
    closedir $dh;
}
walk($vanilla);
if ( !@files ) { print "calls skipped (no vanilla scripts under $vanilla: run this lint on the owner machine)\n"; exit 0 }
for my $f (@files) {
    open my $h, '<', $f or next;
    while (<$h>) {
        s{//.*}{};
        while (/\b([a-z_][a-z0-9_]*)\s*\(/g) { $known{$1} = 1 }
    }
    close $h;
}

# our own definitions
my %ours;
for my $f ( glob("$repo/mg_*.gsc") ) {
    open my $h, '<', $f or die;
    while (<$h>) { $ours{$1} = 1 if /^([a-z_][a-z0-9_]*)\s*\(/ }
    close $h;
}

my $bad = 0;
my %seen;
for my $f ( sort glob("$repo/mg_*.gsc") ) {
    open my $h, '<', $f or die;
    my $ln = 0;
    while ( my $line = <$h> ) {
        $ln++;
        next if $line =~ m{^\s*//};
        $line =~ s{//.*}{};
        $line =~ s{"[^"]*"}{""}g;           # strings out
        $line =~ s{::\s*[a-z_][a-z0-9_]*}{}g;  # function pointers / qualified calls handled by the compiler
        while ( $line =~ /(?<![\w\\:])([a-z_][a-z0-9_]*)\s*\(/g ) {
            my $n = $1;
            next if $keyword{$n} || $ours{$n} || $known{$n};
            my $name = $f;
            $name =~ s{.*/}{};
            next if $seen{"$name:$n"}++;
            printf "UNKNOWN %-18s %5d  %s()  (defined nowhere in mg_*.gsc, never called by a vanilla T6 script)\n", $name, $ln, $n;
            $bad++;
        }
    }
    close $h;
}

if ($bad) { print "lint_calls.pl: $bad unknown call(s)\n"; exit 1 }
print "calls ok\n";
