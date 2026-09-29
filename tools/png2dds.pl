#!/usr/bin/perl
# PNG (8-bit grey / RGB / RGBA, not interlaced) -> DDS with a full mip chain (2x2 box filter): uncompressed 32-bit
# (default) or block-compressed (bc1 colour, bc3 colour + alpha, bc5 normal map; tools/MgDds.pm).
# tools/import_prop.pl writes its textures with it; the Linker embeds the DDS in mod.ff.
#   perl tools/png2dds.pl in.png out.dds [rgba|bc1|bc3|bc5]
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use MgPng;
use MgDds;

my ( $in, $out, $format ) = @ARGV;
die "usage: png2dds.pl in.png out.dds [rgba|bc1|bc3|bc5]\n" unless $in && $out;
my $img = MgPng::read($in);
my $mips = MgDds::write( $out, $img, $format );
printf "png2dds.pl: %s -> %s (%dx%d, %d mips)\n", $in, $out, $img->{w}, $img->{h}, $mips;
