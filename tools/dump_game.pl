#!/usr/bin/perl
# Dumps BO2's zm_prison weapons, models, materials, images (as DDS) and animations into mod/work/dump with the OpenAssetTools
# Unlinker: the source of the Magmagat (tools/build_weapon.pl) and of the prop material template
# (tools/import_prop.pl). Game files: mod/work is never committed.
# zm_prison's images sit in DLC ipaks the Unlinker only opens under a name it loads by itself (base,
# <language>_base): zm.ipak and the DLC ipaks are hard-linked as unused language bases for the dump.
#
#   perl tools/dump_game.pl            dump when mod/work/dump is missing
#   perl tools/dump_game.pl --redump   dump again
# Env: MG_OAT (OpenAssetTools folder), MG_BO2 (the BO2 install).
use strict;
use warnings;
use FindBin;
use File::Path qw(make_path remove_tree);

my $redump = grep { $_ eq '--redump' } @ARGV;
my $work = "$FindBin::Bin/../mod/work";
my $dump = "$work/dump";
my $oat = $ENV{MG_OAT} // 'C:/Games/t6/openassettools';
my $bo2 = $ENV{MG_BO2} // 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops II';
my $zones = "$bo2/zone/all";
sub winpath { my $p = shift; return $p if $p =~ /^[A-Za-z]:/; chomp( my $w = `cygpath -m "$p"` ); $w }

exit 0 if !$redump && -d "$dump/weapons" && -d "$dump/materials";
die "dump_game.pl: no Unlinker at $oat/Unlinker.exe (set MG_OAT)\n" unless -f "$oat/Unlinker.exe";
die "dump_game.pl: no BO2 zones at $zones (set MG_BO2)\n" unless -f "$zones/zm_prison.ff";

remove_tree($dump);
my $alias = "$work/ipak_alias";
remove_tree($alias);
make_path($alias);
my %as = ( dlczm1 => 'fr_base', dlczm2 => 'fc_base', dlczm3 => 'ge_base', dlczm4 => 'as_base', zm => 'it_base' );
for my $src ( sort keys %as ) {
    next unless -f "$zones/$src.ipak";
    link( "$zones/$src.ipak", "$alias/$as{$src}.ipak" ) or die "dump_game.pl: hard link of $src.ipak failed ($!): the repo and BO2 must be on one drive\n";
}
my @cmd = ( "$oat/Unlinker.exe", '--search-path', winpath($alias) . ';' . winpath($zones), '--include-assets', 'weapon,xmodel,material,image,xanim',
    '--image-format', 'DDS', '--model-format', 'GLTF', '-o', winpath($dump), winpath("$zones/zm_prison.ff") );
my $rc = system(@cmd);
remove_tree($alias);
$rc == 0 or die "dump_game.pl: the Unlinker failed\n";
print "dump_game.pl: zm_prison dumped into mod/work/dump\n";
