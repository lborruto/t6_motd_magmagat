#!/usr/bin/perl
# DDS (BC1 / BC3 / BC5 / uncompressed) -> PNG of its top mip, to look at or edit a dumped T6 texture.
#   perl tools/dds2png.pl in.dds out.png
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use MgPng;
use MgDds;

my ( $in, $out ) = @ARGV;
die "usage: dds2png.pl in.dds out.png\n" unless $in && $out;
my $img = MgDds::read($in);
MgPng::write( $out, $img );
printf "dds2png.pl: %s -> %s (%dx%d)\n", $in, $out, $img->{w}, $img->{h};
