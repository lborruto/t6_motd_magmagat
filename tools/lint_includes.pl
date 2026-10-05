#!/usr/bin/perl
use strict; use warnings;
use File::Basename qw(dirname basename);
# tools/lint_includes.pl - catches the "Unresolved external" class of load failure: a mg_*.gsc that calls a
# vanilla SCRIPT helper (not an engine builtin) without the three utility includes. One missing line refuses
# the whole mod at load (mg_dialogue.gsc / is_true, 2026-09-08). The sources are found from the script's own
# place (the repo root above tools/), so it lints the same files from any folder.
my @helpers = qw(is_true is_player_valid flag flag_wait flag_set flag_clear flag_init array_add
                 array_randomize get_players is_headshot random get_array_of_closest
                 waittill_any_return waittill_either play_sound_at_pos);
my @need = ('common_scripts\utility', 'maps\mp\_utility', 'maps\mp\zombies\_zm_utility');
my $repo = dirname(__FILE__) . '/..';
my @src = sort glob("$repo/mg_*.gsc");
die "lint_includes.pl: no mg_*.gsc in $repo\n" unless @src;    # finding none would pass falsely
my $bad = 0;
for my $path (@src) {
    my $f = basename($path);
    open my $h,'<:raw',$path or next; local $/; my $s = <$h>; close $h;
    my $code = $s; $code =~ s{//[^\n]*}{}g;          # drop line comments
    my @miss = grep { index($s, "#include $_;") < 0 } @need;
    next unless @miss;
    my @used = grep { $code =~ /(?<![\w:])\Q$_\E\s*\(/ } @helpers;
    next unless @used;
    print "$f: uses @used but is missing #include $_\n" for @miss;
    $bad++;
}
print $bad ? "$bad file(s) need includes\n" : "includes ok\n";
exit( $bad ? 1 : 0 );
