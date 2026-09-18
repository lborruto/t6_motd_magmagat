#!/usr/bin/perl
# tools/gsc_header.pl <compiled .gsc binary from gsc-tool>
# Prints the T6 script header. The point: every function / import NAME is a 16-bit offset into the string block
# that starts right after the 64-byte header, so a script whose string block passes 65535 bytes makes the game
# read names from wrong places ("Unresolved external: t_completed" seen 2026-09-08). Layout from xensik's
# gsc-tool (T6 header: 8-byte magic, then u32 fields, then u16 counts, then u8 counts).
use strict;
use warnings;

my $f = shift or die "usage: gsc_header.pl <compiled gsc>\n";
open my $h, '<:raw', $f or die "cannot open $f\n";
local $/;
my $d = <$h>;
close $h;

my @u32 = unpack 'x8 V10', $d;          # after the 8-byte magic
my ( $crc, $include_off, $animtree_off, $cseg_off, $strfix_off, $exports_off, $imports_off, $fixup_off, $profile_off, $cseg_size ) = @u32;
my ( $name_off, $strfix_count, $exports_count, $imports_count, $fixup_count, $profile_count ) = unpack 'x48 v6', $d;
my ( $include_count, $animtree_count, $flags ) = unpack 'x60 C3', $d;

# the string block runs from the end of the header to the first table that follows it
my @after = sort { $a <=> $b } grep { $_ > 64 } ( $include_off, $animtree_off, $cseg_off, $strfix_off, $exports_off, $imports_off, $fixup_off, $profile_off );
my $str_end = $after[0] // length $d;
my $str_size = $str_end - 64;

printf "%s\n", $f;
printf "  file size          %8d bytes\n", length $d;
printf "  string block       %8d bytes  (limit 65535: %s)\n", $str_size, ( $str_size > 65535 ? 'OVER, names will be read wrong' : 'ok' );
printf "  code (cseg)        %8d bytes\n", $cseg_size;
printf "  exports (functions) %7d\n", $exports_count;
printf "  imports (externals) %7d\n", $imports_count;
printf "  includes           %8d   string fixups %d   fixups %d\n", $include_count, $strfix_count, $fixup_count;
printf "  script name offset %8d %s\n", $name_off, ( $name_off > 65535 ? '(OVERFLOW)' : '' );
exit( $str_size > 65535 ? 1 : 0 );
