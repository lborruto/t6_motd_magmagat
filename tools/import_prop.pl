#!/usr/bin/perl
# Imports one Greyhound xmodel export (BO3 / T7, .XMODEL_EXPORT + .gltf per LOD) as a T6 rigid prop in mod/props (MG_RAW overrides):
#   - every colour / normal texture it uses: PNG (Greyhound's ximages folder) -> DDS (tools/png2dds.pl),
#     <raw>/images/_mg_<source name>.dds, used as image "*mg_<source name>": a '*' image is embedded in mod.ff
#     (a plain name makes the Linker write a streamed image, which T6 only finds in its own .ipak files)
#   - one material per surface, <raw>/materials/mc/<prop>_m<n>.json, cloned from the vanilla zm_prison wood barrel (dumped by tools/dump_game.pl)
#     material (techset mc_lit_sm_r0c0n0x0_q361191u = colour + normal, lit; the Linker resolves it from zm_prison.ff)
#   - every LOD (at most 4) as a rigid glTF (buffer embedded) with its materials renamed to those, <raw>/model_export/<prop>_lod<k>
#   - <raw>/xmodel/<prop>.json (rigid, the LOD list); tools/import_all.pl lists it in mod/zone_source/mod.zone
# A texture Greyhound only gave as a $placeholder becomes the engine's own: global_normal_flat_16x16 / $white.
# Textures are looked up in the ximages folder, then in the model's own _images/<material>/ folder.
#
#   perl tools/import_prop.pl [options] <greyhound xmodel dir> <prop name> [ximages dir]
#     --skip <regex>              drop the surfaces whose BO3 material matches (e.g. a transparent overlay shell)
#     --color <regex>=<png>       use this colour map for the matching material (e.g. one baked by tools/bake_layers.pl)
#   e.g. perl tools/import_prop.pl C:/Games/t6/Greyhound-1.49.4.0/exported_files/black_ops_3_sp/xmodels/p8_zm_esc_barrel_wood_01 mg_barrel
# Env: MG_TEMPLATE_MTL (the template material json).
use strict;
use warnings;
use FindBin;
use File::Path qw(make_path);
use File::Basename qw(basename);
use JSON::PP;
use MIME::Base64 qw(encode_base64);
use Getopt::Long;

my ( @skip, %color_for );
GetOptions( 'skip=s' => \@skip, 'color=s' => \%color_for ) or die "import_prop.pl: bad options\n";
my ( $src, $prop, $ximages ) = @ARGV;
die "usage: import_prop.pl [--skip re] [--color re=png] <greyhound xmodel dir> <prop name> [ximages dir]\n" unless $src && $prop;
sub skipped { my $name = shift; return scalar grep { $name =~ /$_/ } @skip }
$src =~ s{\\}{/}g;
$ximages //= "$src/../../../black_ops_3/ximages";
my $repo = "$FindBin::Bin/..";
my $raw = $ENV{MG_RAW} // "$repo/mod/props";
my $tmpl_path = $ENV{MG_TEMPLATE_MTL} // "$repo/mod/work/dump/materials/mc/mtl_p6_zm_al_wood_barrel_01.json";
die "import_prop.pl: no template material at $tmpl_path (perl tools/dump_game.pl dumps it)\n" unless -f $tmpl_path;
make_path( "$raw/images", "$raw/materials/mc", "$raw/model_export", "$raw/xmodel" );

sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; open my $h, '>:raw', $f or die "$f: $!\n"; print $h $s; close $h }

# LOD files
opendir my $dh, $src or die "$src: $!\n";
my @lods = sort grep { /_LOD\d+\.XMODEL_EXPORT$/ } readdir $dh;
closedir $dh;
die "import_prop.pl: no *_LOD<n>.XMODEL_EXPORT in $src\n" unless @lods;
@lods = @lods[ 0 .. 3 ] if @lods > 4;    # T6 models take at most 4 LODs

# material name -> { color, normal } source image basenames, in first-seen order over every LOD's glTF
# (a lower LOD can use a material LOD0 does not)
my ( %mat, @mat_order );
for my $lod (@lods) {
    ( my $gl = $lod ) =~ s/\.XMODEL_EXPORT$/.gltf/;
    my $j = decode_json( slurp("$src/$gl") );
    for my $m ( @{ $j->{materials} } ) {
    next if $mat{ $m->{name} };
    push @mat_order, $m->{name} unless skipped( $m->{name} );
    my %t = ( dir => $m->{name} );
    my $ci = $m->{pbrMetallicRoughness}{baseColorTexture}{index};
    my $ni = $m->{normalTexture}{index};
    for ( [ color => $ci ], [ normal => $ni ] ) {
        my ( $k, $ti ) = @$_;
        next unless defined $ti;
        my $uri = $j->{images}[ $j->{textures}[$ti]{source} ]{uri};
        $uri =~ s{.*[\\/]}{};
        $uri =~ s/\.png$//i;
        $t{$k} = $uri;
    }
    $mat{ $m->{name} } = \%t;
  }
}

# textures: PNG -> DDS, once each
my %img_done;
sub image_for {
    my ( $name, $kind, $dir, $png ) = @_;
    return $kind eq 'normal' ? 'global_normal_flat_16x16' : '$white' if !defined $name || $name =~ /^\$/;
    my $ours = "*mg_$name";
    return $ours if $img_done{$ours}++;
    ($png) = grep { -f $_ } "$ximages/$name.png", "$src/_images/$dir/$name.png" unless defined $png;
    if ( !defined $png ) {
        warn "import_prop.pl: $name.png not in $ximages nor the model's _images/$dir, using the engine placeholder\n";
        return $kind eq 'normal' ? 'global_normal_flat_16x16' : '$white';
    }
    my $dds = "$raw/images/_mg_$name.dds";
    if ( !-f $dds ) {
        system( 'perl', "$FindBin::Bin/png2dds.pl", $png, $dds ) == 0 or die "png2dds failed on $png\n";
    }
    return $ours;
}

# materials, cloned from the template
my $tmpl = decode_json( slurp($tmpl_path) );
my %ours_of;
for my $idx ( 0 .. $#mat_order ) {
    my $srcname = $mat_order[$idx];
    my $t = $mat{$srcname};
    my $m = decode_json( encode_json($tmpl) );
    my ($ckey) = grep { $srcname =~ /$_/ } sort keys %color_for;
    if ( defined $ckey ) {
        ( $t->{color} = $color_for{$ckey} ) =~ s{.*[\/]}{};
        $t->{color} =~ s/\.png$//i;
    }
    for my $tex ( @{ $m->{textures} } ) {
        $tex->{image} = image_for( $t->{color}, 'color', $t->{dir}, defined $ckey ? $color_for{$ckey} : undef ) if $tex->{name} eq 'colorMap';
        $tex->{image} = image_for( $t->{normal}, 'normal', $t->{dir} ) if $tex->{name} eq 'normalMap';
    }
    my $mname = "${prop}_m$idx";
    spit( "$raw/materials/mc/$mname.json", JSON::PP->new->pretty->canonical->encode($m) );
    $ours_of{$srcname} = "mc/$mname";
    printf "import_prop.pl: material mc/%s <- %s (color %s, normal %s)\n", $mname, $srcname, $t->{color} // '-', $t->{normal} // '-';
}

# LODs with our material names
my @lodjson;
my @dist = ( 300, 700, 1500, 3000, 5000, 8000 );
my $root;
for my $k ( 0 .. $#lods ) {
    ($root) = slurp("$src/$lods[$k]") =~ /^BONE 0 -1 "([^"]+)"/m if $k == 0;
    # the Linker reads glTF, not XMODEL_EXPORT: Greyhound's glTF of the same LOD, made rigid (no skin) with our material names
    ( my $gl = $lods[$k] ) =~ s/\.XMODEL_EXPORT$/.gltf/;
    my $g = decode_json( slurp("$src/$gl") );
    # skipped surfaces go; a mesh left with none goes too (its nodes lose their mesh)
    my ( @meshes, %new_index );
    for my $mi ( 0 .. $#{ $g->{meshes} } ) {
        my $mesh = $g->{meshes}[$mi];
        $mesh->{primitives} = [ grep { !skipped( $g->{materials}[ $_->{material} ]{name} ) } @{ $mesh->{primitives} } ];
        next unless @{ $mesh->{primitives} };
        $new_index{$mi} = scalar @meshes;
        push @meshes, $mesh;
    }
    $g->{meshes} = \@meshes;
    for my $node ( @{ $g->{nodes} } ) {
        next unless defined $node->{mesh};
        if ( defined $new_index{ $node->{mesh} } ) { $node->{mesh} = $new_index{ $node->{mesh} } }
        else                                       { delete $node->{mesh} }
    }
    # the Linker loads every listed material, so only the used ones stay
    my ( @used, %mat_index );
    for my $p ( map { @{ $_->{primitives} } } @meshes ) {
        $mat_index{ $p->{material} } //= do { push @used, $g->{materials}[ $p->{material} ]; $#used };
        $p->{material} = $mat_index{ $p->{material} };
    }
    $g->{materials} = \@used;
    $_->{name} = $ours_of{ $_->{name} } // $_->{name} for @{ $g->{materials} };
    delete $g->{skins};
    delete $_->{skin} for @{ $g->{nodes} };
    for my $mesh ( @{ $g->{meshes} } ) { delete @{ $_->{attributes} }{qw(JOINTS_0 WEIGHTS_0)} for @{ $mesh->{primitives} } }
    delete @$g{qw(images textures samplers)};
    for my $m ( @{ $g->{materials} } ) { delete $m->{pbrMetallicRoughness}{baseColorTexture}; delete $m->{normalTexture} }
    die "import_prop.pl: $gl has more than one buffer\n" if @{ $g->{buffers} } != 1;
    my $buf = slurp( "$src/" . $g->{buffers}[0]{uri} );
    # Greyhound's glTF is Z-up in centimetres, the Linker's is Y-up in inches (like its own dumps): (x, y, z) -> (x, z, -y) / 2.54
    my %seen;
    for my $mesh ( @{ $g->{meshes} } ) {
        for my $p ( @{ $mesh->{primitives} } ) {
            for my $attr ( [ POSITION => 1 / 2.54 ], [ NORMAL => 1 ] ) {
                my ( $name, $scale ) = @$attr;
                my $ai = $p->{attributes}{$name};
                next if !defined $ai || $seen{$ai}++;
                my $a = $g->{accessors}[$ai];
                my $bv = $g->{bufferViews}[ $a->{bufferView} ];
                my $stride = $bv->{byteStride} // 12;
                my $base = ( $bv->{byteOffset} // 0 ) + ( $a->{byteOffset} // 0 );
                my @mn = ( 1e9, 1e9, 1e9 );
                my @mx = ( -1e9, -1e9, -1e9 );
                for my $v ( 0 .. $a->{count} - 1 ) {
                    my ( $x, $y, $z ) = unpack( 'f<3', substr( $buf, $base + $v * $stride, 12 ) );
                    my @n = ( $x * $scale, $z * $scale, -$y * $scale );
                    substr( $buf, $base + $v * $stride, 12 ) = pack( 'f<3', @n );
                    for my $i ( 0 .. 2 ) { $mn[$i] = $n[$i] if $n[$i] < $mn[$i]; $mx[$i] = $n[$i] if $n[$i] > $mx[$i] }
                }
                @$a{qw(min max)} = ( \@mn, \@mx ) if $a->{min};
            }
        }
    }
    # the Linker only takes embedded buffers
    $g->{buffers}[0]{uri} = "data:application/octet-stream;base64," . encode_base64( $buf, "" );
    my $out = "model_export/${prop}_lod$k.gltf";
    spit( "$raw/$out", JSON::PP->new->pretty->canonical->encode($g) );
    push @lodjson, { distance => $dist[$k] // 10000, file => $out };
}
# lighting origin = the centre of LOD0's vertex bounds, range = half its diagonal (the dumped vanilla props do the same)
my @mn = ( 1e9, 1e9, 1e9 );
my @mx = ( -1e9, -1e9, -1e9 );
my $lod0 = slurp("$src/$lods[0]");
while ( $lod0 =~ /^OFFSET (-?[\d.e+-]+), (-?[\d.e+-]+), (-?[\d.e+-]+)/mg ) {
    my @v = ( $1, $2, $3 );
    for my $i ( 0 .. 2 ) { $mn[$i] = $v[$i] if $v[$i] < $mn[$i]; $mx[$i] = $v[$i] if $v[$i] > $mx[$i] }
}
my @ctr = map { ( $mn[$_] + $mx[$_] ) / 2 } 0 .. 2;
my $range = sqrt( ( $mx[0] - $mn[0] )**2 + ( $mx[1] - $mn[1] )**2 + ( $mx[2] - $mn[2] )**2 ) / 2;
my $xm = { '$schema' => 'http://openassettools.dev/schema/xmodel.v1.json', _game => 't6', _type => 'xmodel', _version => 2,
    collLod => -1, flags => 0, lods => \@lodjson, type => 'rigid',
    lightingOriginOffset => { x => 0 + sprintf( '%.3f', $ctr[0] ), y => 0 + sprintf( '%.3f', $ctr[1] ), z => 0 + sprintf( '%.3f', $ctr[2] ) },
    lightingOriginRange => 0 + sprintf( '%.3f', $range ) };
$xm->{rootBoneName} = $root if $root;
spit( "$raw/xmodel/$prop.json", JSON::PP->new->pretty->canonical->encode($xm) );
printf "import_prop.pl: %s: %d LODs, %d materials, %d new images\n", $prop, scalar(@lods), scalar( keys %ours_of ), scalar( grep { $img_done{$_} == 1 } keys %img_done );
