package MgFx7;
# Black Ops III (T7) FxEffectDef -> the T6 effect JSON the mod's Linker loads (fx/<name>.json, see
# docs/PORTING_BO3_ASSETS.md). Read from a Bo3Snapshot of the running game (tools/MgSnap.pm): a compiled BO3 effect
# names its materials only by address.
#
# The T7 layout was worked out against BO2 effects the BO3 remaster ported unchanged (same name, same element count):
# header 144 bytes, elements 608 bytes, velocity samples 96 (T6's), visual samples 80 (T6's 48 plus BO3 extras).
use strict;
use warnings;
use MgSnap;

use constant { ELEM_SIZE => 608, VEL_SIZE => 96, VIS_SIZE => 80, RAD_MSEC => 180 / 3.14159265358979 * 1000 };

# T7 element types -> T6 (FxElemType): 0-9 are T6's, 12 (a light-description light) is drawn as T6's omni light,
# 13 decal, 14 runner; others have no T6 equal
my %TYPE = ( 0 => 0, 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6, 7 => 7, 8 => 8, 9 => 9, 11 => 10, 12 => 8, 13 => 11, 14 => 12 );

sub f2 { my ( $b, $o ) = @_; [ unpack 'f<2', substr( $b, $o, 8 ) ] }
sub i2 { my ( $b, $o ) = @_; [ unpack 'l<2', substr( $b, $o, 8 ) ] }
sub f3 { my ( $b, $o ) = @_; [ unpack 'f<3', substr( $b, $o, 12 ) ] }
sub u8 { my ( $b, $o ) = @_; unpack 'C', substr( $b, $o, 1 ) }
sub s8 { my ( $b, $o ) = @_; unpack 'c', substr( $b, $o, 1 ) }
sub u16 { my ( $b, $o ) = @_; unpack 'v', substr( $b, $o, 2 ) }
sub ptr { my ( $b, $o ) = @_; unpack 'Q<', substr( $b, $o, 8 ) }

# T7 element flags -> T6: bits 0-7 are the same, T7 inserted one at 8 (T6 8-11 are T7 9-12); T6's velocity graph
# (24 local, 25 world), gravity (26) and billboard pivot (21) bits follow the data, as every vanilla T6 element shows
sub elem_flags {
    my ( $f7, $e ) = @_;
    my $f = $f7 & 0xff;
    $f |= ( ( $f7 >> 9 ) & 0xf ) << 8;
    $f |= $f7 & ( ( 1 << 23 ) | ( 1 << 28 ) | ( 1 << 29 ) | ( 1 << 31 ) );
    my $nz = sub { scalar grep { abs($_) > 1e-9 } @_ };
    $f |= 1 << 24 if $nz->( map { ( @{ $_->{local}{velocity}{base} }, @{ $_->{local}{velocity}{amplitude} } ) } @{ $e->{velSamples} } );
    $f |= 1 << 25 if $nz->( map { ( @{ $_->{world}{velocity}{base} }, @{ $_->{world}{velocity}{amplitude} } ) } @{ $e->{velSamples} } );
    $f |= 1 << 26 if $nz->( @{ $e->{gravity} } );
    $f |= 1 << 21 if $nz->( @{ $e->{billboardPivot} } );
    return $f;
}

sub vec3range { my ( $b, $o ) = @_; { base => f3( $b, $o ), amplitude => f3( $b, $o + 12 ) } }

sub vel_sample {
    my $b = shift;
    return {
        local => { velocity => vec3range( $b, 0 ),  totalDelta => vec3range( $b, 24 ) },
        world => { velocity => vec3range( $b, 48 ), totalDelta => vec3range( $b, 72 ) },
    };
}

# T7 stores rotation in radians over the element's life: T6 wants it per msec and per interval
sub vis_state {
    my ( $b, $o, $rot ) = @_;
    my @c = unpack 'C4', substr( $b, $o, 4 );
    my ( $rd, $rt, $s0, $s1, $sc ) = unpack 'f<5', substr( $b, $o + 4, 20 );
    return { color => \@c, rotationDelta => $rd * $rot, rotationTotal => $rt * $rot, size => [ $s0, $s1 ], scale => $sc };
}

# a snapshot + the names of effects already converted: convert(name) -> (json hash, [materials], [models], [effects])
sub new { my ( $class, $snap ) = @_; bless { s => $snap, fxaddr => { map { $_->{addr} => $_->{name} } $snap->assets } }, $class }

sub convert {
    my ( $self, $name ) = @_;
    my $s = $self->{s};
    my $a = $s->asset($name) or die "MgFx7: no effect $name in the snapshot\n";
    my $h = $s->read( $a->{addr}, 144 ) // die "MgFx7: $name header not captured\n";
    my ( $flags, $pri ) = unpack 'v c', substr( $h, 8, 3 );
    my ( $nl, $no, $ne ) = unpack 's s s', substr( $h, 12, 6 );
    my ( $total, $life_l, $life_nl ) = unpack 'l l l', substr( $h, 20, 12 );
    my $elems = ptr( $h, 32 );
    my %need = ( materials => {}, models => {}, effects => {}, lights => {} );
    my $fx = {
        _type => 'fx', _version => 1, _game => 't6',
        # effect flags: T7 moved T6's 0x10 to 0x20
        flags => ( $flags & 0x81 ) | ( ( $flags & 0x20 ) ? 0x10 : 0 ),
        efPriority => $pri,
        elemDefCountLooping => $nl, elemDefCountOneShot => $no, elemDefCountEmission => $ne,
        totalSize => 0,
        msecLoopingLife => $life_l, msecNonLoopingLife => $life_nl,
        boundingBoxDim => f3( $h, 40 ), boundingBoxCentre => f3( $h, 52 ),
        occlusionQueryDepthBias => unpack( 'f<', substr( $h, 64, 4 ) ),
        occlusionQueryFadeIn => unpack( 'l', substr( $h, 68, 4 ) ), occlusionQueryFadeOut => unpack( 'l', substr( $h, 72, 4 ) ),
        occlusionQueryScaleRange => f2( $h, 76 ),
        elemDefs => [],
    };
    my @notes;
    my @kept = ( 0, 0, 0 );    # looping, one-shot, emission elements kept
    for my $i ( 0 .. $nl + $no + $ne - 1 ) {
        my $b = $s->read( $elems + ELEM_SIZE * $i, ELEM_SIZE ) // die "MgFx7: $name element $i not captured\n";
        my $t7 = u8( $b, 200 );
        my $type = $TYPE{$t7};
        # a BO3-only element type goes; so does a sound element (its alias is BO3's, the mod plays its sounds from script)
        if ( !defined $type || $type == 10 ) {
            push @notes, "element $i: BO3 type $t7 " . ( defined $type ? 'is a sound, dropped' : 'has no T6 equal, dropped' );
            next;
        }
        $kept[ $i < $nl ? 0 : $i < $nl + $no ? 1 : 2 ]++;
        my ( $nvel, $nvis ) = ( u8( $b, 202 ), u8( $b, 205 ) );
        my $velp = ptr( $b, 208 );
        my $visp = ptr( $b, 224 );
        my @vel = map { vel_sample( $s->read( $velp + VEL_SIZE * $_, VEL_SIZE ) // die "MgFx7: $name element $i vel $_ not captured\n" ) } 0 .. $nvel;
        my $rot = RAD_MSEC * ( $nvis ? 2 * $nvis / ( $nvis + 1 ) : 1 );
        my @vis = map {
            my $v = $s->read( $visp + VIS_SIZE * $_, VIS_SIZE ) // die "MgFx7: $name element $i vis $_ not captured\n";
            { base => vis_state( $v, 0, $rot ), amplitude => vis_state( $v, 40, $rot ) }
        } 0 .. $nvis;

        # visuals: one inline, several as an array (8-byte pointers), decals as pairs of materials
        my $vc = u8( $b, 201 );
        my $vp = ptr( $b, 240 );
        my @vptrs = $vc <= 1 ? ( $vc ? ($vp) : () ) : map { $s->u64( $vp + 8 * $_ ) } 0 .. $vc - 1;
        my @visuals;
        for my $p (@vptrs) {
            if ( $type == 11 ) {    # decal: {material, material}
                my @q = map { $s->u64( $p + 8 * $_ ) } 0, 1;
                my @m = map { $_ ? $s->name_at($_) : undef } @q;
                $need{materials}{ $m[$_] } = $q[$_] for grep { defined $m[$_] } 0, 1;
                push @visuals, \@m;
            }
            elsif ( $type == 7 ) { my $n = $s->name_at($p); $need{models}{$n} = 1 if defined $n; push @visuals, $n }
            elsif ( $type == 12 ) { my $n = $self->{fxaddr}{$p} // $s->name_at($p); $need{effects}{$n} = 1 if defined $n; push @visuals, $n }
            elsif ( $type == 10 ) { push @visuals, $s->cstr($p) }
            elsif ( $type == 8 ) { }    # omni light: T6 keeps no visual
            elsif ( $type == 9 ) { my $n = $s->name_at($p); $need{lights}{$n} = 1 if defined $n; push @visuals, $n }
            else { my $n = $s->name_at($p); $need{materials}{$n} = $p if defined $n; push @visuals, $n }
        }

        my $ref = sub { my $p = ptr( $b, shift ); return undef unless $p; my $n = $self->{fxaddr}{$p} // $s->name_at($p); $need{effects}{$n} = 1 if defined $n; $n };
        my ( $abeh, $aidx, $afps, $aloop, $acol, $arow, $arange ) = unpack 'C7', substr( $b, 188, 7 );
        my $e = {
            spawn => i2( $b, 8 ),
            spawnRange => f2( $b, 24 ), fadeInRange => f2( $b, 32 ), fadeOutRange => f2( $b, 40 ),
            spawnFrustumCullRadius => unpack( 'f<', substr( $b, 48, 4 ) ),
            spawnDelayMsec => i2( $b, 52 ), lifeSpanMsec => i2( $b, 60 ),
            spawnOrigin => [ f2( $b, 68 ), f2( $b, 76 ), f2( $b, 84 ) ],
            spawnOffsetRadius => f2( $b, 92 ), spawnOffsetHeight => f2( $b, 100 ),
            spawnAngles => [ f2( $b, 112 ), f2( $b, 120 ), f2( $b, 128 ) ],
            angularVelocity => [ f2( $b, 136 ), f2( $b, 144 ), f2( $b, 152 ) ],
            initialRotation => f2( $b, 160 ),
            rotationAxis => unpack( 'V', substr( $b, 168, 4 ) ),
            gravity => f2( $b, 172 ), reflectionFactor => f2( $b, 180 ),
            atlas => {
                behavior => $abeh & 0x7f, index => $aidx, fps => $afps, loopCount => $aloop ? $aloop - 1 : 0,
                colIndexBits => $acol, rowIndexBits => $arow,
                entryCountAndIndexRange => ( ( ( $arange // 1 ) * 2 ) << 8 ) | ( 1 << ( $acol + $arow ) ),
            },
            windInfluence => unpack( 'f<', substr( $b, 196, 4 ) ),
            elemType => $type,
            velSamples => \@vel, visSamples => \@vis, visuals => \@visuals,
            collMins => [ 0, 0, 0 ], collMaxs => [ 0, 0, 0 ],
            effectOnImpact => $ref->(408), effectOnDeath => $ref->(416), effectEmitted => $ref->(424),
            emitDist => f2( $b, 432 ), emitDistVariance => f2( $b, 440 ),
            effectAttached => $ref->(464),
            sortOrder => 5,
            lightingFrac => u8( $b, 497 ),
            alphaFadeTimeMsec => u16( $b, 500 ), maxWindStrength => u16( $b, 502 ),
            spawnIntervalAtMaxWind => u16( $b, 504 ), lifespanAtMaxWind => u16( $b, 506 ),
            spawnSound => undef,    # BO3's aliases are not in T6
            billboardPivot => f2( $b, 552 ),
        };
        $e->{flags} = elem_flags( unpack( 'V', substr( $b, 0, 4 ) ), $e );
        # a view-model effect (effect flag 1): T6 draws its effect-relative, gravity-free elements with the view model (bit 12)
        $e->{flags} |= 1 << 12 if ( $flags & 1 ) && ( $e->{flags} & 0xc0 ) == 0x80 && !( $e->{flags} & ( 1 << 26 ) );
        if ( $type == 6 ) { $e->{cloudDensityRange} = [ 0, 0 ] }
        else              { $e->{billboardTrim} = [ 1, 1 ] }
        if ( $type == 5 ) { $e->{trail} = $self->trail( ptr( $b, 488 ), "$name element $i" ) }
        if ( $type == 9 ) { $e->{spotLight} = { fovInnerFraction => 0.5, startRadius => 1, endRadius => 1 }; push @notes, "element $i: spot light cone guessed" }
        push @{ $fx->{elemDefs} }, $e;
    }
    @$fx{qw(elemDefCountLooping elemDefCountOneShot elemDefCountEmission)} = @kept;
    $fx->{totalSize} = total_size( $name, $fx );
    return ( $fx, \%need, \@notes );
}

# T6's totalSize, as every vanilla zm_prison effect has it: 76 + 292 an element, the samples (96 / 48 bytes), visual
# arrays, trails and the strings
sub total_size {
    my ( $name, $fx ) = @_;
    my $t = 76 + length($name) + 1;
    for my $e ( @{ $fx->{elemDefs} } ) {
        $t += 292 + 96 * @{ $e->{velSamples} } + 48 * @{ $e->{visSamples} };
        $t += 8 * @{ $e->{visuals} } if $e->{elemType} == 11;
        $t += 4 * @{ $e->{visuals} } if $e->{elemType} != 11 && @{ $e->{visuals} } > 1;
        $t += 28 + 20 * @{ $e->{trail}{verts} } + 2 * @{ $e->{trail}{inds} } if $e->{trail};
        $t += 12 if $e->{spotLight};
        $t += length($_) + 1 for grep {defined} map { $e->{$_} } qw(effectOnImpact effectOnDeath effectEmitted effectAttached);
        $t += length($_) + 1 for $e->{elemType} == 12 ? grep {defined} @{ $e->{visuals} } : ();
    }
    return $t;
}

# T7 FxTrailDef (48 bytes): T6's scroll, repeat, split, two BO3 floats, vertCount at 20, verts at 24, indCount at 32,
# inds at 40
sub trail {
    my ( $self, $p, $what ) = @_;
    my $s = $self->{s};
    my $b = $s->read( $p, 48 ) // die "MgFx7: $what trail not captured\n";
    my ( $scroll, $repeat, $split ) = unpack 'l3', substr( $b, 0, 12 );
    my ($vc) = unpack 'l', substr( $b, 20, 4 );
    my $vp = ptr( $b, 24 );
    my ($ic) = unpack 'l', substr( $b, 32, 4 );
    my $ip = ptr( $b, 40 );
    my @verts = map { [ unpack 'f<5', $s->read( $vp + 20 * $_, 20 ) // die "MgFx7: $what trail vertex not captured\n" ] } 0 .. $vc - 1;
    my @inds = $ic ? unpack( 'v*', $s->read( $ip, 2 * $ic ) // die "MgFx7: $what trail indices not captured\n" ) : ();
    return { scrollTimeMsec => $scroll, repeatDist => $repeat, splitDist => $split, verts => \@verts, inds => \@inds };
}


# a BO3 material at an address: { name, techset (no hash suffix), rows, cols, images: semantic hash -> image name }. Layout
# after HydraX (Scobalula): name, 40 bytes of flags (atlas rows at 6, columns at 7), 12 settings, counts (images at
# 624), techset at 632, image table at 640 (32-byte entries: image, semantic hash; the image's name at +0xF8)
sub material {
    my ( $self, $p ) = @_;
    my $s = $self->{s};
    my $m = $s->read( $p, 656 ) // return undef;
    my $tech = $s->name_at( ptr( $m, 632 ) ) // '';
    $tech =~ s/#.*//;
    my ( $rows, $cols ) = unpack 'C2', substr( $m, 14, 2 );
    my $count = u8( $m, 624 );
    my $table = ptr( $m, 640 );
    my %img;
    for my $k ( 0 .. $count - 1 ) {
        my $e = $s->read( $table + 32 * $k, 32 ) // next;
        my ( $ip, $hash ) = unpack 'Q< V', $e;
        my $n = $s->cstr( $s->u64( $ip + 0xF8 ) // 0 );
        $img{ sprintf '%08x', $hash } = $n if defined $n;
    }
    return { name => $s->name_at($p), techset => $tech, rows => $rows || 1, cols => $cols || 1, images => \%img };
}

1;
