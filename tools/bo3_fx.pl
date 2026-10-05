#!/usr/bin/perl
# The BO3 remaster's effects, as T6 effects in mod/fx (never committed): every effect in tools/assets/bo3_fx.tsv and
# every effect they run, from a Bo3Snapshot of the running game (tools/bo3mem, mod/work/bo3mem/fx.bin):
#   - fx/mg/<name>.json: the effect (tools/MgFx7.pm), for the Linker's T6 effect loader (the mod's OpenAssetTools build)
#   - materials/mg_<material>.json: each BO3 effect material as a vanilla zm_prison effect material of the same kind
#     (emissive, blend, cloud, decal; a heat distortion uses vanilla's gfx_distortion_heat) with the BO3 texture and flipbook grid
#   - images/_mg_<image>.dds: the BO3 texture (Greyhound's PNG export), embedded ("*mg_<image>")
#   - fx/mg/fx_mg_forge_fire, fx_mg_forge_flare: two zm_prison fires for the forge, their glow taken out
# then the zone's fx list (// fx ... // end fx in mod/zone_source/mod.zone).
#
#   perl tools/bo3_fx.pl
# Env: MG_GREYHOUND (the Greyhound folder), MG_OAT_FX (the OpenAssetTools build with the T6 effect dumper).
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use File::Path qw(make_path remove_tree);
use JSON::PP;
use MgSnap;
use MgFx7;
use MgPng;
use MgDds;

my $repo = "$FindBin::Bin/..";
my $work = "$repo/mod/work";
my $raw = "$repo/mod/fx";
my $gh = $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0';
my $oat = $ENV{MG_OAT_FX} // 'C:/Games/t6/oat-src/build/bin/Release_x86';
my $bo2 = $ENV{MG_BO2} // 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops II';
my $json = JSON::PP->new->pretty->canonical;
sub winpath { my $p = shift; return $p if $p =~ /^[A-Za-z]:/; chomp( my $w = `cygpath -m "$p"` ); $w }
sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; ( my $d = $f ) =~ s{/[^/]+$}{}; make_path($d); open my $h, '>:raw', $f or die "$f: $!\n"; print $h $s; close $h }

my $snapfile = "$work/bo3mem/fx.bin";
die "bo3_fx.pl: no $snapfile: run tools/bo3mem/Bo3Snapshot.exe with BO3 on the map (docs/PORTING_BO3_ASSETS.md)\n" unless -f $snapfile;

# the vanilla effect materials the BO3 ones become (dumped by the T6 effect dumper)
my $tdump = "$work/fxdump";
unless ( -d "$tdump/materials" ) {
    my $zones = "$bo2/zone/all";
    system( "$oat/Unlinker.exe", '--search-path', winpath($zones), '--include-assets', 'fx,material', '-o', winpath($tdump), winpath("$zones/zm_prison.ff") ) == 0
        or die "bo3_fx.pl: the effect dump failed (set MG_OAT_FX)\n";
}
my %tmpl = (
    # BO3's emissive blend (every "_em" material: effect_lit_emissive_blend) as T6's own, its fire flame alpha-blended
    # and unlit, or as T6's additive fire (depth-feathered) when its HDR makes it glow (hdr_gain); lit blends (smoke,
    # dust) alpha-blended
    emissive_blend => 'gfx_fxt_fire_flame_vert_e_blnd', emissive => 'gfx_fxt_fire_flame_vert_e', blend => 'gfx_fxt_smk_gen_z40',
    cloud => 'gfx_fxt_debris_fire_ember_cloud_01i',
    decal_mc => 'mc/gfx_impact_liquid_spatter01', decal_wc => 'wc/gfx_impact_liquid_spatter01',
);
my %tj = map { $_ => decode_json( slurp("$tdump/materials/$tmpl{$_}.json") ) } keys %tmpl;

# the roots
my @roots;
open my $lh, '<', "$FindBin::Bin/assets/bo3_fx.tsv" or die "bo3_fx.pl: no tools/assets/bo3_fx.tsv\n";
# a line: the BO3 effect, then options: scale=x,y stretches its element origins (an effect laid out in one of the
# remaster's slightly smaller rooms, fitted to BO2's); as=<name> ships a copy instead, mg/<name>, with tint=r,g,b each
# colour its brightness times the tint (the tempered gun's blue muzzle flash), spread=k its elements' sideways
# origins times k (the drums' flame held inside their rim) and size=k its sprites' sizes times k (the drums' flare);
# surface turns its elements that run relative to the world (flags & 0xC0: 0x00) to its spawn (0x40), so it lies on the
# surface it is played on (the lava pool on a wall: its ring of fire stayed level, across the wall)
my ( %scale, %surface, @copies );
while (<$lh>) {
    s/\s*#.*//;
    my ( $n, @opt ) = split;
    next unless defined $n;
    my %o;
    for (@opt) {
        if    (/^scale=([\d.]+),([\d.]+)$/)         { $scale{$n} = [ $1, $2 ] }
        elsif (/^as=(\w+)$/)                        { $o{as} = $1 }
        elsif (/^tint=([\d.]+),([\d.]+),([\d.]+)$/) { $o{tint} = [ $1, $2, $3 ] }
        elsif (/^spread=([\d.]+)$/)                 { $o{spread} = $1 }
        elsif (/^size=([\d.]+)$/)                   { $o{size} = $1 }
        elsif (/^surface$/)                         { $surface{$n} = 1 }
        else                                        { die "bo3_fx.pl: bad option $_ for $n\n" }
    }
    die "bo3_fx.pl: tint=, spread= and size= make a copy: they need as= ($n)\n" if !$o{as} && ( $o{tint} || $o{spread} || $o{size} );
    if   ( $o{as} ) { push @copies, [ $n, "mg/$o{as}", $o{tint}, $o{spread}, $o{size} ] }
    else            { push @roots, $n }
}
close $lh;

# the BO3 textures Greyhound exported: name -> png
my %png;
for my $dir ( grep {-d} map {"$gh/exported_files/$_/ximages"} qw(black_ops_3 black_ops_3_sp) ) {
    opendir my $dh, $dir or die "$dir: $!\n";
    for my $f ( readdir $dh ) { $png{ lc $1 } //= "$dir/$f" if $f =~ /^(.+)\.png$/i }
    closedir $dh;
}

my $s = MgSnap::open_snapshot($snapfile);
my $c = MgFx7->new($s);
remove_tree($raw);
make_path( "$raw/fx", "$raw/materials", "$raw/images" );

sub t6fx { my $n = shift; ( my $b = $n ) =~ s{.*/}{}; "mg/$b" }

# BO3 multiplies an emissive material's colour by its hdrScale (8 for a soft glow, 256 for fire, 2048+ for a white-hot
# core; the "_i<n>" in its name) before tone mapping; T6 has no HDR. HDR_WHITE is the hdrScale taken as plain white: a
# material above it has its elements' colours scaled up by hdrScale / HDR_WHITE (saturating as BO3's tone map does)
# and draws additive, so it glows; one at or below keeps its colours and BO3's alpha blend. A snapshot without the
# material constants gives 1 (no change). Tune HDR_WHITE in game if the remaster's effects look too hot or too dim.
use constant HDR_WHITE => 64;
use List::Util qw(min max);
sub hdr_gain {
    my $p = shift;
    my $m = defined $p ? $c->material($p) : undef;
    my $h = $m && $m->{settings}{hdrScale} ? $m->{settings}{hdrScale}[0] : 0;
    return $h > HDR_WHITE ? $h / HDR_WHITE : 1;
}
sub t6mat { my $n = shift; ( my $b = $n ) =~ s{.*/}{}; $b =~ s/\|.*//; "mg_$b" }

my ( %done, %by_t6, %mats, @todo, $warn );
@todo = ( ( map { [ $_, t6fx($_) ] } @roots ), @copies );
while ( my $job = shift @todo ) {
    my ( $n, $t6, $tint, $spread, $size ) = @$job;
    next if $done{$t6}++;
    my ( $fx, $need, $notes ) = $c->convert($n);
    # a BO3 heat distortion draws with vanilla's own (a copy of its material crashed the game when drawn)
    my %as;
    for my $mn ( keys %{ $need->{materials} } ) {
        my $m = $c->material( $need->{materials}{$mn} );
        $as{$mn} = 'gfx_distortion_heat' if $m && $m->{techset} =~ /distort/;
    }
    die "bo3_fx.pl: $n and $by_t6{$t6} both become $t6\n" if $by_t6{$t6} && $by_t6{$t6} ne $n;
    $by_t6{$t6} = $n;
    print "bo3_fx.pl: $n: $_\n" for @$notes;
    for my $e ( @{ $fx->{elemDefs} } ) {
        # BO3's HDR: a sprite's colour times its material's hdrScale, in LDR as far as a colour goes (see hdr_gain)
        if ( $e->{elemType} <= 6 ) {
            my ($g) = sort { $b <=> $a } map { hdr_gain( $need->{materials}{$_} ) } grep {defined} @{ $e->{visuals} };
            if ( $g && $g > 1 ) {
                for my $v ( map { @$_{qw(base amplitude)} } @{ $e->{visSamples} } ) { $_ = min( 255, $_ * $g ) for @{ $v->{color} }[ 0 .. 2 ] }
            }
        }
        if ($tint) {
            for my $v ( map { @$_{qw(base amplitude)} } @{ $e->{visSamples} } ) {
                my $l = max( @{ $v->{color} }[ 0 .. 2 ] );
                @{ $v->{color} }[ 0 .. 2 ] = map { min( 255, $l * $_ ) } @$tint;
            }
        }
        $e->{$_} = defined $e->{$_} ? t6fx( $e->{$_} ) : undef for qw(effectOnImpact effectOnDeath effectEmitted effectAttached);
        if    ( $e->{elemType} == 12 ) { $_ = t6fx($_) for grep {defined} @{ $e->{visuals} } }
        elsif ( $e->{elemType} == 11 ) { $e->{visuals} = [ map { [ defined $_->[0] ? 'mc/' . t6mat( $_->[0] ) : undef, defined $_->[1] ? 'wc/' . t6mat( $_->[0] ) : undef ] } @{ $e->{visuals} } ] }
        elsif ( $e->{elemType} == 7 )  { $_ = "mg_$_" for grep {defined} @{ $e->{visuals} } }
        elsif ( $e->{elemType} != 8 )  { $_ = $as{$_} // t6mat($_) for grep {defined} @{ $e->{visuals} } }
    }
    if ($spread) {
        for my $e ( @{ $fx->{elemDefs} } ) { $_ *= $spread for @{ $e->{spawnOrigin}[0] }, @{ $e->{spawnOrigin}[1] } }
    }
    if ($size) {
        for my $e ( grep { $_->{elemType} <= 6 } @{ $fx->{elemDefs} } ) {
            for my $v ( map { @$_{qw(base amplitude)} } @{ $e->{visSamples} } ) { $_ *= $size for @{ $v->{size} } }
        }
    }
    if ( $surface{$n} ) {
        for my $e ( grep { ( $_->{flags} & 0xC0 ) == 0 } @{ $fx->{elemDefs} } ) { $e->{flags} |= 0x40 }
    }
    if ( my $k = $scale{$n} ) {
        for my $e ( @{ $fx->{elemDefs} } ) { $_ *= $k->[0] for @{ $e->{spawnOrigin}[0] }; $_ *= $k->[1] for @{ $e->{spawnOrigin}[1] } }
    }
    $fx->{totalSize} = MgFx7::total_size( $t6, $fx );
    spit( "$raw/fx/$t6.json", $json->encode($fx) );
    $mats{$_} //= $need->{materials}{$_} for grep { !$as{$_} } keys %{ $need->{materials} };
    push @todo, map { [ $_, t6fx($_) ] } keys %{ $need->{effects} };
}

# zm_prison's own fires for the forge's press at work, without the glow at their heart (the owner's call): the
# additive light haze (gfx_fxt_smk_light_add_*) and the light (element type 7) go, the flames, sparks and smoke stay
my %glowless = ( 'maps/zombie_alcatraz/fx_alcatraz_fire_sm' => 'mg/fx_mg_forge_fire', 'maps/zombie_alcatraz/fx_alcatraz_falling_fire_impact' => 'mg/fx_mg_forge_flare' );
for my $src ( sort keys %glowless ) {
    my $t6 = $glowless{$src};
    my $fx = decode_json( slurp("$tdump/fx/$src.json") );
    my @kinds = ( ('elemDefCountLooping') x $fx->{elemDefCountLooping}, ('elemDefCountOneShot') x $fx->{elemDefCountOneShot}, ('elemDefCountEmission') x $fx->{elemDefCountEmission} );
    my @keep = grep { my $e = $fx->{elemDefs}[$_]; $e->{elemType} != 7 && !grep { defined && /smk_light_add/ } @{ $e->{visuals} } } 0 .. $#{ $fx->{elemDefs} };
    $fx->{$_} = 0 for qw(elemDefCountLooping elemDefCountOneShot elemDefCountEmission);
    $fx->{ $kinds[$_] }++ for @keep;
    $fx->{elemDefs} = [ @{ $fx->{elemDefs} }[@keep] ];
    $fx->{totalSize} = MgFx7::total_size( $t6, $fx );
    spit( "$raw/fx/$t6.json", $json->encode($fx) );
    $by_t6{$t6} = $src;
}

# materials
my %images;
for my $mn ( sort keys %mats ) {
    my $m = $c->material( $mats{$mn} ) or do { warn "bo3_fx.pl: material $mn not captured\n"; $warn++; next };
    next if $mn =~ m{^vd/};    # a decal's second (model) material: made with the first
    my $t = $m->{techset};
    my $kind = $t =~ /lit_weapon_impact|decal/ ? 'decal' : $t =~ /cloud/ ? 'cloud' : $t =~ /emissive_blend/ ? ( hdr_gain( $mats{$mn} ) > 1 ? 'emissive' : 'emissive_blend' ) : $t =~ /_add\b|additive|emissive/ ? 'emissive' : 'blend';
    my $color = $m->{images}{a0ab1041};
    # a texture whose name the snapshot missed: BO3 names it after its material (gfx_<x>_em -> fxt_<x>, i_<material>, ...)
    if ( !defined $color ) {
        ( my $b = $mn ) =~ s{.*/}{};
        my $bare = $b;
        1 while $bare =~ s/_(?:em|lit|ds\d+|i\d+)$//;
        ( my $fxt = $bare ) =~ s/^gfx_(?:fxt_)?/fxt_/;
        ( my $nogfx = $bare ) =~ s/^gfx_//;
        ($color) = grep { $png{ lc $_ } } $b, "i_$b", $fxt, "i_$fxt", $nogfx, "i_$nogfx";
        print "bo3_fx.pl: $mn: texture unnamed in the snapshot, found as $color\n" if defined $color;
    }
    unless ( defined $color && $png{ lc $color } ) {
        warn "bo3_fx.pl: $mn: its texture " . ( $color // '(unnamed)' ) . " is not in Greyhound's export\n";
        $warn++;
        next;
    }
    # a glowing material's HDR goes into its texture too (its colours alone saturate: BO3's blue flame is (0, 76, 255)
    # times 256, over a texture whose brightest pixels are 146): one copy of the texture per gain
    my $gain = $kind eq 'emissive' ? hdr_gain( $mats{$mn} ) : 1;
    my $img = "mg_" . lc($color) . ( $gain > 1 ? sprintf( '_x%d', $gain ) : '' );
    $images{$img} = [ $png{ lc $color }, undef, $gain ];
    my @out = $kind eq 'decal' ? ( [ "mc/" . t6mat($mn), $tj{decal_mc} ], [ "wc/" . t6mat($mn), $tj{decal_wc} ] ) : ( [ t6mat($mn), $tj{$kind} ] );
    for my $o (@out) {
        my ( $name, $tpl ) = @$o;
        my $j = decode_json( encode_json($tpl) );
        $j->{textureAtlas} = { columns => $m->{cols}, rows => $m->{rows} };
        for my $tex ( @{ $j->{textures} } ) {
            if ( $tex->{name} eq 'colorMap' ) { $tex->{image} = "*$img" }
            elsif ( $tex->{name} eq 'normalMap' ) {
                my $n = $m->{images}{'59d30d0f'};
                if ( defined $n && $png{ lc $n } ) { $tex->{image} = '*mg_' . lc $n; $images{ 'mg_' . lc $n } = [ $png{ lc $n }, 'normal' ] }
                else { $tex->{image} = 'global_normal_flat_16x16' }
            }
            elsif ( $tex->{name} eq 'specularMap' ) { $tex->{image} = '$black' }
        }
        spit( "$raw/materials/$name.json", $json->encode($j) );
    }
}

# images: BC3 (the alpha matters), BC5 normals; a gain scales colour and alpha (an additive sprite adds both), clamped
for my $img ( sort keys %images ) {
    my ( $src, $normal, $gain ) = @{ $images{$img} };
    if ( $gain && $gain > 1 ) {
        my $p = MgPng::read($src);
        $_ = min( 255, int( $_ * $gain + 0.5 ) ) for @{ $p->{px} };
        MgDds::write( "$raw/images/_$img.dds", $p, 'bc3' );
        next;
    }
    system( 'perl', "$FindBin::Bin/png2dds.pl", $src, "$raw/images/_$img.dds", $normal ? 'bc5' : 'bc3' ) == 0 or die "bo3_fx.pl: png2dds failed on $src\n";
}

# the zone: our fx block replaces the previous one
my $zone = "$repo/mod/zone_source/mod.zone";
my $z = slurp($zone);
my $crlf = $z =~ /\r\n/;
$z =~ s/\r\n/\n/g;
my $block = "// fx (tools/bo3_fx.pl)\n" . join( '', map {"fx,$_\n"} sort keys %by_t6 ) . "// end fx\n";
$z =~ s{// fx \(tools/bo3_fx\.pl\)\n.*?// end fx\n}{}s;
$z .= "\n" unless $z =~ /\n$/;
$z .= $block;
$z =~ s/\n/\r\n/g if $crlf;
spit( $zone, $z );
printf "bo3_fx.pl: %d effects, %d materials, %d images%s\n", scalar keys %by_t6, scalar keys %mats, scalar keys %images, $warn ? ", $warn warnings" : '';
