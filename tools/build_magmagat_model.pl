#!/usr/bin/perl
# The real BO4 Magmagat and tempered Blundergat (Greyhound's exports of wpn_t8_zm_magmagat_view and
# wpn_t8_zm_blundergat_tempered_view from the BO3 remaster) on BO2's Blundergat rig, so it plays the Blundergat's T6 animations. The two rigs are the same skeleton (Treyarch rebuilt the BO2 gun):
# every BO4 bone sits where its T6 bone does, only the names differ (tag_weapon = j_gun, tag_cap_le_animate = j_cap_le,
# ...). So the T6 skeleton is kept as OpenAssetTools dumped it (joint nodes and inverse bind matrices, byte for byte)
# and only the mesh is replaced: BO4 vertices moved into the T6 mesh space (Greyhound: Z-up centimetres; T6: Y-up
# inches), their joints renamed to T6 joints (a BO4-only bone, e.g. the armour's, rides j_gun).
#   mg_magmagat_view / mg_magmus_view      skinned, the Magmus with the armour kit (mg_tempered_view / _up_view the same)
#   mg_magmagat_world / mg_magmus_world    LOD0: the same mesh fitted on the T6 world gun, all on tag_weapon
# Materials: the BO4 colour / normal maps on the Blundergat's lit material; the magma parts on the Acid Gat's
# emberglow shader (reveal = BO4's crack mask, ember = BO4's magma glow noise coloured, heat = vanilla flicker).
# Textures are embedded block-compressed (BC1 colour, BC3 gloss, BC5 normal), at most 1024 px.
#
#   perl tools/build_magmagat_model.pl <out raw dir> <zm_prison dump dir>      (tools/build_weapon.pl runs it)
# Env: MG_GREYHOUND (the Greyhound folder).
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use JSON::PP;
use MIME::Base64 qw(encode_base64 decode_base64);
use File::Path qw(make_path);
use MgPng;
use MgDds;

my ( $raw, $dump ) = @ARGV;
die "usage: build_magmagat_model.pl <out raw dir> <zm_prison dump dir>\n" unless $raw && $dump;
my $gh = $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0';
my $xg = "$gh/exported_files/black_ops_3_sp/xmodels";
my $xi = "$gh/exported_files/black_ops_3/ximages";
# [ BO4 view model, our base gun, our Pack-a-Punched gun (the armour kit), its body in Mob's Pack-a-Punch camo ]: the
# Magmagat (the Magmus wears the camo, as BO4 dresses it in its map's) and the tempered Blundergat the fireplace hands
# back (BO4's own, its canisters burning blue; Pack-a-Punched, the Sweeper's armour only, as BO2's)
my @models = ( [ 'wpn_t8_zm_magmagat_view', 'mg_magmagat', 'mg_magmus', 1 ], [ 'wpn_t8_zm_blundergat_tempered_view', 'mg_tempered', 'mg_tempered_up', 0 ] );

sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; ( my $d = $f ) =~ s{/[^/]+$}{}; make_path($d); open my $h, '>:raw', $f or die "$f: $!\n"; print $h $s; close $h }
my $json = JSON::PP->new->pretty->canonical;

# ---- glTF reading
my %COMPS = ( SCALAR => 1, VEC2 => 2, VEC3 => 3, VEC4 => 4, MAT4 => 16 );
my %FMT = ( 5121 => [ 'C', 1 ], 5123 => [ 'v', 2 ], 5125 => [ 'V', 4 ], 5126 => [ 'f<', 4 ] );
sub load_gltf {
    my ( $file, $dir ) = @_;
    my $g = decode_json( slurp($file) );
    my @bufs;
    for my $b ( @{ $g->{buffers} } ) {
        my $u = $b->{uri};
        push @bufs, $u =~ /^data:/ ? decode_base64( substr( $u, index( $u, ',' ) + 1 ) ) : slurp("$dir/$u");
    }
    $g->{_bufs} = \@bufs;
    return $g;
}
sub accessor {    # -> list of array refs (one per element)
    my ( $g, $ai ) = @_;
    my $a = $g->{accessors}[$ai];
    my $bv = $g->{bufferViews}[ $a->{bufferView} ];
    my ( $f, $sz ) = @{ $FMT{ $a->{componentType} } };
    my $n = $COMPS{ $a->{type} };
    my $stride = $bv->{byteStride} || $n * $sz;
    my $base = ( $bv->{byteOffset} // 0 ) + ( $a->{byteOffset} // 0 );
    my $buf = $g->{_bufs}[ $bv->{buffer} ];
    return map { [ unpack( "$f$n", substr( $buf, $base + $_ * $stride, $n * $sz ) ) ] } 0 .. $a->{count} - 1;
}
sub raw_accessor_bytes {    # the tight bytes of an accessor (for the inverse bind matrices we keep)
    my ( $g, $ai ) = @_;
    my $a = $g->{accessors}[$ai];
    my $bv = $g->{bufferViews}[ $a->{bufferView} ];
    my ( undef, $sz ) = @{ $FMT{ $a->{componentType} } };
    my $len = $COMPS{ $a->{type} } * $sz * $a->{count};
    return substr( $g->{_bufs}[ $bv->{buffer} ], ( $bv->{byteOffset} // 0 ) + ( $a->{byteOffset} // 0 ), $len );
}

# ---- the BO4 meshes
my %t6_of = (
    tag_weapon => 'j_gun', tag_hammer_animate => 'j_hammer', tag_swivel_animate => 'j_swivel', tag_loader_animate => 'j_loader',
    tag_brake_action_animate => 'tag_brake_action', tag_cap_le_animate => 'j_cap_le', tag_cap_ri_animate => 'j_cap_ri',
);
for my $side (qw(le ri)) {
    for my $pos ( [ bottom => 'bo' ], [ upper => 'up' ] ) {
        $t6_of{"tag_ammo_${side}_$pos->[0]_animate"} = "j_ammo_${side}_$pos->[1]";
        $t6_of{"tag_ammo_${side}_$pos->[0]_acid_animate"} = "j_ammo_${side}_$pos->[1]_acid";
    }
}
for my $n ( 1 .. 5 ) { $t6_of{"tag_chain_le_back_${n}_pba"} = "j_chain_le_ba_$n"; $t6_of{"tag_chain_le_front_${n}_pba"} = "j_chain_le_fr_$n" }
my @armor_mats = qw(mtl_wpn_t8_zm_blundergat_armor mtl_wpn_t8_zm_blundergat_armor_ember_red mtl_wpn_t8_zm_blundergat_armor_ember_blue);
my %is_armor = map { $_ => 1 } @armor_mats;
my %lit = (    # BO4 material -> [ colour, normal ]  (lit: the Blundergat's own material)
    mtl_wpn_t8_zm_blundergat_receiver => [ 'i_wpn_t8_zm_blundergat_receiver_c', 'i_wpn_t8_zm_blundergat_receiver_n' ],
    mtl_wpn_t8_zm_blundergat_stock_details => [ 'i_wpn_t8_zm_blundergat_stock_details_c', 'i_wpn_t8_zm_blundergat_stock_details_n' ],
    mtl_wpn_t8_zm_blundergat_stock => [ 'i_wpn_t8_zm_blundergat_stock_c', 'i_wpn_t8_zm_blundergat_stock_n' ],
    mtl_wpn_t8_zm_blundergat_barrel => [ 'i_wpn_t8_zm_blundergat_barrel_c', 'i_wpn_t8_zm_blundergat_barrel_n' ],
    mtl_wpn_t8_zm_blundergat_armor => [ 'i_wpn_t8_zm_blundergat_armor_c', 'i_wpn_t8_zm_blundergat_armor_n' ],
    mtl_wpn_t8_zm_blundergat_frame => [ undef, 'i_wpn_t8_zm_blundergat_frame_n' ],
);
sub bo4_prims {    # a Greyhound export -> ( { mat, pos, nrm, uv, joints (bo4 names x4), weights, idx } ... )
    my $name = shift;
    my $src = "$xg/$name";
    my ($src_gltf) = glob("$src/*_LOD0.gltf");
    die "build_magmagat_model.pl: no Greyhound export of $name in $src\n" unless $src_gltf;
    my $bo4 = load_gltf( $src_gltf, $src );
    my @bo4_joint = map { $bo4->{nodes}[$_]{name} } @{ $bo4->{skins}[0]{joints} };
    my @prims;
    for my $mesh ( @{ $bo4->{meshes} } ) {
        for my $p ( @{ $mesh->{primitives} } ) {
            next if $bo4->{materials}[ $p->{material} ]{name} eq 'nodraw';    # an invisible helper surface
            my $at = $p->{attributes};
            # Greyhound: Z-up centimetres -> T6 view mesh space: Y-up inches, (x, y, z) -> (x, z, -y)
            my @pos = map { [ $_->[0] / 2.54, $_->[2] / 2.54, -$_->[1] / 2.54 ] } accessor( $bo4, $at->{POSITION} );
            my @nrm = map { [ $_->[0], $_->[2], -$_->[1] ] } accessor( $bo4, $at->{NORMAL} );
            push @prims, { mat => $bo4->{materials}[ $p->{material} ]{name}, pos => \@pos, nrm => \@nrm,
                uv => [ accessor( $bo4, $at->{TEXCOORD_0} ) ], jn => [ map { [ map { $bo4_joint[$_] } @$_ ] } accessor( $bo4, $at->{JOINTS_0} ) ],
                wt => [ accessor( $bo4, $at->{WEIGHTS_0} ) ], idx => [ map { $_->[0] } accessor( $bo4, $p->{indices} ) ] };
        }
    }
    return @prims;
}

# ---- output glTF on a T6 template's skeleton
# $weights_for->(bo4 joint names, weights) -> [ joint idx x4 ], [ weight x4 ] in the template's skin
sub write_model {
    my ( $out, $tmpl_file, $prims, $weights_for, $xf ) = @_;
    my $t = load_gltf( $tmpl_file, '.' );
    my @nodes = @{ $t->{nodes} };
    my @keep = grep { !defined $nodes[$_]{mesh} && ( $nodes[$_]{name} // '' ) !~ /_skel$/ } 0 .. $#nodes;
    die "build_magmagat_model.pl: $tmpl_file: the joints are not the first nodes\n" if grep { $keep[$_] != $_ } 0 .. $#keep;
    my ($skel) = grep { ( $nodes[$_]{name} // '' ) =~ /_skel$/ } 0 .. $#nodes;
    my %gl = ( asset => { version => '2.0', generator => 'Magmagat build_magmagat_model.pl' }, scene => 0, materials => [], meshes => [],
        accessors => [], bufferViews => [], skins => [] );
    my $bin = '';
    my $view = sub {    # bytes -> accessor
        my ( $bytes, $ctype, $type, $count, $target, $minmax ) = @_;
        $bin .= "\0" x ( ( 4 - length($bin) % 4 ) % 4 );
        push @{ $gl{bufferViews} }, { buffer => 0, byteOffset => length $bin, byteLength => length $bytes, ( $target ? ( target => $target ) : () ) };
        $bin .= $bytes;
        push @{ $gl{accessors} }, { bufferView => $#{ $gl{bufferViews} }, componentType => $ctype, type => $type, count => $count, %{ $minmax || {} } };
        return $#{ $gl{accessors} };
    };
    my @out_nodes = map { my %n = %{ $nodes[$_] }; \%n } @keep;
    my $ibm = $view->( raw_accessor_bytes( $t, $t->{skins}[0]{inverseBindMatrices} ), 5126, 'MAT4', scalar @{ $t->{skins}[0]{joints} } );
    push @{ $gl{skins} }, { joints => $t->{skins}[0]{joints}, inverseBindMatrices => $ibm, skeleton => $t->{skins}[0]{skeleton} // 0 };
    my @surf;
    my %mat_index;
    for my $p (@$prims) {
        my $mi = $mat_index{ $p->{mat} } //= do { push @{ $gl{materials} }, { name => "mc/mg_bo4_$p->{mat}", doubleSided => JSON::PP::true }; $#{ $gl{materials} } };
        my $n = scalar @{ $p->{pos} };
        my ( @mn, @mx );
        @mn = ( 1e9, 1e9, 1e9 );
        @mx = ( -1e9, -1e9, -1e9 );
        my ( $pb, $nb, $ub, $jb, $wb ) = ( '', '', '', '', '' );
        for my $v ( 0 .. $n - 1 ) {
            my @q = $xf ? $xf->( @{ $p->{pos}[$v] } ) : @{ $p->{pos}[$v] };
            for my $k ( 0 .. 2 ) { $mn[$k] = $q[$k] if $q[$k] < $mn[$k]; $mx[$k] = $q[$k] if $q[$k] > $mx[$k] }
            $pb .= pack( 'f<3', @q );
            $nb .= pack( 'f<3', @{ $p->{nrm}[$v] } );
            $ub .= pack( 'f<2', @{ $p->{uv}[$v] } );
            my ( $j, $w ) = $weights_for->( $p->{jn}[$v], $p->{wt}[$v] );
            $jb .= pack( 'C4', @$j );
            $wb .= pack( 'f<4', @$w );
        }
        my %attr = ( POSITION => $view->( $pb, 5126, 'VEC3', $n, 34962, { min => \@mn, max => \@mx } ), NORMAL => $view->( $nb, 5126, 'VEC3', $n, 34962 ),
            TEXCOORD_0 => $view->( $ub, 5126, 'VEC2', $n, 34962 ), JOINTS_0 => $view->( $jb, 5121, 'VEC4', $n, 34962 ), WEIGHTS_0 => $view->( $wb, 5126, 'VEC4', $n, 34962 ) );
        my $ib = pack( 'v*', @{ $p->{idx} } );
        my $idx = $view->( $ib, 5123, 'SCALAR', scalar @{ $p->{idx} }, 34963 );
        push @{ $gl{meshes} }, { primitives => [ { attributes => \%attr, indices => $idx, material => $mi, mode => 4 } ] };
        push @out_nodes, { name => 'surf' . scalar(@surf), mesh => $#{ $gl{meshes} }, skin => 0 };
        push @surf, $#out_nodes;
    }
    my %sk = %{ $nodes[$skel] };
    $sk{children} = [ ( grep { my $i = $_; !grep { $_ == $i } map { @{ $_->{children} || [] } } @nodes[@keep] } 0 .. $#keep ), @surf ];
    push @out_nodes, \%sk;
    $gl{nodes} = \@out_nodes;
    $gl{scenes} = [ { nodes => [$#out_nodes] } ];
    $gl{buffers} = [ { byteLength => length $bin, uri => 'data:application/octet-stream;base64,' . encode_base64( $bin, '' ) } ];
    spit( $out, encode_json( \%gl ) );
    return \%mat_index;
}

my $t6_view = "$dump/model_export/t6_wpn_zmb_blundergat_view_lod0.gltf";
my $t6_world = "$dump/model_export/t6_wpn_zmb_blundergat_world_lod0.gltf";
my $tv = load_gltf( $t6_view, '.' );
my %t6_joint;
my @tv_joints = @{ $tv->{skins}[0]{joints} };
$t6_joint{ $tv->{nodes}[ $tv_joints[$_] ]{name} } = $_ for 0 .. $#tv_joints;
die "build_magmagat_model.pl: no j_gun in the T6 view skeleton\n" unless defined $t6_joint{j_gun};
my %unmapped;
my $view_weights = sub {
    my ( $names, $w ) = @_;
    my %sum;
    for my $k ( 0 .. 3 ) {
        next unless $w->[$k] > 0;
        my $t = $t6_of{ $names->[$k] } // $names->[$k];
        if ( !defined $t6_joint{$t} ) { $unmapped{ $names->[$k] }++; $t = 'j_gun' }
        $sum{ $t6_joint{$t} } += $w->[$k];
    }
    my @j = sort { $sum{$b} <=> $sum{$a} } keys %sum;
    @j = @j[ 0 .. 3 ] if @j > 4;
    my $tot = 0;
    $tot += $sum{$_} for @j;
    my @w = map { $sum{$_} / $tot } @j;
    push @j, 0 while @j < 4;
    push @w, 0 while @w < 4;
    return ( \@j, \@w );
};

# The BO4 model carries both armour kits: tag_armor (the Sweeper's) and tag_armor_acid, which BO2 hides on its own
# Pack-a-Punched Acid Gat (blundersplat_upgraded_zm hideTags). The armour bones do not exist in T6 (they ride j_gun),
# so the hidden kit's triangles are dropped here instead.
sub without_bone {
    my ( $bone, @in ) = @_;
    my @out;
    for my $p (@in) {
        my @dom = map { my ( $n, $w ) = ( $p->{jn}[$_], $p->{wt}[$_] ); my $b = 0; $w->[$_] > $w->[$b] and $b = $_ for 1 .. 3; $n->[$b] } 0 .. $#{ $p->{pos} };
        my @idx;
        for ( my $i = 0; $i < @{ $p->{idx} }; $i += 3 ) {
            my @t = @{ $p->{idx} }[ $i .. $i + 2 ];
            push @idx, @t unless grep { $dom[$_] eq $bone } @t;
        }
        push @out, { %$p, idx => \@idx } if @idx;
    }
    return @out;
}
# world: the base mesh's box fitted on the T6 world gun's (uniform scale from the length, centres aligned)
sub bounds {
    my @ps = @_;
    my @mn = ( 1e9, 1e9, 1e9 );
    my @mx = ( -1e9, -1e9, -1e9 );
    for my $p (@ps) { for my $k ( 0 .. 2 ) { $mn[$k] = $p->[$k] if $p->[$k] < $mn[$k]; $mx[$k] = $p->[$k] if $p->[$k] > $mx[$k] } }
    return ( \@mn, \@mx );
}
my $tw = load_gltf( $t6_world, '.' );
my @wpos = map { accessor( $tw, $_->{attributes}{POSITION} ) } map { @{ $_->{primitives} } } @{ $tw->{meshes} };
my ( $wmn, $wmx ) = bounds(@wpos);
my $root_only = sub { ( [ 0, 0, 0, 0 ], [ 1, 0, 0, 0 ] ) };

my @all_prims;
for my $m (@models) {
    my ( $src, $base_name, $up_name, $pap ) = @$m;
    my @prims = bo4_prims($src);
    my @base = grep { !$is_armor{ $_->{mat} } } @prims;
    my @up = without_bone( 'tag_armor_acid', @prims );
    @up = map { $lit{ $_->{mat} } && !$is_armor{ $_->{mat} } ? { %$_, mat => "$_->{mat}_pap" } : $_ } @up if $pap;
    push @all_prims, @prims, @up;
    write_model( "$raw/model_export/${base_name}_view_lod0.gltf", $t6_view, \@base, $view_weights );
    write_model( "$raw/model_export/${up_name}_view_lod0.gltf", $t6_view, \@up, $view_weights );
    my ( $bmn, $bmx ) = bounds( map { @{ $_->{pos} } } @base );
    my $s = ( $wmx->[0] - $wmn->[0] ) / ( $bmx->[0] - $bmn->[0] );
    my @off = map { ( $wmn->[$_] + $wmx->[$_] ) / 2 - $s * ( $bmn->[$_] + $bmx->[$_] ) / 2 } 0 .. 2;
    my $to_world = sub { map { $s * $_[$_] + $off[$_] } 0 .. 2 };
    write_model( "$raw/model_export/${base_name}_world_lod0.gltf", $t6_world, \@base, $root_only, $to_world );
    write_model( "$raw/model_export/${up_name}_world_lod0.gltf", $t6_world, \@up, $root_only, $to_world );
    printf "build_magmagat_model.pl: %s: %d surfaces, world scale %.3f\n", $src, scalar @prims, $s;
}
printf "build_magmagat_model.pl: BO4-only bones on j_gun: %s\n", join( ' ', sort keys %unmapped ) || 'none';

# ---- textures
my %tex_done;
sub texture {    # (name, png or code, format, max px, transform) -> '*image'
    my ( $name, $png, $format, $max, $fn ) = @_;
    my $ours = "*mg_bo4_$name";
    return $ours if $tex_done{$ours}++;
    my $img = shrink( ref $png ? $png->() : MgPng::read($png), $max );
    if ($fn) {
        my $px = $img->{px};
        for ( my $i = 0; $i < @$px; $i += 4 ) { @$px[ $i .. $i + 3 ] = map { my $v = int( $_ + 0.5 ); $v < 0 ? 0 : $v > 255 ? 255 : $v } $fn->( @$px[ $i .. $i + 3 ] ) }
    }
    make_path("$raw/images");
    MgDds::write( "$raw/images/_mg_bo4_$name.dds", $img, $format );
    return $ours;
}
sub shrink {    # (image, max px) -> the image, 2x box downscaled until it fits
    my ( $img, $max ) = @_;
    while ( $img->{w} > $max || $img->{h} > $max ) {
        my ( $w, $h, $px ) = @$img{qw(w h px)};
        my ( $nw, $nh ) = ( int( $w / 2 ), int( $h / 2 ) );
        my @d;
        for my $y ( 0 .. $nh - 1 ) {
            for my $x ( 0 .. $nw - 1 ) {
                my ( $o1, $o2 ) = ( ( 2 * $y * $w + 2 * $x ) * 4, ( ( 2 * $y + 1 ) * $w + 2 * $x ) * 4 );
                push @d, map { ( $px->[ $o1 + $_ ] + $px->[ $o1 + 4 + $_ ] + $px->[ $o2 + $_ ] + $px->[ $o2 + 4 + $_ ] + 2 ) >> 2 } 0 .. 3;
            }
        }
        $img = { w => $nw, h => $nh, px => \@d };
    }
    return $img;
}
sub solid { my @c = @_; sub { { w => 4, h => 4, px => [ (@c) x 16 ] } } }
sub png { my $n = shift; my $f = "$xi/$n.png"; die "build_magmagat_model.pl: $n.png is not in $xi\n" unless -f $f; $f }
my $lum = sub { ( 0.3 * $_[0] + 0.59 * $_[1] + 0.11 * $_[2] ) };
# T6 specular map: rgb = specular colour, alpha = gloss. BO4's materials are physically based: a metal's colour map is
# nearly black (5 to 17 / 255 on the Magmagat) and its shine is in its own specular (_s) and gloss (_g) maps, so they
# are taken as they are, gloss into the alpha. A map BO4 does not have: a plain non-metal's specular (0.04, sRGB 56), a
# middling gloss.
my $SPEC_PX = 512;
sub spec_gloss {    # (BO4 texture stem) -> code making the T6 specular map
    my $stem = shift;
    return sub {
        my ( $s, $g ) = map { -f "$xi/${stem}_$_.png" ? shrink( MgPng::read("$xi/${stem}_$_.png"), $SPEC_PX ) : undef } qw(s g);
        my $base = $s // $g // die "build_magmagat_model.pl: ${stem} has neither _s nor _g\n";
        my ( $w, $h ) = @$base{qw(w h)};
        for ( grep { defined } $s, $g ) {
            die "build_magmagat_model.pl: ${stem}: _s and _g sizes differ ($_->{w}x$_->{h} vs ${w}x$h)\n" if $_->{w} != $w || $_->{h} != $h;
        }
        my @px;
        for my $i ( 0 .. $w * $h - 1 ) {
            my $o = $i * 4;
            push @px, $s ? @{ $s->{px} }[ $o .. $o + 2 ] : ( 56, 56, 56 ), $g ? $g->{px}[$o] : 128;
        }
        return { w => $w, h => $h, px => \@px };
    };
}

# ---- materials
my %glow = (    # BO4 material -> [ crust colour source, reveal (crack mask), ember source, colour ]  (emberglow: the Acid Gat's)
    mtl_wpn_t8_zm_blundergat_magma => [ 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_magma_glow_e', 'lava' ],
    mtl_wpn_t8_zm_blundergat_magma_barrel => [ 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_magma_glow_e', 'lava' ],
    mtl_wpn_t8_zm_blundergat_magma_details => [ 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_magma_glow_e', 'lava' ],
    mtl_wpn_t8_zm_blundergat_armor_ember_red => [ 'i_wpn_t8_zm_blundergat_armor_ember_c', 'i_wpn_t8_zm_blundergat_armor_ember_c', 'i_wpn_t8_zm_blundergat_armor_ember_c', 'lava' ],
    # the tempered gun: BO4 tints the acid canisters and the armour's embers blue (the essence)
    mtl_wpn_t8_zm_blundergat_acid_barrel_blue => [ 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_acid_c', 'i_mtl_wpn_t8_zm_blundergat_acid_glow_e', 'blue' ],
    mtl_wpn_t8_zm_blundergat_armor_ember_blue => [ 'i_wpn_t8_zm_blundergat_armor_ember_c', 'i_wpn_t8_zm_blundergat_armor_ember_c', 'i_wpn_t8_zm_blundergat_armor_ember_c', 'blue' ],
);
# colour -> [ crust tint (from the luminance), ember ramp (t = 0..1) ]
my %ramp = (
    lava => [ sub { my $l = shift; ( $l * 1.25, $l * 0.62, $l * 0.45 ) }, sub { my $t = shift; ( 255 * $t**0.55, 185 * $t**1.3, 60 * $t**2.6 ) } ],    # dark red -> orange -> yellow-white
    blue => [ sub { my $l = shift; ( $l * 0.3, $l * 0.42, $l * 1.3 ) }, sub { my $t = shift; ( 45 * $t**2.6, 110 * $t**1.5, 255 * $t**0.6 ) } ],    # deep blue -> blue -> pale blue (no green: BO4's essence)
);
my %lava = ( Emissiver_Amount => 16, Flicker_Min => 0.6, Flicker_Max => 1.45, Heat_Scale => 1.8, Ember_Scale => 1,
    Heat_Direction => [ 0.05, 0.08 ], Ember_Direction => [ -0.03, -0.06 ] );
my $lit_tmpl = decode_json( slurp("$dump/materials/mc/mtl_t6_wpn_zmb_blundergat.json") );
my $glow_tmpl = decode_json( slurp("$dump/materials/mc/mtl_t6_wpn_zmb_blundergat_acid.json") );
# Mob's Pack-a-Punch camo (mtl_weapon_camo_zmb_dlc2, the one vanilla puts on every Pack-a-Punched gun there): a dark
# cracked crust whose cracks glow and flicker as molten. Its own material draws only through T6's camo system (worn
# by a model, it showed no texture), so the Magmus body wears it on the Acid Gat's emberglow shader instead, the same
# glow as the camo's, with the camo's own images (zm_prison's, loaded by name) and the gun's normal map.
my %camo = ( Diffuse_Map => '~-gcamo_zmb_dlc2_col', EmberGlow_Reveal_Map => 'camo_zmb_dlc2_reveal', Ember_Map => 'camo_zmb_dlc2_ember',
    SpecularAndGloss => '~~-gcamo_zmb_dlc2_spc-rgb&~-r~471adc2c' );
# On a gun in hand that crust read too dark (the owner, 2026-10-04: "very somber"): the Magmus takes a copy lifted
# (gamma 0.6, x 1.2); its glow stays the template's (10: the owner found 14 too strong).
my $magmus_crust = texture( 'magmus_crust', sub {
    my $img = MgDds::read("$dump/images/~-gcamo_zmb_dlc2_col.dds");
    my $px = $img->{px};
    for ( my $i = 0; $i < @$px; $i += 4 ) {
        for ( 0 .. 2 ) { my $v = int( 1.2 * 255 * ( $px->[ $i + $_ ] / 255 )**0.6 + 0.5 ); $px->[ $i + $_ ] = $v > 255 ? 255 : $v }
    }
    return $img;
}, 'bc1', 1024 );
sub lit_images {    # BO4 lit material -> its colour, normal and specular maps, by the lit template's slot names
    my ( $c, $n ) = @{ $lit{ $_[0] } };
    ( my $short = $_[0] ) =~ s/^mtl_wpn_t8_zm_blundergat_?//;
    $short ||= 'body';
    ( my $stem = $n ) =~ s/_n$//;
    return (
        colorMap => defined $c ? texture( "${short}_c", png($c), 'bc1', 1024 ) : texture( "${short}_c", solid( 34, 32, 30, 255 ), 'bc1', 4 ),
        normalMap => texture( "${short}_n", png($n), 'bc5', 1024 ),
        specularMap => texture( "${short}_s", spec_gloss($stem), 'bc3', $SPEC_PX ),
    );
}
my %used = map { $_->{mat} => 1 } @all_prims;
for my $m ( sort keys %used ) {
    my $mat;
    if ( $m =~ /^(.+)_pap$/ && $lit{$1} ) {
        my %img = ( %camo, Normal_Map => { lit_images($1) }->{normalMap}, Diffuse_Map => $magmus_crust );
        $mat = decode_json( encode_json($glow_tmpl) );
        for my $t ( @{ $mat->{textures} } ) { $t->{image} = $img{ $t->{name} } if defined $t->{name} && exists $img{ $t->{name} } }    # heat map, rim mask: vanilla
    }
    elsif ( $lit{$m} ) {
        my %img = lit_images($m);
        $mat = decode_json( encode_json($lit_tmpl) );
        for my $t ( @{ $mat->{textures} } ) { $t->{image} = $img{ $t->{name} } // die "build_magmagat_model.pl: lit template slot $t->{name}\n" }
    }
    elsif ( my $g = $glow{$m} ) {
        my ( $crust, $reveal, $ember, $colour ) = @$g;
        my ( $tint, $glow_ramp ) = @{ $ramp{$colour} };
        ( my $short = $m ) =~ s/^mtl_wpn_t8_zm_blundergat_//;
        my %img = (
            # the cooled crust: the crack mask darkened, cast in the colour
            Diffuse_Map => texture( "${short}_crust", png($crust), 'bc1', 1024, sub { ( $tint->( $lum->(@_) * 0.3 + 10 ), 255 ) } ),
            EmberGlow_Reveal_Map => texture( "${short}_reveal", png($reveal), 'bc1', 1024, sub { my $l = $lum->(@_); ( $l, $l, $l, 255 ) } ),
            Ember_Map => texture( "${short}_ember", png($ember), 'bc1', 1024, sub { ( $glow_ramp->( $lum->(@_) / 255 ), 255 ) } ),
            SpecularAndGloss => texture( 'magma_s', solid( 40, 30, 24, 120 ), 'bc3', 4 ),
            Normal_Map => 'global_normal_flat_16x16',
        );
        $mat = decode_json( encode_json($glow_tmpl) );
        for my $t ( @{ $mat->{textures} } ) { $t->{image} = $img{ $t->{name} } if defined $t->{name} && exists $img{ $t->{name} } }    # heat map, rim mask: vanilla
        for my $c ( @{ $mat->{constants} || [] } ) {
            my $v = $lava{ $c->{name} } // next;
            my @v = ref $v ? @$v : ($v);
            $c->{literal}[$_] = $v[$_] for 0 .. $#v;
        }
    }
    else { die "build_magmagat_model.pl: no material recipe for $m\n" }
    spit( "$raw/materials/mc/mg_bo4_$m.json", $json->encode($mat) );
}
printf "build_magmagat_model.pl: %d materials, %d textures\n", scalar keys %used, scalar keys %tex_done;
