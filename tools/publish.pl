#!/usr/bin/perl
# Publishes a release: builds mod.ff and its sound bank (tools/build_mod.pl) and creates the GitHub Release v<version>
# with mod.ff, mod.all.sabl and mod.all.sabs attached; .github/workflows/release.yml then builds the player zip from the tagged
# sources and attaches it (the bare mod.ff is removed once the zip is up).
# The release notes: how to install, then the "## <version>" section of CHANGELOG.md.
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
my @assets = map { "$repo/mod/out/$_" } qw(mod.ff mod.all.sabl mod.all.sabs);
-s $_ or die "publish.pl: $_ is missing or empty after build_mod.pl\n" for @assets;

# what's new: the "## <version>" section of CHANGELOG.md, when it has one
my $news = '';
if ( open my $c, '<', "$repo/CHANGELOG.md" ) {
    ($news) = do { local $/; <$c> } =~ /^## \Q$version\E\b[^\n]*\n(.*?)(?=^## |\z)/ms;
    $news //= '';
    $news =~ s/\r//g;
    $news =~ s/^\s+|\s+\z//g;
    # its relative links point into the repository at the tag (a release page resolves none)
    chomp( my $url = `git -C "$repo" remote get-url origin` );
    $url =~ s{^git\@github\.com:}{https://github.com/};
    $url =~ s{\.git$}{};
    $news =~ s{\]\((?![a-z]+:|#)([^)]+)\)}{]($url/blob/$tag/$1)}g if $url =~ m{^https://github\.com/};
}

my ( $fh, $notes ) = tempfile( SUFFIX => '.md', UNLINK => 1 );
print $fh <<"MD";
Magmagat for Mob of the Dead $version (Plutonium T6).

**Install**: download `zm_magmagat-$version.zip` below (it appears a minute after the release), unzip it and drop the
`zm_magmagat` folder into `%localappdata%\\Plutonium\\storage\\t6\\mods\\`. In game: **Mods** -> **zm_magmagat**, then
play Mob of the Dead.
MD
print $fh "\n$news\n" if length $news;
close $fh;
my @cmd = ( 'gh', 'release', 'create', $tag, @assets, '--target', $head, '--title', "Magmagat $version", '--notes-file', $notes );
push @cmd, '--draft' if $draft;
system(@cmd) == 0 or die "publish.pl: gh release create failed\n";
print "publish.pl: $tag published with mod.ff and its sound bank (mod.all.sabl / .sabs); the release workflow attaches zm_magmagat-$version.zip\n";
