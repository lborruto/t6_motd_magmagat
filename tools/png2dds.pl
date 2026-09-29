#!/usr/bin/perl
# PNG (8-bit grey / RGB / RGBA, not interlaced) -> uncompressed 32-bit DDS (A8B8G8R8) with a full mip chain (2x2 box filter).
# tools/import_prop.pl writes its textures with it; the Linker embeds the DDS in mod.ff.
#   perl tools/png2dds.pl in.png out.dds
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use MgPng;
use MgDds;

my ( $in, $out ) = @ARGV;
die "usage: png2dds.pl in.png out.dds\n" unless $in && $out;
my $img = MgPng::read($in);
my $mips = MgDds::write( $out, $img );
printf "png2dds.pl: %s -> %s (%dx%d, %d mips)\n", $in, $out, $img->{w}, $img->{h}, $mips;
