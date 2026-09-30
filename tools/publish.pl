#!/usr/bin/perl
# Publishes a release: builds mod.ff and its sound bank (tools/build_mod.pl) and creates the GitHub Release v<version>
# with mod.ff, mod.all.sabl and mod.all.sabs attached; .github/workflows/release.yml then builds the player zip from the tagged
# sources and attaches it (the bare mod.ff is removed once the zip is up).
# Needs the GitHub CLI signed in (gh auth login) and the release commit pushed: the tag is made on it.
#
#   perl tools/publish.pl              the version is level.mg_version in mg_main.gsc
#   perl tools/publish.pl --draft      a draft release (the workflow runs when it is published)
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempfile);

my $draft = grep { $_ eq '--draft' } @ARGV;
my $repo = "$FindBin::Bin/..";
my ($version) = do { open my $h, '<', "$repo/mg_main.gsc" or die "publish.pl: no mg_main.gsc\n"; local $/; <$h> } =~ /level\.mg_version\s*=\s*"([^"]+)"/;
die "publish.pl: no level.mg_version in mg_main.gsc\n" unless $version;
my $tag = "v$version";

system( 'gh', 'auth', 'status' ) == 0 or die "publish.pl: the GitHub CLI is not signed in (gh auth login)\n";
chomp( my $dirty = `git -C "$repo" status --porcelain --untracked-files=no` );
die "publish.pl: commit your changes first (the release is built from the pushed commit)\n" if $dirty;
chomp( my $head = `git -C "$repo" rev-parse HEAD` );
chomp( my $remote = `git -C "$repo" ls-remote origin refs/heads/main` );
die "publish.pl: push main first: origin/main is not HEAD ($head)\n" unless $remote =~ /^\Q$head\E\s/;

system( 'perl', "$FindBin::Bin/build_mod.pl", '--no-install' ) == 0 or die "publish.pl: build_mod.pl failed\n";

my ( $fh, $notes ) = tempfile( SUFFIX => '.md', UNLINK => 1 );
print $fh <<"MD";
Magmagat for Mob of the Dead $version (Plutonium T6).

**Install**: download `zm_magmagat-$version.zip` below (it appears a minute after the release), unzip it and drop the
`zm_magmagat` folder into `%localappdata%\\Plutonium\\storage\\t6\\mods\\`. In game: **Mods** -> **zm_magmagat**, then
play Mob of the Dead.
MD
close $fh;
my @cmd = ( 'gh', 'release', 'create', $tag, map( { "$repo/mod/out/$_" } qw(mod.ff mod.all.sabl mod.all.sabs) ), '--target', $head, '--title', "Magmagat $version", '--notes-file', $notes );
push @cmd, '--draft' if $draft;
system(@cmd) == 0 or die "publish.pl: gh release create failed\n";
print "publish.pl: $tag published with mod.ff and its sound bank (mod.all.sabl / .sabs); the release workflow attaches zm_magmagat-$version.zip\n";
