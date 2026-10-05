#!/usr/bin/perl
# The temper drums' filling (the owner's call: BO4's drums are open and filled, 2/3 up, nothing seen of their inside),
# written as a Greyhound export for tools/import_prop.pl: a disc of BO4's ash (its fire pit's) fitted inside the
# remaster's drum (p7_zm_gen_barrel_metal_55gal_green_drk_lod: 60 cm across, 87.9 high, its foot at 0) 2/3 up, with
# BO4's burnt splinters (p8_zm_esc_debris_wood_pile_splinter_40x40x4_burnt) shrunk onto it. One LOD: it is small.
#
#   perl tools/barrel_fill.pl <the splinters' Greyhound folder> <out folder>      (tools/import_all.pl runs it)
use strict;
use warnings;
use JSON::PP;
use File::Path qw(make_path);
use File::Copy qw(copy);

my ( $src, $out ) = @ARGV;
die "usage: barrel_fill.pl <splinters' Greyhound folder> <out folder>\n" unless $src && $out;
my $name = 'p8_zm_esc_debris_wood_pile_splinter_40x40x4_burnt_LOD0';
sub slurp { my $f = shift; open my $h, '<:raw', $f or die "barrel_fill.pl: $f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; open my $h, '>:raw', $f or die "barrel_fill.pl: $f: $!\n"; print $h $s; close $h }

my $top = 87.9 * 2 / 3;    # cm: the fill's surface, 2/3 up the drum
my $radius = 29.2;         # cm: the drum's inside, just within its 29.9 outside
my $shrink = 0.38;         # the splinters (112 x 96 cm) within the disc
my $g = decode_json( slurp("$src/$name.gltf") );
my $buf = slurp("$src/$name.bin");

# the splinters: shrunk about their middle and laid on the disc
my %done;
for my $p ( map { @{ $_->{primitives} } } @{ $g->{meshes} } ) {
    my $ai = $p->{attributes}{POSITION};
    next if $done{$ai}++;
    my $a = $g->{accessors}[$ai];
    my $bv = $g->{bufferViews}[ $a->{bufferView} ];
    my $base = ( $bv->{byteOffset} // 0 ) + ( $a->{byteOffset} // 0 );
    my $stride = $bv->{byteStride} // 12;
    my ( @mn, @mx );
    for my $v ( 0 .. $a->{count} - 1 ) {
        my @n = unpack( 'f<3', substr( $buf, $base + $v * $stride, 12 ) );
        @n = ( $n[0] * $shrink, $n[1] * $shrink, $top + $n[2] * $shrink );
        substr( $buf, $base + $v * $stride, 12 ) = pack( 'f<3', @n );
        for ( 0 .. 2 ) { $mn[$_] = $n[$_] if !defined $mn[$_] || $n[$_] < $mn[$_]; $mx[$_] = $n[$_] if !defined $mx[$_] || $n[$_] > $mx[$_] }
    }
    @$a{qw(min max)} = ( \@mn, \@mx );
}

# the disc: a fan of 32, facing up, its UVs a circle within the ash texture
my $seg = 32;
my ( @pos, @nrm, @uv, @idx );
push @pos, 0, 0, $top; push @nrm, 0, 0, 1; push @uv, 0.5, 0.5;
for my $i ( 0 .. $seg - 1 ) {
    my $t = 2 * 3.14159265358979 * $i / $seg;
    push @pos, $radius * cos($t), $radius * sin($t), $top;
    push @nrm, 0, 0, 1;
    push @uv, 0.5 + 0.45 * cos($t), 0.5 + 0.45 * sin($t);
    push @idx, 0, 1 + $i, 1 + ( $i + 1 ) % $seg;
}
sub view {    # (packed data, target) -> bufferView index, appended 4-aligned
    my ( $data, $target ) = @_;
    $buf .= "\0" x ( ( 4 - length($buf) % 4 ) % 4 );
    push @{ $g->{bufferViews} }, { buffer => 0, byteOffset => length($buf), byteLength => length($data), target => $target };
    $buf .= $data;
    return $#{ $g->{bufferViews} };
}
sub accessor { push @{ $g->{accessors} }, shift; $#{ $g->{accessors} } }
my $n = $seg + 1;
my $pa = accessor( { bufferView => view( pack( 'f<*', @pos ), 34962 ), componentType => 5126, count => $n, type => 'VEC3',
    min => [ -$radius, -$radius, $top ], max => [ $radius, $radius, $top ] } );
my $na = accessor( { bufferView => view( pack( 'f<*', @nrm ), 34962 ), componentType => 5126, count => $n, type => 'VEC3' } );
my $ta = accessor( { bufferView => view( pack( 'f<*', @uv ), 34962 ), componentType => 5126, count => $n, type => 'VEC2' } );
my $ia = accessor( { bufferView => view( pack( 'v*', @idx ), 34963 ), componentType => 5123, count => scalar @idx, type => 'SCALAR' } );
my $ash = 'i_mtl_p8_zm_gla_egy_fire_pit_sml_ash';
push @{ $g->{images} }, { uri => "_images\\mg_barrel_ash\\${ash}_c.png" }, { uri => "_images\\mg_barrel_ash\\${ash}_n.png" };
push @{ $g->{textures} }, { source => $#{ $g->{images} } - 1 }, { source => $#{ $g->{images} } };
push @{ $g->{materials} }, { name => 'mg_barrel_ash', pbrMetallicRoughness => { baseColorTexture => { index => $#{ $g->{textures} } - 1 } },
    normalTexture => { index => $#{ $g->{textures} } } };
push @{ $g->{meshes} }, { primitives => [ { mode => 4, indices => $ia, material => $#{ $g->{materials} }, attributes => { POSITION => $pa, NORMAL => $na, TEXCOORD_0 => $ta } } ] };
push @{ $g->{nodes} }, { mesh => $#{ $g->{meshes} } };

my $stem = 'mg_barrel_fill_LOD0';
$g->{buffers} = [ { byteLength => length($buf), uri => "$stem.bin" } ];
make_path("$out/_images/mg_barrel_ash");
for my $dir ( glob("$src/_images/*") ) {
    ( my $d = $dir ) =~ s{.*/}{};
    make_path("$out/_images/$d");
    copy( $_, "$out/_images/$d/" ) for glob("$dir/*.png");
}
copy( "$src/_images/xmaterial_8f9ea4d16282daa/${ash}_$_.png", "$out/_images/mg_barrel_ash/" ) or die "barrel_fill.pl: no ${ash}_$_.png\n" for qw(c n);
spit( "$out/$stem.gltf", JSON::PP->new->canonical->encode($g) );
spit( "$out/$stem.bin", $buf );
# import_prop.pl reads its root bone and lighting centre from the XMODEL_EXPORT
spit( "$out/$stem.XMODEL_EXPORT", "MODEL\nVERSION 6\n\nNUMBONES 1\nBONE 0 -1 \"tag_origin\"\n\nNUMVERTS 1\nVERT 0\nOFFSET 0.000000, 0.000000, " . sprintf( '%.6f', $top ) . "\n" );
print "barrel_fill.pl: $out/$stem (an ash disc of $radius cm at $top cm, the splinters at ${\ ( $shrink * 100 )} %)\n";
