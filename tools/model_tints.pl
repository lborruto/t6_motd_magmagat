#!/usr/bin/perl
# The colours a BO3 model's materials really draw with: many carry no colour map of their own worth taking alone (a
# light-grey paint map, $black_color, $white_diffuse) and get their colour from the material's colorTint constant (and a
# second layer's, colorTint1), which Greyhound does not export. They are read from a Bo3Snapshot taken with
# --models=<model> (tools/bo3mem), one row a material, for tools/import_prop.pl --tints:
#   <material>  <colour map>  <second layer map>  <colorTint r,g,b>  <colorTint1 r,g,b>      (linear)
#
#   perl tools/model_tints.pl <snapshot.bin> <xmodel> <out.tsv>
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use MgSnap;
use MgFx7;

my ( $file, $model, $out ) = @ARGV;
die "usage: model_tints.pl <snapshot.bin> <xmodel> <out.tsv>\n" unless $out;
my $s = MgSnap::open_snapshot($file);
my $c = MgFx7->new($s);
# the model as Bo3Snapshot lists it: HydraX's XModelAsset, LOD count at +64, per-LOD materials at +200 (24 bytes each:
# count at +0, material pointers at +8)
my $a = $s->asset("xmodel/$model") or die "model_tints.pl: $model is not in $file (snapshot it with --models=$model)\n";
my $h = $s->read( $a->{addr}, 392 ) // die "model_tints.pl: ${model}'s header not captured\n";
my $lods = unpack 'l<', substr( $h, 64, 4 );
my $mm = unpack 'Q<', substr( $h, 200, 8 );
my ( %seen, @rows );
for my $l ( 0 .. $lods - 1 ) {
    my $b = $s->read( $mm + 24 * $l, 24 ) // next;
    my $n = unpack 'l<', $b;
    my $p = unpack 'Q<', substr( $b, 8, 8 );
    for my $k ( 0 .. $n - 1 ) {
        my $m = $c->material( $s->u64( $p + 8 * $k ) // next ) // next;
        ( my $name = $m->{name} // next ) =~ s{^\w+/}{};
        next if $seen{$name}++;
        my $f = sub { my $v = $m->{settings}{ $_[0] } // [ 1, 1, 1 ]; join ',', map { sprintf '%.4f', $_ } @$v[ 0 .. 2 ] };
        push @rows, join( "\t", $name, $m->{images}{a0ab1041} // '-', $m->{images}{'80951342'} // '-', $f->('colorTint'), $f->('colorTint1') );
    }
}
open my $o, '>', $out or die "$out: $!\n";
print $o "$_\n" for @rows;
close $o;
printf "model_tints.pl: %s: %d materials -> %s\n", $model, scalar @rows, $out;
