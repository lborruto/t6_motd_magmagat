#!/usr/bin/perl
# Builds the BO3 prop viewer: one self-contained HTML page (three.js from jsDelivr) that shows Greyhound exports
# (LOD0 glTF, Z-up centimetres) with their real textures, at T6 scale (inches), next to a 72-inch player for size.
# Used to pick which BO3 model to import with tools/import_prop.pl.
#
#   perl tools/pickers/gen_prop_viewer.pl [out.html]
# Env: MG_GREYHOUND (the Greyhound folder). Textures are downscaled by PowerShell / System.Drawing (JPEG when opaque,
# PNG when the texture has alpha) so the page stays small.
use strict;
use warnings;
use FindBin;
use JSON::PP;
use MIME::Base64 qw(encode_base64);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $out = shift // "$FindBin::Bin/../../release/prop_viewer.html";
my $gh = $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0';
my $xm = "$gh/exported_files/black_ops_3_sp/xmodels";
my $xi = "$gh/exported_files/black_ops_3/ximages";

# [ group, BO3 model, what it is, our import name or '' ]
my @models = (
    [ 'Barrels', 'p7_zm_gen_barrel_metal_55gal_green_drk_lod', '55-gallon metal drum, dark green', 'mg_barrel_green' ],
    [ 'Barrels', 'p7_slu_barrel_metal_02_blue_dmg', 'Metal barrel, blue, dented', 'mg_barrel_blue' ],
    [ 'Barrels', 'p8_zm_esc_barrel_wood_01', 'Wooden barrel (MOTD remake)', 'mg_barrel' ],
    [ 'Barrels', 'p7_barrel_vintage_wood_lid', 'Wooden barrel lid', '' ],
    [ 'Forge props', 'p8_zm_esc_fireplace_vintage', 'Vintage fireplace', '' ],
    [ 'Forge props', 'p8_zm_esc_skull_pile_01', 'Skull pile', '' ],
    [ 'Forge props', 'p7_zm_zod_skull', 'Single skull', '' ],
    [ 'Forge props', 'p8_zm_esc_candle_tall', 'Tall candle', '' ],
    [ 'Forge props', 'p8_zm_esc_candle_med_melt_on', 'Melted candle, lit', '' ],
    [ 'Weapon', 'wpn_t8_zm_magmagat_view', 'Magmagat (first-person model)', '' ],
);

sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }

my $tmp = tempdir( CLEANUP => 1 );
# PowerShell needs Windows paths (this perl may be the MSYS one, whose temp dir is /tmp)
sub winpath { my $p = shift; return $p if $p =~ /^[A-Za-z]:/; chomp( my $w = `cygpath -m "$p"` ); $w }
my ( @jobs, %job_of );    # textures to shrink: [ src png, dst base, max px ]
my @entries;
for my $m (@models) {
    my ( $group, $name, $label, $ours ) = @$m;
    my ($gl) = glob("$xm/$name/*_LOD0.gltf");
    die "gen_prop_viewer.pl: no LOD0 glTF for $name in $xm\n" unless $gl;
    my $g = decode_json( slurp($gl) );
    ( my $dir = $gl ) =~ s{/[^/]+$}{};

    # rigid: no skin, every mesh node in the scene
    delete $g->{skins};
    delete $_->{skin} for @{ $g->{nodes} };
    for my $mesh ( @{ $g->{meshes} } ) { delete @{ $_->{attributes} }{qw(JOINTS_0 WEIGHTS_0)} for @{ $mesh->{primitives} } }
    $g->{scenes} = [ { nodes => [ grep { defined $g->{nodes}[$_]{mesh} } 0 .. $#{ $g->{nodes} } ] } ];
    $g->{scene} = 0;
    die "gen_prop_viewer.pl: $name has more than one buffer\n" if @{ $g->{buffers} } != 1;
    $g->{buffers}[0]{uri} = 'data:application/octet-stream;base64,' . encode_base64( slurp( "$dir/" . $g->{buffers}[0]{uri} ), '' );

    # textures: the real ones from the ximages folder, a placeholder ($...) or a missing one is dropped
    my @missing;
    my %is_normal;
    for my $mt ( @{ $g->{materials} } ) { $is_normal{ $mt->{normalTexture}{index} } = 1 if $mt->{normalTexture} }
    my @keep_img;
    for my $ii ( 0 .. $#{ $g->{images} } ) {
        ( my $base = $g->{images}[$ii]{uri} ) =~ s{.*[\\/]}{};
        $base =~ s/\.png$//i;
        my $src = "$xi/$base.png";
        if ( $base =~ /^\$/ || !-f $src ) {
            push @missing, $base unless $base =~ /^\$/;
            $keep_img[$ii] = 0;
            next;
        }
        my $normal = grep { $is_normal{$_} && $g->{textures}[$_]{source} == $ii } 0 .. $#{ $g->{textures} };
        my $max = $normal ? 256 : 512;
        $job_of{"$src|$max"} //= do { push @jobs, [ $src, "$tmp/t" . scalar(@jobs), $max, $normal ? 1 : 0 ]; $#jobs };
        $g->{images}[$ii] = { __job => $job_of{"$src|$max"} };
        $keep_img[$ii] = 1;
    }
    for my $mt ( @{ $g->{materials} } ) {
        my $pbr = $mt->{pbrMetallicRoughness} //= {};
        $pbr->{metallicFactor} = 0;
        $pbr->{roughnessFactor} = 0.8;
        for my $slot ( [ $pbr, 'baseColorTexture' ], [ $mt, 'normalTexture' ] ) {
            my ( $h, $k ) = @$slot;
            next unless $h->{$k};
            my $src = $g->{textures}[ $h->{$k}{index} ]{source};
            delete $h->{$k} unless $keep_img[$src];
        }
        delete $pbr->{metallicRoughnessTexture};
        delete $mt->{occlusionTexture};
        delete $mt->{emissiveTexture};
    }
    my $verts = 0;
    for my $mesh ( @{ $g->{meshes} } ) { $verts += $g->{accessors}[ $_->{attributes}{POSITION} ]{count} for @{ $mesh->{primitives} } }
    push @entries, { group => $group, name => $name, label => $label, ours => $ours, gltf => $g, verts => $verts,
        materials => scalar @{ $g->{materials} }, missing => [ sort keys %{ { map { $_ => 1 } @missing } } ] };
}

# shrink every texture in one PowerShell run
{
    my $list = "$tmp/jobs.txt";
    open my $h, '>', $list or die;
    print $h join( "\t", winpath( $_->[0] ), winpath( $_->[1] ), $_->[2], $_->[3] ), "\n" for @jobs;
    close $h;
    my $ps = "$tmp/shrink.ps1";
    open $h, '>', $ps or die;
    print $h <<'PS';
param([string]$list)
Add-Type -AssemblyName System.Drawing
$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 82L
foreach ($line in Get-Content $list) {
  $src, $dst, $max, $isnormal = $line -split "`t"
  $img = [System.Drawing.Image]::FromFile($src)
  $s = [Math]::Min(1.0, [double]$max / [Math]::Max($img.Width, $img.Height))
  $w = [Math]::Max(1, [int]($img.Width * $s)); $h = [Math]::Max(1, [int]($img.Height * $s))
  $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gr = [System.Drawing.Graphics]::FromImage($bmp)
  $gr.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gr.DrawImage($img, 0, 0, $w, $h)
  $gr.Dispose(); $img.Dispose()
  $alpha = $false
  # a normal map's alpha is not opacity: always JPEG
  for ($y = 0; $isnormal -ne "1" -and $y -lt $h -and -not $alpha; $y += [Math]::Max(1, [int]($h / 32))) {
    for ($x = 0; $x -lt $w; $x += [Math]::Max(1, [int]($w / 32))) { if ($bmp.GetPixel($x, $y).A -lt 250) { $alpha = $true; break } }
  }
  if ($alpha -and [Math]::Max($w, $h) -gt 384) {
    $s2 = 384.0 / [Math]::Max($w, $h); $w2 = [Math]::Max(1, [int]($w * $s2)); $h2 = [Math]::Max(1, [int]($h * $s2))
    $b2 = New-Object System.Drawing.Bitmap $bmp, $w2, $h2; $bmp.Dispose(); $bmp = $b2
  }
  if ($alpha) { $bmp.Save("$dst.png", [System.Drawing.Imaging.ImageFormat]::Png) }
  else { $bmp.Save("$dst.jpg", $jpeg, $ep) }
  $bmp.Dispose()
}
PS
    close $h;
    system( 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', winpath($ps), winpath($list) ) == 0 or die "gen_prop_viewer.pl: texture shrink failed\n";
}
my @uri;
for my $i ( 0 .. $#jobs ) {
    my $b = $jobs[$i][1];
    if    ( -f "$b.jpg" ) { $uri[$i] = 'data:image/jpeg;base64,' . encode_base64( slurp("$b.jpg"), '' ) }
    elsif ( -f "$b.png" ) { $uri[$i] = 'data:image/png;base64,' . encode_base64( slurp("$b.png"), '' ) }
    else                  { die "gen_prop_viewer.pl: no output for $jobs[$i][0]\n" }
}
for my $e (@entries) {
    for my $img ( @{ $e->{gltf}{images} || [] } ) { %$img = ( uri => $uri[ $img->{__job} ] ) if exists $img->{__job} }
}

# the page
my $tpl = slurp("$FindBin::Bin/prop_viewer.tpl.html");
my @meta = map { { group => $_->{group}, name => $_->{name}, label => $_->{label}, ours => $_->{ours}, verts => $_->{verts},
    materials => $_->{materials}, missing => $_->{missing} } } @entries;
my $blocks = join "\n", map {
    my $j = encode_json( $entries[$_]{gltf} );
    $j =~ s{</}{<\\/}g;
    qq{<script type="application/json" id="gltf-$_">$j</script>}
} 0 .. $#entries;
my $meta = encode_json( \@meta );
$tpl =~ s/__META__/$meta/ or die "gen_prop_viewer.pl: no __META__ in the template\n";
$tpl =~ s/__GLTF_BLOCKS__/$blocks/ or die "gen_prop_viewer.pl: no __GLTF_BLOCKS__ in the template\n";
( my $od = $out ) =~ s{/[^/]+$}{};
make_path($od);
open my $o, '>:raw', $out or die "$out: $!\n";
print $o $tpl;
close $o;
printf "gen_prop_viewer.pl: %s, %d models, %d textures, %.1f MB\n", $out, scalar @entries, scalar @jobs, ( -s $out ) / 1048576;
