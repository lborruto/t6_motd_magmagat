use strict;
use warnings;
use FindBin;
my $dump = $ENV{MG_SND_DUMP} // "snd_dump"; # soundbank dumps (zm_prison/, patch_zm/, common_zm/) and small/ (shrunk files)
use MIME::Base64 qw(encode_base64);

# gen_snd_motd.pl > wizard_snd_motd.html : Magmagat Sound Picker, modelled on Dead Frequency's gen_wizard_snd.pl.
# One quest role at a time (what it is, where it plays today), the curated candidate list under it (extracted from
# the zm_prison / Alcatraz soundbank, downsampled the same way shrink.pl does), pick one, Next.
#
# Local inputs (not in any repo):
my $CSV    = '$FindBin::Bin/../assets/soundbank/zmb_alcatraz.all.aliases.csv';
my @ROOTS  = (
    '$dump/zm_prison',
    '$dump/patch_zm',
    '$dump/common_zm',
);
my $SMALL  = '$dump/small';
mkdir $SMALL unless -d $SMALL;

# ---- shrink.pl logic, inlined (16-bit PCM WAV -> mono, half rate; other formats copied as-is) ----
sub shrink_bytes {
    my ($data) = @_;
    return $data if substr( $data, 0, 4 ) ne 'RIFF';
    my $pos = 12;
    my ( $fmt, $ch, $rate, $bits, $pcm );
    while ( $pos + 8 <= length $data ) {
        my ( $id, $sz ) = unpack 'a4 V', substr( $data, $pos, 8 );
        my $body = substr( $data, $pos + 8, $sz );
        if ( $id eq 'fmt ' ) {
            ( $fmt, $ch, $rate ) = unpack 'v v V', $body;
            $bits = unpack 'v', substr( $body, 14, 2 );
        }
        elsif ( $id eq 'data' ) { $pcm = $body; last }
        $pos += 8 + $sz + ( $sz % 2 );
    }
    return $data if !defined $pcm || $fmt != 1 || $bits != 16;
    my @s = unpack 's<*', $pcm;
    my @mono;
    if ( $ch == 2 ) { for ( my $i = 0; $i + 1 < @s; $i += 2 ) { push @mono, ( $s[$i] + $s[ $i + 1 ] ) / 2 } }
    else { @mono = @s }
    my @half;
    for ( my $i = 0; $i + 1 < @mono; $i += 2 ) { push @half, int( ( $mono[$i] + $mono[ $i + 1 ] ) / 2 ) }
    my $nrate = int( $rate / 2 );
    my $body  = pack 's<*', @half;
    my $fmtc  = pack 'v v V V v v', 1, 1, $nrate, $nrate * 2, 2, 16;
    return 'RIFF' . pack( 'V', 4 + 8 + length($fmtc) + 8 + length($body) ) . 'WAVE' . 'fmt ' . pack( 'V', length $fmtc ) . $fmtc . 'data' . pack( 'V', length $body ) . $body;
}

sub wav_dur {
    my ($data) = @_;
    return undef if substr( $data, 0, 4 ) ne 'RIFF';
    my $pos = 12;
    my ( $rate, $brate, $dsz );
    while ( $pos + 8 <= length $data ) {
        my ( $id, $sz ) = unpack 'a4 V', substr( $data, $pos, 8 );
        if ( $id eq 'fmt ' ) { ( $rate, $brate ) = ( unpack( 'v v V V', substr( $data, $pos + 8, $sz ) ) )[ 2, 3 ] }
        elsif ( $id eq 'data' ) { $dsz = $sz; last }
        $pos += 8 + $sz + ( $sz % 2 );
    }
    return undef unless $brate && defined $dsz;
    return $dsz / $brate;
}

sub flac_dur {
    my ($data) = @_;
    return undef unless substr( $data, 0, 4 ) eq 'fLaC';
    my @b = unpack 'C*', substr( $data, 4 + 4 + 10, 8 );
    my $rate = ( $b[0] << 12 ) | ( $b[1] << 4 ) | ( $b[2] >> 4 );
    my $samples = ( ( $b[3] & 0x0F ) * 2**32 ) + ( ( $b[4] << 24 ) | ( $b[5] << 16 ) | ( $b[6] << 8 ) | $b[7] );
    return undef unless $rate;
    return $samples / $rate;
}

# ---- curated candidates: every "today" alias used by mg_snd_player / mg_snd_near / playsoundtoplayer in the
# mod's mg_*.gsc, plus neighbours in the zm_prison/Alcatraz bank (afterlife, hellbox, wolfhead, powerpanel /
# generator, quest, fire, explosion, soul, perk / cha-ching, electric families).
my @CANDIDATES = qw(
  zmb_afterlife_shockbox_on zmb_afterlife_shockbox_off zmb_afterlife_panel_on zmb_afterlife_trigger_activate
  zmb_afterlife_object_apparate zmb_afterlife_object_disapparate zmb_afterlife_zombie_warp_in zmb_afterlife_zombie_warp_out
  zmb_afterlife_add zmb_afterlife_bleedout zmb_afterlife_death zmb_afterlife_end zmb_afterlife_ghost_loop
  zmb_afterlife_impact zmb_afterlife_loop zmb_afterlife_revived zmb_afterlife_reviving zmb_afterlife_reviving_sparks
  zmb_afterlife_start zmb_afterlife_trigger_electrocute
  zmb_powerpanel_activate zmb_quest_generator_panel_power zmb_quest_generator_panel_spark
  zmb_quest_generator_loop1 zmb_quest_generator_loop2 zmb_quest_generator_loop3 zmb_gondola_generator_loop
  zmb_quest_forcefield_start zmb_quest_forcefield_end zmb_quest_forcefield_loop
  zmb_quest_electricchair_activate zmb_quest_electricchair_spawn
  zmb_quest_elevator_move zmb_quest_final_white_bad zmb_quest_final_white_good zmb_quest_key_unlock
  zmb_quest_nixie_count zmb_quest_nixie_count_final zmb_quest_nixie_fail zmb_quest_nixie_success
  zmb_hellbox_open zmb_hellbox_jingle zmb_hellbox_rise zmb_hellbox_arrive zmb_hellbox_close zmb_hellbox_leave
  zmb_hellbox_lock zmb_hellbox_unlock zmb_hellbox_slam_shake
  zmb_perks_packa_ready zmb_perks_packa_deny zmb_perks_packa_upgrade zmb_perks_power_on zmb_perks_broken_jingle
  zmb_cha_ching zmb_cha_ching_loud zmb_no_cha_ching
  zmb_powerup_grabbed zmb_powerup_grabbed_3p zmb_buildable_complete
  zmb_fire_loop amb_fire_med amb_fire_lrg amb_fire_sml amb_ember_burn
  evt_wolfhead_eat evt_wolfhead_fire_loop evt_wolfhead_spawn_howl evt_wolfhead_bark evt_wolfhead_bite
  evt_wolfhead_growl evt_wolfhead_spawn evt_wolfhead_depart evt_wolfhead_depart_howl evt_wolfhead_twitch_bark
  evt_soulsuck_body
  wpn_blundersplat_explode wpn_blundersplat_fuse wpn_blundergat_fire_plr wpn_blundersplat_explode_layer
  zmb_ai_brutus_gas_explode zmb_cherry_explode zmb_explo zmb_explo_sweet
  zmb_phdflop_explo zmb_phdflop_explo_more zmb_phdflop_explo_sweet
  amb_electrical_fence evt_electrical_surge zmb_electric_chair_2d
);
my %want = map { $_ => 1 } @CANDIDATES;

# ---- CSV: alias -> first row with a resolvable file (Name,FileSource,...,VolMin,VolMax,DistMin,DistMaxDry,...,PanType,...,Looping,...)
open my $ch, '<', $CSV or die "$CSV: $!";
my $head = <$ch>;
chomp $head;
my @cols = split /,/, $head;
my %ix;
$ix{ $cols[$_] } = $_ for 0 .. $#cols;
my %row;
while (<$ch>) {
    chomp;
    my @f = split /,/, $_, -1;
    my $a = $f[ $ix{Name} ];
    next unless $want{$a};
    next if $row{$a};    # first row wins, like board.pl
    my $rel = $f[ $ix{FileSource} ];
    next unless length $rel;
    $rel =~ s{\\}{/}g;
    $rel =~ s{^raw/sound/}{};
    my $found;
    for my $r (@ROOTS) {
        my $cand = "$r/sound/$rel";
        if ( -f $cand ) { $found = $cand; last }
    }
    next unless $found;
    $row{$a} = {
        file  => $found,
        pan   => $f[ $ix{PanType} ],
        dmin  => $f[ $ix{DistMin} ],
        dmax  => $f[ $ix{DistMaxDry} ],
        vmin  => $f[ $ix{VolMin} ],
        vmax  => $f[ $ix{VolMax} ],
        loop  => $f[ $ix{Looping} ],
    };
}
close $ch;

# ---- extract, shrink, embed, measure duration
my @sounds;
for my $a ( sort keys %row ) {
    my $r    = $row{$a};
    my $ext  = $r->{file} =~ /\.flac$/ ? 'flac' : 'wav';
    open my $fh, '<:raw', $r->{file} or next;
    local $/;
    my $data = <$fh>;
    close $fh;
    my $small = $ext eq 'wav' ? shrink_bytes($data) : $data;
    my $dur   = $ext eq 'flac' ? flac_dur($small) : wav_dur($small);
    $dur //= 0;
    my $mime = $ext eq 'flac' ? 'audio/flac' : 'audio/wav';
    open my $o, '>:raw', "$SMALL/$a.$ext" or die;
    print $o $small;
    close $o;
    push @sounds, { a => $a, d => $dur, pan => $r->{pan}, dmin => $r->{dmin}, dmax => $r->{dmax}, vmax => $r->{vmax},
                     loop => $r->{loop}, uri => "data:$mime;base64," . encode_base64( $small, '' ) };
}
@sounds = sort { $a->{d} <=> $b->{d} } @sounds;
printf STDERR "resolved %d / %d candidates\n", scalar(@sounds), scalar(@CANDIDATES);

# ---- page-size budget: base64 inflates ~4/3, keep the embedded audio under ~11 MB raw (~14.7 MB encoded) so the
# whole page stays under 16 MB. Never drop a "today" alias any role points to; drop the largest others first.
my %essential = map { $_ => 1 } qw(
  zmb_powerpanel_activate zmb_powerup_grabbed_3p evt_wolfhead_eat zmb_no_cha_ching zmb_afterlife_panel_on
  zmb_afterlife_trigger_activate zmb_afterlife_shockbox_on zmb_quest_generator_panel_power
  zmb_afterlife_object_apparate zmb_afterlife_object_disapparate zmb_perks_packa_ready wpn_blundersplat_explode
  zmb_fire_loop
);
my $BUDGET = 11_000_000;
my $total  = 0;
$total += length( $_->{uri} ) * 3 / 4 for @sounds;    # approx raw bytes back out of the base64 uri
if ( $total > $BUDGET ) {
    my @droppable = sort { length( $b->{uri} ) <=> length( $a->{uri} ) } grep { !$essential{ $_->{a} } } @sounds;
    for my $d (@droppable) {
        last if $total <= $BUDGET;
        $total -= length( $d->{uri} ) * 3 / 4;
        $d->{drop} = 1;
    }
    @sounds = grep { !$_->{drop} } @sounds;
    @sounds = sort { $a->{d} <=> $b->{d} } @sounds;
    printf STDERR "trimmed to %d candidates to fit the size budget (~%.1f MB raw audio)\n", scalar(@sounds), $total / 1_000_000;
}

# ---- roles: id, title, when it plays, in the quest, today's alias, what fits
my @roles = (
    [ 'hearth_start', 'Hearth start (gun laid in the fire)', 'The moment a Blundergat leaves the player\'s hand and lies in the hearth: state ready -> souls, mg_hearth_start().',
      'Press use at the fireplace holding a Blundergat.', 'zmb_powerpanel_activate', 'a short activation click/hum, under 2 s' ],
    [ 'orb_collect', 'Orb collected', 'A player walks into a floating soul orb and it is added to the count; mg_orb_spawn().',
      'Up to 18 times per fireplace session, one per office kill.', 'zmb_powerup_grabbed_3p', 'a bright pickup chime, under 1 s' ],
    [ 'skull_lit', 'Skull lit (6 / 12 / 18)', 'One of the three mantle skulls turns blue and its glow ignites; mg_skull_light().',
      'At orb counts 6, 12 and 18.', 'evt_wolfhead_eat', 'a satisfying stinger, 1 to 2 s' ],
    [ 'office_empty', 'Office-empty warning', 'Nobody has stood in the Warden\'s Office for 3 s while souls are counting; 2 s left before the gun is lost. mg_hearth_office_watch().',
      'Souls state, whenever the office empties.', 'zmb_no_cha_ching', 'an urgent alarm-like cue, 1 to 2 s' ],
    [ 'souls_deposit', 'Souls deposited / fire turns blue', '18 orbs reached, use pressed again: state souls -> pickup, the flame goes blue. mg_hearth_deposit().',
      'Once per fireplace session.', 'zmb_afterlife_panel_on', 'a rising activation sound, 1 to 3 s' ],
    [ 'gun_taken', 'Tempered gun taken', 'The player takes the risen tempered Blundergat from the fire: state pickup -> run. mg_hearth_take().',
      'Within the 30 s pickup window.', 'zmb_afterlife_trigger_activate', 'a clean pickup/activate cue' ],
    [ 'barrel_refill', 'Barrel refill', 'The carrier stands within 80 units of one of the five blue barrels and the temper timer resets to 25 s. mg_run_loop().',
      'Along the run route, as often as needed.', 'zmb_afterlife_shockbox_on', 'a quick electric/refuel cue, under 1.5 s' ],
    [ 'temper_lost', 'Temper lost', 'The 25 s temper timer hits 0, or the weapon was switched away too long, or the carrier went down. mg_run_fail_do().',
      'Any time during the run.', 'zmb_no_cha_ching', 'a heavy failure cue, 1 to 3 s' ],
    [ 'forge_powered', 'Forge powered', 'First press at the dock generator turns it on. mg_forge_press().',
      'Once, before the forge can be used.', 'zmb_quest_generator_panel_power', 'a generator power-up, 1 to 3 s' ],
    [ 'gun_forge_placed', 'Gun placed in the forge (ghosts start)', 'The tempered Blundergat is set on the generator and the 5 s ghost circle begins. mg_forge_place().',
      'Once per forge run.', 'zmb_afterlife_object_apparate', 'a materialize/apparate cue' ],
    [ 'ghosts_end', 'Ghosts end / Magmagat ready', 'The 5 s ghost circle ends, the gun bursts and becomes ready to take. mg_forge_place().',
      'End of the forge sequence.', 'zmb_afterlife_object_disapparate', 'a dematerialize/release cue' ],
    [ 'magmagat_taken', 'Magmagat taken', 'The player takes the forged weapon off the generator; the personality is granted. mg_forge_take() -> mg_weapon_grant().',
      'Once per weapon forged.', 'zmb_perks_packa_ready', 'a triumphant grant/ready jingle' ],
    [ 'ball_explosion', 'Lava ball explosion', 'A thrown lava ball sticks to a zombie for 0.6 s then explodes, killing everything within 150 units. mg_ball_explode().',
      'Every caught shot of the Magmagat.', 'wpn_blundersplat_explode', 'a punchy explosion, 1 to 2 s' ],
    [ 'patch_loop', 'Magma patch burning loop', 'A missed shot leaves an 8 s burning patch on the ground that damages zombies walking through it. mg_patch().',
      'Every missed shot of the Magmagat.', 'zmb_fire_loop', 'a fire loop' ],
    [ 'acid_refusal', 'Acid Gat refusal', 'The Acid Gat crafting station refuses a Magmagat outright: the forge already claimed the gun. mg_acid_station_validation().',
      'Trying to Pack-a-Punch a Magmagat at the Acid Gat table.', 'zmb_no_cha_ching', 'a firm denial cue' ],
    [ 'debug_zap', 'Debug shock zap', 'Owner-only tool: !mg shock fires the shock pistol at Afterlife shock boxes/panels; only an fx (blue_spark) plays today, no sound is wired. mg_shock_loop().',
      'Debug only, not part of the quest for players.', '', 'a short electric zap, under 1 s (currently silent: pick one to wire in)' ],
);

my %cat = map { $_->{a} => ( $_->{loop} && $_->{loop} =~ /^loop/ ? 'loop' : ( $_->{d} <= 1.6 ? 'short' : 'long' ) ) } @sounds;

sub rows_for {
    my $out = '';
    for my $s (@sounds) {
        my $range = $s->{pan} eq '2d' ? '2D' : "3D $s->{dmin}-$s->{dmax}";
        my $dur   = sprintf( '%.1f s', $s->{d} );
        $out .= qq~<li class="row" data-alias="$s->{a}" data-cat="$cat{$s->{a}}"><button class="play" type="button" data-alias="$s->{a}" aria-label="Play $s->{a}"><span class="tri"></span></button><label class="pickrow"><input type="radio" name="pick-ROLE" value="$s->{a}"><code>$s->{a}</code><span class="dur">$dur</span><span class="chip">$range</span><span class="chip">vol $s->{vmax}</span></label></li>\n~;
    }
    return $out;
}
my $list_rows = rows_for();

my $steps = '';
my $n     = scalar @roles;
for my $i ( 0 .. $#roles ) {
    my ( $id, $title, $when, $ex, $cur, $fits ) = @{ $roles[$i] };
    my $rows = $list_rows;
    $rows =~ s/pick-ROLE/pick-$id/g;
    my $k = $i + 1;
    my $curblock = $cur
      ? qq~<span>Today:</span><button class="play small" type="button" data-alias="$cur" aria-label="Play current"><span class="tri"></span></button><code>$cur</code><button class="keep" type="button">Keep it</button>~
      : qq~<span>Today:</span><code>(none — silent)</code>~;
    $steps .= <<"STEP";
<section class="step" data-id="$id" data-cur="$cur" hidden>
  <div class="card">
    <div class="eyebrow">Sound $k of $n</div>
    <h2>$title</h2>
    <p class="when">$when</p>
    <p class="ex"><b>In the quest:</b> $ex</p>
    <p class="fits"><b>What fits:</b> $fits</p>
    <div class="cur">$curblock</div>
  </div>
  <div class="filters"><input type="search" placeholder="Search a sound (name)" aria-label="Search"><div class="chips"><button type="button" data-cat="" class="on">all</button><button type="button" data-cat="short">short</button><button type="button" data-cat="long">long</button><button type="button" data-cat="loop">loops</button></div></div>
  <ul class="rows">$rows</ul>
</section>
STEP
}

my $json  = join( ',', map { qq~"$_->{a}":"$_->{uri}"~ } @sounds );
my $count = scalar @sounds;

print <<"HTML";
<title>Magmagat Sound Picker</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght\@500;700&family=IBM+Plex+Sans:wght\@400;600&family=IBM+Plex+Mono:wght\@400;500&display=swap">
<style>
:root{--bg:#231710;--panel:#2c1d13;--ink:#f3e6d6;--muted:#b89b7f;--line:#4a3222;--accent:#e8641f;--elec:#3aa6c9;--good:#6fbf6f;--bar:#3a2717;--sel:#4a2a12}
\@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--bg:#faf3ea;--panel:#ffffff;--ink:#241a10;--muted:#6b5a45;--line:#e3d3bd;--accent:#c9530f;--elec:#1f78b8;--good:#3f8f46;--bar:#efe2cd;--sel:#ffe6cf}}
:root[data-theme="light"]{--bg:#faf3ea;--panel:#ffffff;--ink:#241a10;--muted:#6b5a45;--line:#e3d3bd;--accent:#c9530f;--elec:#1f78b8;--good:#3f8f46;--bar:#efe2cd;--sel:#ffe6cf}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:980px;margin:0 auto;padding:22px 20px 90px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:16px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.progress{font:13px "IBM Plex Mono",monospace;color:var(--muted)}
.nav{display:flex;gap:8px}
.nav button,.keep,.copy{background:var(--accent);color:#fff;border:0;padding:9px 16px;font:600 14px "IBM Plex Sans",sans-serif;cursor:pointer}
.nav button.ghost,.keep{background:transparent;color:var(--ink);border:1px solid var(--line)}
.nav button:disabled{opacity:.4;cursor:default}
button:focus-visible,input:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.track{height:4px;background:var(--bar);margin:0 0 20px}.track i{display:block;height:100%;background:var(--accent);transition:width .2s}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:16px 18px;margin-bottom:14px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
.card h2{font:700 30px/1.05 "Barlow Condensed",sans-serif;margin:4px 0 8px;text-wrap:balance}
.card p{margin:0 0 6px;max-width:72ch}.when{color:var(--ink)}.ex,.fits{color:var(--muted);font-size:14px}
.cur{display:flex;align-items:center;gap:10px;margin-top:10px;padding-top:10px;border-top:1px solid var(--line);flex-wrap:wrap}
.cur span{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.cur code{font:500 14px "IBM Plex Mono",monospace}
.filters{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:0 0 8px}
.filters input{flex:1 1 240px;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 10px;font:14px "IBM Plex Sans",sans-serif}
.chips{display:flex;gap:6px}.chips button{background:transparent;color:var(--muted);border:1px solid var(--line);padding:5px 10px;font:12px "IBM Plex Mono",monospace;cursor:pointer}
.chips button.on{color:var(--accent);border-color:var(--accent)}
.rows{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:4px}
.row{display:flex;align-items:center;gap:10px;background:var(--panel);border:1px solid var(--line);padding:6px 10px}
.row.playing{border-color:var(--accent)}.row.picked{background:var(--sel);border-color:var(--accent)}
.pickrow{display:flex;align-items:center;gap:10px;flex:1;cursor:pointer;min-width:0;flex-wrap:wrap}
.pickrow code{font:500 14px "IBM Plex Mono",monospace}
.dur{font:12px "IBM Plex Mono",monospace;font-variant-numeric:tabular-nums;color:var(--ink);min-width:44px}
.chip{font:11px "IBM Plex Mono",monospace;color:var(--muted);border:1px solid var(--line);padding:0 5px;border-radius:3px}
.play{width:36px;height:36px;border-radius:50%;border:1px solid var(--line);background:var(--bg);cursor:pointer;display:grid;place-items:center;flex:none}
.play.small{width:30px;height:30px}
.play .tri{width:0;height:0;border-left:11px solid var(--accent);border-top:7px solid transparent;border-bottom:7px solid transparent;margin-left:2px}
.row.playing .play{background:var(--accent)}.row.playing .play .tri{border-left-color:#fff}
.summary .list{font:13px/1.7 "IBM Plex Mono",monospace;white-space:pre-wrap;background:var(--panel);border:1px solid var(--line);padding:12px}
.summary textarea{width:100%;box-sizing:border-box;min-height:80px;margin:10px 0;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px;font:14px "IBM Plex Sans",sans-serif}
.foot{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:10px 20px;display:flex;justify-content:center;gap:10px;z-index:3}
</style>
<div class="wrap">
<div class="top"><h1>Magmagat Sound Picker</h1><span class="progress" id="prog"></span></div>
<div class="track"><i id="bar" style="width:0%"></i></div>
<p class="when" style="color:var(--muted);margin:0 0 16px;max-width:76ch">One quest moment at a time. Read where it plays, listen to what plays today, press play on the candidates and tick the one you want. Next moves on; Skip leaves a moment unchanged. Your picks are kept in this browser and summed up at the end, with a copy button. The "vol" chip is the alias's own level in the zm_prison / Afterlife bank. $count candidate sounds, all extracted from the zm_prison soundbank.</p>
$steps
<section class="step summary" data-id="summary" hidden>
  <div class="card"><div class="eyebrow">Done</div><h2>Your picks</h2><p class="when">Copy this and paste it back. "keep" means the current sound stays.</p></div>
  <div class="list" id="sumlist"></div>
  <textarea id="notes" placeholder="Notes (too quiet, wrong feel, ideas)"></textarea>
  <button class="copy" type="button" id="copy">Copy picks</button>
</section>
</div>
<div class="foot nav"><button type="button" class="ghost" id="prev">Previous</button><button type="button" class="ghost" id="skip">Skip</button><button type="button" id="next">Next</button></div>
<audio id="player" preload="auto"></audio>
<script type="application/json" id="snd">{$json}</script>
<script>
(function(){
  var SND=JSON.parse(document.getElementById('snd').textContent);
  var steps=Array.prototype.slice.call(document.querySelectorAll('.step')),cur=0,picks={},keep={};
  var player=document.getElementById('player'),playingRow=null,notes=document.getElementById('notes');
  try{var st=JSON.parse(localStorage.getItem('mg_wiz_snd')||'{}');picks=st.picks||{};keep=st.keep||{};cur=st.cur||0;notes.value=st.notes||'';}catch(e){}
  function save(){try{localStorage.setItem('mg_wiz_snd',JSON.stringify({picks:picks,keep:keep,cur:cur,notes:notes.value}))}catch(e){}}
  function stop(){player.pause();player.currentTime=0;if(playingRow){playingRow.classList.remove('playing');playingRow=null}}
  function play(alias,row){if(playingRow===row&&!player.paused){stop();return}stop();if(!SND[alias])return;player.src=SND[alias];player.play();if(row){playingRow=row;row.classList.add('playing')}}
  player.addEventListener('ended',function(){if(playingRow){playingRow.classList.remove('playing');playingRow=null}});
  function summary(){var out=[];steps.forEach(function(s){var id=s.dataset.id;if(id==='summary')return;var t=s.querySelector('h2').textContent;var v=picks[id]?picks[id]:(keep[id]?'keep ('+s.dataset.cur+')':'-- not decided --');out.push(t+' = '+v)});return out.join('\\n')}
  function show(i){stop();cur=Math.max(0,Math.min(steps.length-1,i));steps.forEach(function(s,k){s.hidden=k!==cur});
    document.getElementById('prog').textContent=cur<steps.length-1?('sound '+(cur+1)+' / '+(steps.length-1)):'summary';
    document.getElementById('bar').style.width=Math.round(100*cur/(steps.length-1))+'%';
    document.getElementById('prev').disabled=cur===0;document.getElementById('skip').disabled=cur===steps.length-1;
    document.getElementById('next').textContent=cur===steps.length-2?'Finish':'Next';document.getElementById('next').disabled=cur===steps.length-1;
    if(cur===steps.length-1)document.getElementById('sumlist').textContent=summary();
    window.scrollTo(0,0);save()}
  steps.forEach(function(s){
    var id=s.dataset.id;
    s.querySelectorAll('.play').forEach(function(b){b.addEventListener('click',function(){play(b.dataset.alias,b.closest('.row'))})});
    s.querySelectorAll('input[type=radio]').forEach(function(r){
      if(picks[id]===r.value){r.checked=true;r.closest('.row').classList.add('picked')}
      r.addEventListener('change',function(){picks[id]=r.value;delete keep[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});r.closest('.row').classList.add('picked');save()});
    });
    var k=s.querySelector('.keep');if(k)k.addEventListener('click',function(){keep[id]=1;delete picks[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});s.querySelectorAll('input[type=radio]').forEach(function(r){r.checked=false});save();show(cur+1)});
    var search=s.querySelector('input[type=search]'),chips=s.querySelectorAll('.chips button'),cat='';
    function filter(){var q=(search?search.value:'').toLowerCase();s.querySelectorAll('.row').forEach(function(r){var ok=(!q||r.dataset.alias.indexOf(q)>=0)&&(!cat||r.dataset.cat===cat);r.hidden=!ok})}
    if(search)search.addEventListener('input',filter);
    chips.forEach(function(c){c.addEventListener('click',function(){cat=c.dataset.cat;chips.forEach(function(x){x.classList.toggle('on',x===c)});filter()})});
  });
  document.getElementById('prev').addEventListener('click',function(){show(cur-1)});
  document.getElementById('next').addEventListener('click',function(){show(cur+1)});
  document.getElementById('skip').addEventListener('click',function(){show(cur+1)});
  notes.addEventListener('input',save);
  document.getElementById('copy').addEventListener('click',function(){var t=summary();if(notes.value)t+='\\n\\nNotes: '+notes.value;var b=this;function done(){b.textContent='Copied';setTimeout(function(){b.textContent='Copy picks'},1500)}if(navigator.clipboard){navigator.clipboard.writeText(t).then(done,function(){prompt('Copy this:',t)})}else{prompt('Copy this:',t)}});
  show(cur);
})();
</script>
HTML
