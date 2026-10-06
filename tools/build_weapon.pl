#!/usr/bin/perl
# Builds the Magmagat weapons into mod/weapon (generated from game files, so never committed):
#   magmagat_zm           the real BO4 Magmagat model (tools/build_magmagat_model.pl) on BO2's Blundergat rig, so it
#                         plays the Blundergat's animations; its lava tanks are the Acid Gat's bones, shown
#   magmagat_upgraded_zm  the Magmus Operandi: the same model with the BO4 armour kit
#   mg_magma_blob_zm      the lava blob: the Acid Gat's sticky grenade (blundersplat_explosive_dart_zm) with our blob
#                         model and Harry's trail, lobbed by the script, which bursts it (Harry's explosion) or leaves
#                         it as a lava pool (mg_weapon.gsc)
# Steps: dump zm_prison once (tools/dump_game.pl, into mod/work/dump); the BO4 view models and the near world models
# with their materials (tools/build_magmagat_model.pl); the lava material (tools/gen_lava_mat.pl); the far
# world LODs (1, 2) are BO2's Blundergat recoloured (tools/recolor.pl); the weapon files copy vanilla ones (animations,
# sounds, physics) with our models and the remaster's effects (mod.ff's mg/fx_magmagat_*, tools/bo3_fx.pl, named by
# asset); the display names (english/localizedstrings/mg_weapons.str) and the zone lines.
#
#   perl tools/build_weapon.pl [--redump]
# Env: MG_OAT, MG_BO2 (see tools/dump_game.pl), MG_GREYHOUND (see tools/build_magmagat_model.pl).
use strict;
use warnings;
use FindBin;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);
use JSON::PP;

my $redump = grep { $_ eq '--redump' } @ARGV;
my $repo = "$FindBin::Bin/..";
my $raw = "$repo/mod/weapon";
my $dump = "$repo/mod/work/dump";

sub slurp { my $f = shift; open my $h, '<:raw', $f or die "$f: $!\n"; local $/; my $s = <$h>; close $h; $s }
sub spit { my ( $f, $s ) = @_; ( my $d = $f ) =~ s{/[^/]+$}{}; make_path($d); open my $h, '>:raw', $f or die "$f: $!\n"; print $h $s; close $h }
my $json = JSON::PP->new->pretty->canonical;

# 1. the dump (tools/dump_game.pl, once)
system( 'perl', "$FindBin::Bin/dump_game.pl", $redump ? '--redump' : () ) == 0 or die "build_weapon.pl: the dump failed\n";
remove_tree($raw);

# 2. the BO4 models, their materials and textures; the lava material
system( 'perl', "$FindBin::Bin/build_magmagat_model.pl", $raw, $dump ) == 0 or die "build_weapon.pl: the BO4 model failed\n";
system( 'perl', "$FindBin::Bin/gen_lava_mat.pl", $raw, $dump ) == 0 or die "build_weapon.pl: the lava material failed\n";

# 3. the far world LODs: BO2's Blundergat world model, recoloured. [ source image, our image, recolor.pl options ]
my @recolors = (
    [ '~-gmtl_t6_wpn_zmb_blundergat_col', 'mg_magmagat_col', '--sat', '0.45', '--gain', '0.75', '--tint', '1.25,0.82,0.62' ],
    [ '~-gmtl_t6_wpn_zmb_blundergat_acid_col', 'mg_magmagat_tank_col', '--hue', '120:18', '--sat', '0.9', '--tint', '1.2,0.62,0.42' ],
    [ 'mtl_t6_wpn_zmb_blundergat_acid_ember', 'mg_magmagat_ember', '--hue', '120:20' ],
);
my %image_of;    # vanilla image -> ours ('*' = embedded in mod.ff)
for my $r (@recolors) {
    my ( $src, $ours, @opt ) = @$r;
    make_path("$raw/images");
    system( 'perl', "$FindBin::Bin/recolor.pl", "$dump/images/$src.dds", "$raw/images/_$ours.dds", '--format', 'bc1', @opt ) == 0
        or die "build_weapon.pl: recolour of $src failed\n";
    $image_of{$src} = "*$ours";
}
my %material_of = ( 'mc/mtl_t6_wpn_zmb_blundergat' => 'mc/mtl_mg_magmagat', 'mc/mtl_t6_wpn_zmb_blundergat_acid' => 'mc/mtl_mg_magmagat_tank' );
for my $src ( sort keys %material_of ) {
    my $m = decode_json( slurp("$dump/materials/$src.json") );
    for my $t ( @{ $m->{textures} } ) { $t->{image} = $image_of{ $t->{image} } // $t->{image} }
    spit( "$raw/materials/$material_of{$src}.json", $json->encode($m) );
}
my $world = decode_json( slurp("$dump/xmodel/t6_wpn_zmb_blundergat_world.json") );
for my $k ( 1 .. $#{ $world->{lods} } ) {
    my $g = decode_json( slurp("$dump/$world->{lods}[$k]{file}") );
    $_->{name} = $material_of{ $_->{name} } // $_->{name} for @{ $g->{materials} };
    spit( "$raw/model_export/mg_magmagat_world_lod$k.gltf", encode_json($g) );
}
# the tempered gun far away: BO2's own Blundergat LODs
for my $k ( 1 .. $#{ $world->{lods} } ) { spit( "$raw/model_export/mg_tempered_world_lod$k.gltf", slurp("$dump/$world->{lods}[$k]{file}") ) }

# 4. xmodels: the view models (one LOD, as the Blundergat's), the world models (BO4 near, recoloured BO2 far)
my $view = decode_json( slurp("$dump/xmodel/t6_wpn_zmb_blundergat_view.json") );
for my $ours (qw(mg_magmagat_view mg_magmus_view mg_tempered_view mg_tempered_up_view)) {
    my $x = decode_json( encode_json($view) );
    $x->{lods} = [ { distance => $view->{lods}[0]{distance}, file => "model_export/${ours}_lod0.gltf" } ];
    spit( "$raw/xmodel/$ours.json", $json->encode($x) );
}
for my $ours (qw(mg_magmagat_world mg_magmus_world mg_tempered_world mg_tempered_up_world)) {
    my $x = decode_json( encode_json($world) );
    $x->{lods}[0]{file} = "model_export/${ours}_lod0.gltf";
    my $far = $ours =~ /tempered/ ? 'mg_tempered_world' : 'mg_magmagat_world';
    $x->{lods}[$_]{file} = "model_export/${far}_lod$_.gltf" for 1 .. $#{ $x->{lods} };
    spit( "$raw/xmodel/$ours.json", $json->encode($x) );
}
my @models = qw(mg_magmagat_view mg_magmagat_world mg_magmus_view mg_magmus_world mg_tempered_view mg_tempered_world mg_tempered_up_view
    mg_tempered_up_world);

# 5. weapon files: [ ours, the vanilla one it copies, field overrides ]. hideTags = the Acid Gat's: the plain shells and
#    muzzle go, the lava set (the acid bones) shows. The remaster's Magmagat is the Acid Gat with fire, and ours fires as
#    T6's Acid Gat does: a harmless hitscan shot with no tracer nor impact, the script lobs the blob (magicgrenadetype
#    mg_magma_blob_zm, mg_blob_launch in mg_weapon.gsc). Flashes as the remaster's own t8_magmagat_zm /
#    t8_magmagat_upgraded_zm (read from BO3's weapon pool): Harry's fire-coloured flash on the Magmagat and his _ug one on
#    the Magmus (mod.ff's mg/fx_blundersplat_muzzleflash*). Fire and dry-fire sounds are BO4's own (tools/assets/
#    bo4_sounds.tsv: its layered shot, the Magmus' with BO4's Pack-a-Punch layer over it). The
#    ammo is BO4's (1 / 36 / 30, the Magmus 2 / 30 / 25). The blob is a grenade, so it falls (T6 flies a projectile
#    weapon straight), lobbed by the script (mg_blob_launch), with no damage of its own, hit nor explosion: the
#    script does all of it as BO4's (mg_weapon.gsc) and deletes the blob, which never goes off unless it hit nothing
#    (its 10 s fuse outlasts the 5 s pool).
# BO4's own timings (read from its weapon tunables in memory): both guns fire every 0.4 s and reload in 2.3 s, where
# the Blundergat they copy fires every 0.192 s and reloads in 2.55 s (the first raise is 0.95 s on both)
my %bo4_times = ( fireTime => 0.4, lastFireTime => 0.4, reloadTime => 2.3, reloadEmptyTime => 2.3 );
my $tank_tags = join "\n", qw(j_ammo_ri_bo j_ammo_ri_up j_ammo_le_bo j_ammo_le_up tag_muzzle tag_barrel_le_in tag_barrel_ri_in);
# BO4's own view animations, the Magmagat's and the Magmus' (BO4 plays one set on both, vm_ww_blundergat_*: its
# weapon's anim table, read from memory): Greyhound's Direct XAnim export (BO1 compatibility, the version the Linker
# reads) into black_ops_4_sp/xanims, carried in mod.ff. Each BO4 animation and the T6 fields it fills; the fields left
# out keep the Blundergat's (ADS up and down: BO4's ads_base_* move one bone, a base pose, not a replacement).
my $xa4 = ( $ENV{MG_GREYHOUND} // 'C:/Games/t6/Greyhound-1.49.4.0' ) . '/exported_files/black_ops_4_sp/xanims';
my %vm_fields = ( idle => [qw(idleAnim emptyIdleAnim)], fire => [qw(fireAnim fireIntroAnim lastShotAnim)],
    fire_ads => [qw(adsFireAnim adsFireIntroAnim adsLastShotAnim)], reload => ['reloadAnim'], reload_empty => ['reloadEmptyAnim'],
    pullout => [qw(raiseAnim emptyRaiseAnim altRaiseAnim)], first_raise => ['firstRaiseAnim'],
    putaway => [qw(dropAnim emptyDropAnim altDropAnim)], pullout_quick => ['quickRaiseAnim'], putaway_quick => ['quickDropAnim'],
    sprint_in => [qw(sprintInAnim sprintInEmptyAnim)], sprint_loop => [qw(sprintLoopAnim sprintLoopEmptyAnim)],
    sprint_out => [qw(sprintOutAnim sprintOutEmptyAnim)], crawl_in => [qw(crawlInAnim crawlEmptyInAnim)],
    crawl_out => [qw(crawlOutAnim crawlEmptyOutAnim)], crawl_f => [qw(crawlForwardAnim crawlEmptyForwardAnim)],
    crawl_b => [qw(crawlBackAnim crawlEmptyBackAnim)], crawl_l => [qw(crawlLeftAnim crawlEmptyLeftAnim)],
    crawl_r => [qw(crawlRightAnim crawlEmptyRightAnim)] );
# Their notetracks, as T6's own animations name them: sndnt#<sound alias>, rmbnt#<rumble>; a rumble the game doesn't
# know ends it (COM_ERROR "Could not play rumble asset"). Greyhound writes BO4's names as their hashes (fnv1a-64 of the
# name, low 60 bits): the sounds become ours (tools/assets/bo4_sounds.tsv, BO4's reload foley at its frames;
# 37e24dd167cadfd is fly_blundergat_first_raise), the rumbles are BO2's own reload_medium and reload_small (the
# same names), and BO4's script notes (open_cylinder, bullets_in, loop_end...) go.
my %notes = ( 'sndnt#b0e81208ad9bd0d' => 'sndnt#mg_reload_open', 'sndnt#f66f1b60c187356' => 'sndnt#mg_reload_insert',
    'sndnt#62cefd09884e3ef' => 'sndnt#mg_reload_close', 'sndnt#37e24dd167cadfd' => 'sndnt#mg_raise_cock',
    'rmbnt#a101e863b7f5052' => 'rmbnt#reload_medium', 'rmbnt#cd630b53ad2f9a0' => 'rmbnt#reload_small' );

# A Direct XAnim (version 19) ends with its notetracks: u8 count, then each a C string and a u16 frame. Found from
# the end (the only count whose notes end exactly at the end of the file), rewritten through %notes, sorted by frame.
sub vm_notes {
    my ( $d, $name ) = @_;
    my $len = length $d;
    for ( my $p = $len - 1; $p >= 0 && $p >= $len - 8192; $p-- ) {
        my $n = ord substr( $d, $p, 1 );
        next unless $n;
        my ( $q, @n ) = ( $p + 1 );
        for ( 1 .. $n ) {
            my $e = index( $d, "\0", $q );
            last if $e <= $q || $e - $q > 64 || $e + 3 > $len || substr( $d, $q, $e - $q ) !~ /^[\x20-\x7e]+$/;
            push @n, [ substr( $d, $q, $e - $q ), unpack( 'v', substr( $d, $e + 1, 2 ) ) ];
            $q = $e + 3;
        }
        next unless @n == $n && $q == $len;
        my @kept;
        for (@n) {
            if ( defined $notes{ $_->[0] } ) { push @kept, [ $notes{ $_->[0] }, $_->[1] ] }
            elsif ( $_->[0] =~ /^(sndnt|rmbnt)#/ ) { warn "build_weapon.pl: $name: note $_->[0] unknown, left out\n" }
        }
        @kept = sort { $a->[1] <=> $b->[1] } @kept;
        return substr( $d, 0, $p ) . chr( scalar @kept ) . join( '', map { "$_->[0]\0" . pack( 'v', $_->[1] ) } @kept );
    }
    return $d;    # no notes
}

# T6 fits an animation into its state's time, so the loops take BO4's own lengths (frames / 30: sprint 90, crawl 30;
# the Blundergat's 0.935 s sprint loop ran BO4's 3 s one about 3 times fast), and the empty raise and drop the normal
# ones (BO4 has one animation for both). The times that decide when the gun may fire again keep the Blundergat's.
my %vm_times = ( sprintLoopTime => 3, crawlForwardTime => 1, crawlBackTime => 1, crawlLeftTime => 1, crawlRightTime => 1,
    emptyRaiseTime => 0.7, emptyDropTime => 0.4 );
my ( %bo4_anims, @xanims );
make_path("$raw/xanim");
for my $a ( sort keys %vm_fields ) {
    my $x = "vm_ww_blundergat_$a";
    if ( !-f "$xa4/$x" ) { warn "build_weapon.pl: $x left out, the Blundergat's plays (no $xa4/$x)\n"; next }
    spit( "$raw/xanim/$x", vm_notes( slurp("$xa4/$x"), $x ) );
    push @xanims, $x;
    $bo4_anims{$_} = $x for @{ $vm_fields{$a} };
}
%bo4_anims = ( %bo4_anims, %vm_times ) if @xanims == keys %vm_fields;    # the times go with the whole set
my %blob_only = ( shotCount => 1, damage => 0, minDamage => 0, playerDamage => 0, tracerType => '', impactType => 'none',
    emptyFireSound => 'mg_dryfire_npc', emptyFireSoundPlayer => 'mg_dryfire_plr', %bo4_times, %bo4_anims );
# the blob in flight and stuck: BO4's lava blob (p8_fxp_magma_blob, tools/import_all.pl), as mg_model( "ball" ) in
# mg_coords.gsc. Export it from Greyhound after the Magmagat fired in BO3: before, BO3 has not streamed its mesh in and
# the export is empty
my $blob = 'mg_magma_blob';
# the Acid Gat's dart and grenade hit with impact types (bolt, grenade_explode) that Mob's impact table draws as its
# green acid splash and smoke: ours draw only their own effects (the burst sound is scripted, mg_blob_burst)
my %no_acid = ( impactType => 'none' );
my @weapons = (
    [ 'magmagat_zm', 'blundergat_zm', { displayName => 'ZMWEAPON_MAGMAGAT', gunModel => 'mg_magmagat_view',
        worldModel => 'mg_magmagat_world', hideTags => $tank_tags, %blob_only, fireSound => 'mg_fire_npc', fireSoundPlayer => 'mg_fire_plr',
        viewFlashEffect => 'mg/fx_blundersplat_muzzleflash',
        worldFlashEffect => 'mg/fx_blundersplat_muzzleflash_3p', clipSize => 1, maxAmmo => 36, startAmmo => 30 } ],
    [ 'magmagat_upgraded_zm', 'blundergat_upgraded_zm', { displayName => 'ZMWEAPON_MAGMAGAT_UPGRADED', gunModel => 'mg_magmus_view',
        worldModel => 'mg_magmus_world', attachViewModel6 => '', attachWorldModel6 => '', hideTags => "$tank_tags\ntag_sights",
        %blob_only, fireSound => 'mg_fire_up_npc', fireSoundPlayer => 'mg_fire_up_plr',
        viewFlashEffect => 'mg/fx_blundersplat_muzzleflash_ug', worldFlashEffect => 'mg/fx_blundersplat_muzzleflash_ug_3p',
        clipSize => 2, maxAmmo => 30, startAmmo => 25 } ],
    # the script hides it where it sticks and shows a copy, turned to the surface it stuck to
    [ 'mg_magma_blob_zm', 'blundersplat_explosive_dart_zm', { projectileModel => $blob, projTrailEffect => 'mg/fx_magmagat_trail_bolt',
        damage => 0, projExplosionEffect => '', projExplosionSound => '', %no_acid, fuseTime => 10, explosionRadius => 300,
        explosionInnerDamage => 0, explosionOuterDamage => 0,
        aifuseTime => 10, explosionTag => '' } ],
    # the tempered Blundergat the fireplace hands back (BO4's model, its canisters burning blue): a Blundergat still,
    # with the Blundergat's own muzzle flash, as the remaster's tempered gun fires
    [ 'mg_tempered_zm', 'blundergat_zm', { displayName => 'ZMWEAPON_MG_TEMPERED', gunModel => 'mg_tempered_view', worldModel => 'mg_tempered_world',
        hideTags => $tank_tags } ],
    [ 'mg_tempered_upgraded_zm', 'blundergat_upgraded_zm', { displayName => 'ZMWEAPON_MG_TEMPERED_UPGRADED', gunModel => 'mg_tempered_up_view',
        worldModel => 'mg_tempered_up_world', attachViewModel6 => '', attachWorldModel6 => '', hideTags => "$tank_tags\ntag_sights" } ],
);
for my $w (@weapons) {
    my ( $ours, $src, $set ) = @$w;
    my @kv = split /\\/, slurp("$dump/weapons/$src"), -1;
    my $magic = shift @kv;
    die "build_weapon.pl: $src is not a WEAPONFILE\n" unless $magic eq 'WEAPONFILE';
    my %left = %$set;
    for ( my $i = 0; $i < $#kv; $i += 2 ) {
        next unless exists $left{ $kv[$i] };
        $kv[ $i + 1 ] = delete $left{ $kv[$i] };
    }
    die "build_weapon.pl: $src has no field " . join( ', ', sort keys %left ) . "\n" if %left;
    spit( "$raw/weapons/$ours", join( '\\', $magic, @kv ) );
}

# 6. display names
my %names = ( ZMWEAPON_MAGMAGAT => 'Magmagat', ZMWEAPON_MAGMAGAT_UPGRADED => 'Magmus Operandi', ZMWEAPON_MG_TEMPERED => 'Tempered Blundergat',
    ZMWEAPON_MG_TEMPERED_UPGRADED => 'Tempered Sweeper' );
my $str = qq{VERSION             "1"\nCONFIG              "C:\\\\trees\\\\cod3\\\\cod3\\\\bin\\\\StringEd.cfg"\nFILENOTES           "Magmagat mod"\n};
$str .= qq{\nREFERENCE           $_\nLANG_ENGLISH        "$names{$_}"\n} for sort keys %names;
$str .= "\nENDMARKER\n";
spit( "$raw/english/localizedstrings/mg_weapons.str", $str );

# 7. the zone: our weapon block replaces the previous one
my $zone = "$repo/mod/zone_source/mod.zone";
my $z = slurp($zone);
$z =~ s/\r\n/\n/g;    # a checkout may hand it over with CRLF endings
my @lines = ( 'localize,mg_weapons', ( map { "xmodel,$_" } @models ), ( map { "xanim,$_" } @xanims ), ( map { "weapon,$_->[0]" } @weapons ) );
my $block = "// weapon (tools/build_weapon.pl)\n" . join( "\n", @lines ) . "\n// end weapon\n";
# in place when the block exists (the zone keeps its order), else appended
if ( $z !~ s/\/\/ weapon \(tools\/build_weapon\.pl\).*?\/\/ end weapon\n/$block/s ) { $z =~ s/\s*\z/\n/; $z .= "\n$block" }
spit( $zone, $z );
printf "build_weapon.pl: %d weapons, %d models\n", scalar @weapons, scalar @models;
