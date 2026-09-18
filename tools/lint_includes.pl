use strict; use warnings;
# tools/lint_includes.pl - catches the "Unresolved external" class of load failure: a mg_*.gsc that calls a
# vanilla SCRIPT helper (not an engine builtin) without the three utility includes. One missing line refuses
# the whole mod at load (mg_dialogue.gsc / is_true, 2026-09-08).
my @helpers = qw(is_true is_player_valid flag flag_wait flag_set flag_clear flag_init array_add array_remove
                 array_randomize get_players getplayers_ignore_bots is_headshot random get_array_of_closest
                 waittill_any_return waittill_either play_sound_at_pos playsoundatposition_dummy);
my @need = ('common_scripts\utility', 'maps\mp\_utility', 'maps\mp\zombies\_zm_utility');
my $bad = 0;
for my $f (glob('mg_*.gsc')) {
    open my $h,'<:raw',$f or next; local $/; my $s = <$h>; close $h;
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
