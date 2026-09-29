#!/usr/bin/perl
# The Magmagat's projectile and pool, as BO4 builds them: meshes, not particles (its magmagat.gsc flies the
# p8_fxp_magma_blob model and lays fx_magma_splat meshes). T6 fastfiles cannot carry a new particle effect, so the
# two meshes are generated here and skinned with the BO3 remaster's own lava (i_pbr_lava_magma_emissive_1_mtl: rock
# colour, molten emission, normal) on the Acid Gat's emberglow shader, which flickers and scrolls the heat:
#   mg_lava_blob   a lumpy ball of lava, ~6 in across (the lava ball in flight, the blob stuck on a zombie)
#   mg_lava_pool   an irregular molten splat, ~60 in across (the magma patch a miss leaves)
#
#   perl tools/gen_lava_fx.pl <out raw dir> <zm_prison dump dir>      (tools/build_weapon.pl runs it)
# Env: MG_GREYHOUND (the Greyhound folder).
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use JSON::PP;
use MIME::Base64 qw(encode_base64);
use File::Path qw(make_path);
use MgPng;
use MgDds;

my ( $raw, $dump ) = @ARGV;
die "usage: gen_lava_fx.pl <out raw dir> <zm_prison dump dir>\n" unless $raw && $dump;
my $gh = $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0';
my $xi = "$gh/exported_files/black_ops_3/ximages";
my $PI = 4 * atan2( 1, 1 );
sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; ( my $d = $f ) =~ s{/[^/]+$}{}; make_path($d); open my $h, '>:raw', $f or die "$f: $!\n"; print $h $s; close $h }
my $json = JSON::PP->new->pretty->canonical;

# ---- textures and the material
sub png { my $n = shift; my $f = "$xi/$n.png"; die "gen_lava_fx.pl: $n.png is not in $xi\n" unless -f $f; MgPng::read($f) }
make_path("$raw/images");
my $col = png('i_pbr_lava_magma_emissive_1_mtl_c');
my $emi = png('i_pbr_lava_magma_emissive_1_mtl_e');
MgDds::write( "$raw/images/_mg_lava_c.dds", $col, 'bc1' );
MgDds::write( "$raw/images/_mg_lava_e.dds", $emi, 'bc1' );
MgDds::write( "$raw/images/_mg_lava_n.dds", png('i_pbr_lava_magma_emissive_1_mtl_n'), 'bc5' );
{    # the glow shows where the emission is bright
    my @px = @{ $emi->{px} };
    for ( my $i = 0; $i < @px; $i += 4 ) { my $l = int( 0.3 * $px[$i] + 0.59 * $px[ $i + 1 ] + 0.11 * $px[ $i + 2 ] ); @px[ $i .. $i + 2 ] = ( $l, $l, $l ) }
    MgDds::write( "$raw/images/_mg_lava_reveal.dds", { %$emi, px => \@px }, 'bc1' );
    MgDds::write( "$raw/images/_mg_lava_s.dds", { w => 4, h => 4, px => [ ( 30, 22, 18, 90 ) x 16 ] }, 'bc3' );
}
my $mat = decode_json( slurp("$dump/materials/mc/mtl_t6_wpn_zmb_blundergat_acid.json") );
my %img = ( Diffuse_Map => '*mg_lava_c', Ember_Map => '*mg_lava_e', EmberGlow_Reveal_Map => '*mg_lava_reveal', Normal_Map => '*mg_lava_n',
    SpecularAndGloss => '*mg_lava_s' );
for my $t ( @{ $mat->{textures} } ) { $t->{image} = $img{ $t->{name} } if defined $t->{name} && exists $img{ $t->{name} } }
my %lava = ( Emissiver_Amount => 20, Flicker_Min => 0.55, Flicker_Max => 1.5, Heat_Scale => 2, Ember_Scale => 1,
    Heat_Direction => [ 0.06, 0.1 ], Ember_Direction => [ -0.04, -0.07 ] );
for my $c ( @{ $mat->{constants} || [] } ) {
    my $v = $lava{ $c->{name} } // next;
    my @v = ref $v ? @$v : ($v);
    $c->{literal}[$_] = $v[$_] for 0 .. $#v;
}
spit( "$raw/materials/mc/mg_lava.json", $json->encode($mat) );

# ---- meshes (glTF Y-up inches, as the Linker reads them)
sub noise3 {    # smooth deterministic noise on a direction, -1..1
    my ( $x, $y, $z, $seed ) = @_;
    my $n = sin( 3.1 * $x + 1.7 * $seed ) * cos( 2.3 * $y + 0.9 * $seed ) + 0.6 * sin( 5.3 * $z - 2.1 * $x + $seed )
        + 0.35 * sin( 8.9 * $y + 4.1 * $z + 0.5 * $seed );
    return $n / 1.95;
}
sub write_rigid {    # (name, [ [x,y,z] ], [ [u,v] ], [ tri idx ])
    my ( $name, $pos, $uv, $idx ) = @_;
    my @nrm = map { [ 0, 0, 0 ] } @$pos;
    for ( my $i = 0; $i < @$idx; $i += 3 ) {
        my ( $a, $b, $c ) = @$idx[ $i .. $i + 2 ];
        my @u = map { $pos->[$b][$_] - $pos->[$a][$_] } 0 .. 2;
        my @v = map { $pos->[$c][$_] - $pos->[$a][$_] } 0 .. 2;
        my @n = ( $u[1] * $v[2] - $u[2] * $v[1], $u[2] * $v[0] - $u[0] * $v[2], $u[0] * $v[1] - $u[1] * $v[0] );
        for my $k ( $a, $b, $c ) { $nrm[$k][$_] += $n[$_] for 0 .. 2 }
    }
    for my $n (@nrm) { my $l = sqrt( $n->[0]**2 + $n->[1]**2 + $n->[2]**2 ) || 1; $_ /= $l for @$n }
    my @mn = ( 1e9, 1e9, 1e9 );
    my @mx = ( -1e9, -1e9, -1e9 );
    for my $p (@$pos) { for my $k ( 0 .. 2 ) { $mn[$k] = $p->[$k] if $p->[$k] < $mn[$k]; $mx[$k] = $p->[$k] if $p->[$k] > $mx[$k] } }
    my $pb = join '', map { pack 'f<3', @$_ } @$pos;
    my $nb = join '', map { pack 'f<3', @$_ } @nrm;
    my $ub = join '', map { pack 'f<2', @$_ } @$uv;
    my $ib = pack 'v*', @$idx;
    $ib .= "\0\0" if length($ib) % 4;
    my $bin = $pb . $nb . $ub . $ib;
    my $n = scalar @$pos;
    my @views = ( [ 0, length $pb, 34962 ], [ length $pb, length $nb, 34962 ], [ length( $pb ) + length( $nb ), length $ub, 34962 ],
        [ length( $pb ) + length( $nb ) + length( $ub ), 2 * @$idx, 34963 ] );
    my %g = (
        asset => { version => '2.0', generator => 'Magmagat gen_lava_fx.pl' }, scene => 0, scenes => [ { nodes => [0] } ],
        nodes => [ { name => 'tag_origin', children => [1] }, { name => 'surf0', mesh => 0 } ],
        meshes => [ { primitives => [ { attributes => { POSITION => 0, NORMAL => 1, TEXCOORD_0 => 2 }, indices => 3, material => 0, mode => 4 } ] } ],
        materials => [ { name => 'mc/mg_lava', doubleSided => JSON::PP::true } ],
        bufferViews => [ map { { buffer => 0, byteOffset => $_->[0], byteLength => $_->[1], target => $_->[2] } } @views ],
        accessors => [ { bufferView => 0, componentType => 5126, type => 'VEC3', count => $n, min => \@mn, max => \@mx },
            { bufferView => 1, componentType => 5126, type => 'VEC3', count => $n }, { bufferView => 2, componentType => 5126, type => 'VEC2', count => $n },
            { bufferView => 3, componentType => 5123, type => 'SCALAR', count => scalar @$idx } ],
        buffers => [ { byteLength => length $bin, uri => 'data:application/octet-stream;base64,' . encode_base64( $bin, '' ) } ],
    );
    spit( "$raw/model_export/${name}_lod0.gltf", encode_json( \%g ) );
    my @ctr = map { ( $mn[$_] + $mx[$_] ) / 2 } 0 .. 2;
    my $range = sqrt( ( $mx[0] - $mn[0] )**2 + ( $mx[1] - $mn[1] )**2 + ( $mx[2] - $mn[2] )**2 ) / 2;
    spit( "$raw/xmodel/$name.json", $json->encode( { '$schema' => 'http://openassettools.dev/schema/xmodel.v1.json', _game => 't6',
        _type => 'xmodel', _version => 2, collLod => -1, flags => 0, type => 'rigid', rootBoneName => 'tag_origin',
        lods => [ { distance => 4000, file => "model_export/${name}_lod0.gltf" } ],
        lightingOriginOffset => { x => 0 + sprintf( '%.3f', $ctr[0] ), y => 0 + sprintf( '%.3f', -$ctr[2] ), z => 0 + sprintf( '%.3f', $ctr[1] ) },
        lightingOriginRange => 0 + sprintf( '%.3f', $range ) } ) );
    printf "gen_lava_fx.pl: %s, %d verts, %d tris\n", $name, $n, @$idx / 3;
}

# the blob: an icosphere (3 subdivisions), each vertex pushed out by the noise
{
    my $t = ( 1 + sqrt 5 ) / 2;
    my @v = map { my $l = sqrt( $_->[0]**2 + $_->[1]**2 + $_->[2]**2 ); [ map { $_ / $l } @$_ ] }
        ( [ -1, $t, 0 ], [ 1, $t, 0 ], [ -1, -$t, 0 ], [ 1, -$t, 0 ], [ 0, -1, $t ], [ 0, 1, $t ], [ 0, -1, -$t ], [ 0, 1, -$t ],
        [ $t, 0, -1 ], [ $t, 0, 1 ], [ -$t, 0, -1 ], [ -$t, 0, 1 ] );
    my @f = ( [ 0, 11, 5 ], [ 0, 5, 1 ], [ 0, 1, 7 ], [ 0, 7, 10 ], [ 0, 10, 11 ], [ 1, 5, 9 ], [ 5, 11, 4 ], [ 11, 10, 2 ], [ 10, 7, 6 ], [ 7, 1, 8 ],
        [ 3, 9, 4 ], [ 3, 4, 2 ], [ 3, 2, 6 ], [ 3, 6, 8 ], [ 3, 8, 9 ], [ 4, 9, 5 ], [ 2, 4, 11 ], [ 6, 2, 10 ], [ 8, 6, 7 ], [ 9, 8, 1 ] );
    for ( 1 .. 3 ) {
        my %mid;
        my $m = sub {
            my ( $a, $b ) = sort { $a <=> $b } @_;
            return $mid{"$a,$b"} //= do {
                my @p = map { ( $v[$a][$_] + $v[$b][$_] ) / 2 } 0 .. 2;
                my $l = sqrt( $p[0]**2 + $p[1]**2 + $p[2]**2 );
                push @v, [ map { $_ / $l } @p ];
                $#v;
            };
        };
        @f = map { my ( $a, $b, $c ) = @$_; my ( $ab, $bc, $ca ) = ( $m->( $a, $b ), $m->( $b, $c ), $m->( $c, $a ) ); ( [ $a, $ab, $ca ], [ $b, $bc, $ab ], [ $c, $ca, $bc ], [ $ab, $bc, $ca ] ) } @f;
    }
    my $r = 3;
    my @pos = map { my $s = $r * ( 1 + 0.24 * noise3( @$_, 1.3 ) ); [ map { $_ * $s } @$_ ] } @v;
    my @uv = map { [ 0.5 + atan2( $_->[2], $_->[0] ) / ( 2 * $PI ), 0.5 - asin_( $_->[1] ) / $PI ] } @v;
    write_rigid( 'mg_lava_blob', \@pos, \@uv, [ map { @$_ } @f ] );
}
sub asin_ { my $x = shift; $x = 1 if $x > 1; $x = -1 if $x < -1; atan2( $x, sqrt( 1 - $x * $x ) ) }

# the pool: a flat molten splat, domed a little, its rim wobbling (up = +Y)
{
    my ( $rings, $segs, $radius ) = ( 7, 48, 30 );
    my @pos = ( [ 0, 0.9, 0 ] );
    my @uv = ( [ 0.5, 0.5 ] );
    for my $ring ( 1 .. $rings ) {
        for my $s ( 0 .. $segs - 1 ) {
            my $a = 2 * $PI * $s / $segs;
            my $edge = 1 + 0.28 * noise3( cos $a, sin $a, 0.3, 2.7 ) + 0.1 * sin( 7 * $a );
            my $r = $radius * $edge * $ring / $rings;
            my $h = 0.9 * ( 1 - ( $ring / $rings )**2 ) + 0.15;
            my ( $x, $z ) = ( $r * cos $a, $r * sin $a );
            push @pos, [ $x, $h, $z ];
            push @uv, [ 0.5 + $x / ( 2.2 * $radius ), 0.5 + $z / ( 2.2 * $radius ) ];
        }
    }
    my @idx;
    push @idx, 0, 1 + ( $_ + 1 ) % $segs, 1 + $_ for 0 .. $segs - 1;
    for my $ring ( 1 .. $rings - 1 ) {
        my ( $a0, $b0 ) = ( 1 + ( $ring - 1 ) * $segs, 1 + $ring * $segs );
        for my $s ( 0 .. $segs - 1 ) {
            my $s1 = ( $s + 1 ) % $segs;
            push @idx, $a0 + $s, $a0 + $s1, $b0 + $s1, $a0 + $s, $b0 + $s1, $b0 + $s;
        }
    }
    write_rigid( 'mg_lava_pool', \@pos, \@uv, \@idx );
}
