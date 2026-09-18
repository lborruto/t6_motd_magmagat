use strict;
use warnings;
use FindBin;

# gen_fx_motd.pl > wizard_fx_motd.html : Magmagat Effect Picker, modelled on Dead Frequency's gen_wizard_fx.pl.
# Effects cannot be rendered in a browser: the page pairs with the in-game `!mg fx <key>` audition tool
# (mg_debug.gsc), which now plays ANY effect the map itself registered: our own 20 mg_fx_table() keys, plus
# every vanilla level._effect key of zm_prison whose asset ships in the fastfile (tools/assets/fx_registered_zm_prison.txt,
# key<TAB>path, built by the owner from the Mob of the Dead + Core loadfx calls). One quest role at a time (= one
# mg_fx_table() key, 1:1 with the roles below); the candidate list under it is every playable key (ours marked
# "today" where used, vanilla shown with its asset path and script family); the primary action per row is
# `!mg fx <key>`, copied with a big button. A secondary "set" command still swaps the role's OWN key to that
# candidate's path for the next map load (mg_fx_init() honours a `mg_fx_<key>` dvar override) for anyone who wants
# to make the swap permanent instead of just looking at it live.
my $ASSETS  = "$FindBin::Bin/../assets/assets_zm_prison.txt";
my $VANILLA = "$FindBin::Bin/../assets/fx_registered_zm_prison.txt";

# ---- mg_fx_table() (mg_systems.gsc), in its declaration order = the old !mg fx <n> order (mg_aud_fx_list()).
my @TABLE = (
    [ 'fire_md',    'maps/zombie_alcatraz/fx_alcatraz_fire_md' ],
    [ 'fire_sm',    'maps/zombie_alcatraz/fx_alcatraz_fire_sm' ],
    [ 'fire_xsm',   'maps/zombie_alcatraz/fx_alcatraz_fire_xsm' ],
    [ 'embers',     'maps/zombie_alcatraz/fx_alcatraz_embers_flat' ],
    [ 'blue_fire',  'maps/zombie_alcatraz/fx_alcatraz_afterlife_zmb_tport' ],
    [ 'soul',       'maps/zombie_alcatraz/fx_alcatraz_soul_charge' ],
    [ 'soul_start', 'maps/zombie_alcatraz/fx_alcatraz_soul_charge_start' ],
    [ 'soul_full',  'maps/zombie_alcatraz/fx_alcatraz_soul_charged' ],
    [ 'soul_hit',   'maps/zombie_alcatraz/fx_alcatraz_soul_charge_impact_sm' ],
    [ 'soul_trail', 'maps/zombie_alcatraz/fx_alcatraz_soul_gib_trail' ],
    [ 'ghost',      'maps/zombie_alcatraz/fx_alcatraz_afterlife_zmb_tport' ],
    [ 'sparks',     'maps/zombie_alcatraz/fx_alcatraz_generator_sparks' ],
    [ 'smoke',      'maps/zombie_alcatraz/fx_alcatraz_generator_smk' ],
    [ 'glow',       'maps/zombie_alcatraz/fx_alcatraz_quest_item_glow' ],
    [ 'glint',      'maps/zombie_alcatraz/fx_alcatraz_key_glint' ],
    [ 'ball',       'maps/zombie_alcatraz/fx_alcatraz_falling_fire' ],
    [ 'ball_hit',   'maps/zombie_alcatraz/fx_alcatraz_falling_fire_impact' ],
    [ 'burn',       'maps/zombie_alcatraz/fx_alcatraz_zmb_fire_torso' ],
    [ 'explo',      'maps/zombie/fx_zmb_tranzit_lava_torso_explo' ],
    [ 'blue_spark', 'electrical/fx_elec_spark_bounce_blue_lg' ],
);
my %idx_of;
$idx_of{ $TABLE[$_][0] } = $_ for 0 .. $#TABLE;
my %path_of = map { $_->[0] => $_->[1] } @TABLE;

# ---- the family of a path: the meaningful folder under maps/ or weapon/, else the first segment.
sub family {
    my ($p) = @_;
    my @seg = split m{/}, $p;
    return $seg[1] if @seg > 1 && ( $seg[0] eq 'maps' || $seg[0] eq 'weapon' );
    return $seg[0];
}

sub kind {
    my ($p) = @_;
    return 'one-shot' if $p =~ /impact|explo|burst|flash|splinter|_fall\b|death|dust|charge$|muzzleflash|waterhit|hit_sm|hit_md|hit_lg|_os$|spawn|arrive|open\b|lock\b|leave\b/;
    return 'loop';
}

# ---- the full playable candidate list: our 20 keys, then every vanilla key that has an asset (drop anything
# without a playable key, per the brief: candidates ARE keys now, not raw asset paths).
my @candidates;
push @candidates, { key => $_->[0], path => $_->[1], src => 'ours' } for @TABLE;
{
    open my $v, '<', $VANILLA or die "$VANILLA: $!";
    while (<$v>) {
        chomp;
        next if /^#/;
        next unless length;
        my ( $key, $path ) = split /\t/;
        next unless $key && $path;
        push @candidates, { key => $key, path => $path, src => 'vanilla' };
    }
    close $v;
}
my $total_candidates = scalar @candidates;

my $list_rows = '';
for my $c (@candidates) {
    my $k     = kind( $c->{path} );
    my $fam   = family( $c->{path} );
    my $badge = $c->{src} eq 'ours' ? qq~<span class="chip chip-ours">ours</span>~ : qq~<span class="chip chip-vanilla">$fam</span>~;
    $list_rows .= qq~<li class="row" data-key="$c->{key}" data-kind="$k" data-src="$c->{src}"><label class="pickrow"><input type="radio" name="pick-ROLE" value="$c->{key}"><code>$c->{key}</code>$badge<span class="chip chip-$k">$k</span><span class="path">$c->{path}</span></label><button class="cmd primary" type="button" data-cmd="!mg fx $c->{key}">!mg fx $c->{key}</button><button class="cmd set" type="button" data-cmd='set mg_fx_ROLEKEY &quot;$c->{path}&quot;'>set ROLEKEY</button></li>\n~;
}

# roles: id, title, where it plays, fx_table key (= today value), what fits
my @roles = (
    [ 'hearth_fire', 'Hearth fire (normal)', 'The fireplace flame outside the souls / pickup states: small when locked/ready/run/forge/done, medium while souls are being collected. mg_hearth_fire().',
      'fire_sm', 'a warm, grounded flame; fire_md is the bigger stage used during the souls count' ],
    [ 'hearth_fire_blue', 'Hearth fire (blue, tempered)', 'The fireplace once the tempered gun is ready to take (pickup state). mg_hearth_fire().',
      'blue_fire', 'a cold blue flame, distinct from the warm hearth fire' ],
    [ 'skull_glow', 'Skull lit glow', 'The glow that ignites on a mantle skull at 6, 12 and 18 souls and stays until reset. mg_skull_light().',
      'soul_full', 'a steady charged glow, readable from across the room' ],
    [ 'orb', 'Orb', 'The floating soul orb that rises from an office kill and drifts, waiting to be collected. mg_orb_spawn().',
      'soul', 'a small, followable floating light' ],
    [ 'orb_impact', 'Orb collected impact', 'The burst on the player the instant an orb is collected. mg_orb_spawn().',
      'soul_hit', 'a quick bright pop' ],
    [ 'soul_trail', 'Soul trail to the hearth', 'The moving trail from the collected orb back to the fireplace. mg_trail(), called from mg_orb_spawn().',
      'soul_trail', 'a directional streak that reads while moving fast' ],
    [ 'barrel_flame', 'Barrel blue flame', 'The flame on top of all five route barrels while the temper is live. mg_barrels_set().',
      'blue_fire', 'the same blue flame as the tempered hearth (shared key)' ],
    [ 'gun_flame', 'Flame on the carried gun', 'The small flame linked to the carrier\'s weapon hand for the whole temper run. mg_run_loop().',
      'fire_xsm', 'a compact flame that will not swallow the weapon model' ],
    [ 'forge_sparks', 'Forge sparks', 'The one-shot when the generator is first powered. mg_forge_press().',
      'sparks', 'a bright electrical burst, 1 to 2 s' ],
    [ 'ghosts', 'Ghosts', 'Two ghost effects that circle the gun on the generator for 5 s while it converts. mg_forge_place().',
      'ghost', 'an ethereal loop that reads while orbiting' ],
    [ 'forge_smoke', 'Forge smoke', 'A smoke column at the generator for the same 5 s the ghosts circle. mg_forge_place().',
      'smoke', 'a rising smoke loop' ],
    [ 'magmagat_glow', 'Magmagat ready glow', 'The glow left on the generator once the Magmagat is ready to take. mg_forge_place(), mg_forge_take().',
      'glow', 'a steady inviting glow' ],
    [ 'ball_trail', 'Lava ball trail', 'The trail on every lava ball in flight, from muzzle to target. mg_lava_ball().',
      'ball', 'a hot, fast-moving trail' ],
    [ 'ball_impact', 'Ball impact', 'The burst where a missed lava ball lands, and where a caught one explodes. mg_lava_ball(), mg_ball_explode().',
      'ball_hit', 'a molten splash, 1 to 2 s' ],
    [ 'zombie_burn', 'Zombie burning', 'Linked to a zombie caught by a lava ball explosion or standing in a magma patch. mg_ball_explode(), mg_burn_fx(), mg_brutus_burn() (Brutus only, never lethal).',
      'burn', 'a body-scale fire loop that reads while moving with the zombie' ],
    [ 'explosion', 'Explosion', 'The lava ball\'s kill burst (150-unit radius) and the burst when the forge conversion completes. mg_ball_explode(), mg_forge_place().',
      'explo', 'a solid explosion, 1 to 2 s' ],
    [ 'patch_fire', 'Magma patch fire', 'The 8 s burning patch left by a missed shot. mg_patch().',
      'fire_md', 'the same fire used by the hearth\'s souls stage (shared key)' ],
    [ 'patch_embers', 'Patch embers', 'Ember dressing on top of the magma patch fire, alongside patch_fire, for its whole 8 s. mg_patch().',
      'embers', 'a flat ember bed, no big silhouette' ],
    [ 'shock_zap', 'Shock zap spark', 'Owner debug tool: the zap sent to an Afterlife shock box/panel by the shock pistol. mg_shock_loop().',
      'blue_spark', 'a short electric spark at the hit point' ],
    [ 'anchor_glint', 'Anchor preview glint', 'The marker on a coordinate preview spawned by `!mg show` while placing anchors. mg_preview_show() / mg_place.gsc.',
      'glint', 'the same small key glint used across the mod (shared key)' ],
);

my $steps  = '';
my $nroles = scalar @roles;
for my $i ( 0 .. $#roles ) {
    my ( $id, $title, $where, $key, $needs ) = @{ $roles[$i] };
    my $k      = $i + 1;
    my $cur    = $path_of{$key} // '(unregistered key)';
    my $curcmd = "!mg fx $key";
    my $rows   = $list_rows;
    $rows =~ s/pick-ROLE/pick-$id/g;
    $rows =~ s/ROLEKEY/$key/g;
    # mark this role's own key "today" in the candidate list (adds a CSS class, data-src stays "ours" for the JS filter)
    $rows =~ s{<li class="row" data-key="\Q$key\E" data-kind="([a-z-]+)" data-src="ours">}{<li class="row today" data-key="$key" data-kind="$1" data-src="ours">};
    $steps .= <<"STEP";
<section class="step" data-id="$id" data-cur="$cur" hidden>
  <div class="card">
    <div class="eyebrow">Effect $k of $nroles</div>
    <h2>$title</h2>
    <p class="when">$where</p>
    <p class="fits"><b>What fits:</b> $needs</p>
    <div class="cur"><span>Today (key <code>$key</code>):</span><code>$cur</code><button class="cmd primary" type="button" data-cmd="$curcmd">$curcmd</button><button class="keep" type="button">Keep it</button></div>
  </div>
  <div class="filters"><input type="search" placeholder="Search a key, path or family (fire, spark, glow, brutus, magicbox...)" aria-label="Search"><div class="chips"><button type="button" data-kind="" class="on">all</button><button type="button" data-kind="one-shot">one-shot</button><button type="button" data-kind="loop">loop</button></div><div class="chips"><button type="button" data-src="" class="on">all</button><button type="button" data-src="ours">ours (20)</button><button type="button" data-src="vanilla">vanilla (@{[ $total_candidates - 20 ]})</button></div></div>
  <ul class="rows">$rows</ul>
</section>
STEP
}

my $count_ours    = 20;
my $count_vanilla = $total_candidates - 20;
print <<"HTML";
<title>Magmagat Effect Picker</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght\@500;700&family=IBM+Plex+Sans:wght\@400;600&family=IBM+Plex+Mono:wght\@400;500&display=swap">
<style>
:root{--bg:#231710;--panel:#2c1d13;--ink:#f3e6d6;--muted:#b89b7f;--line:#4a3222;--accent:#e8641f;--elec:#3aa6c9;--good:#6fbf6f;--bar:#3a2717;--sel:#4a2a12}
\@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--bg:#faf3ea;--panel:#ffffff;--ink:#241a10;--muted:#6b5a45;--line:#e3d3bd;--accent:#c9530f;--elec:#1f78b8;--good:#3f8f46;--bar:#efe2cd;--sel:#ffe6cf}}
:root[data-theme="light"]{--bg:#faf3ea;--panel:#ffffff;--ink:#241a10;--muted:#6b5a45;--line:#e3d3bd;--accent:#c9530f;--elec:#1f78b8;--good:#3f8f46;--bar:#efe2cd;--sel:#ffe6cf}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:1080px;margin:0 auto;padding:22px 20px 90px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:10px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.progress{font:13px "IBM Plex Mono",monospace;color:var(--muted)}
.track{height:4px;background:var(--bar);margin:0 0 16px}.track i{display:block;height:100%;background:var(--accent);transition:width .2s}
.banner{background:var(--sel);border:1px solid var(--accent);color:var(--ink);padding:10px 14px;margin:0 0 14px;font-size:14px;max-width:80ch}
.banner code{font:500 13px "IBM Plex Mono",monospace}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:16px 18px;margin-bottom:12px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
.card h2{font:700 30px/1.05 "Barlow Condensed",sans-serif;margin:4px 0 8px;text-wrap:balance}
.card p{margin:0 0 6px;max-width:72ch}.fits{color:var(--muted);font-size:14px}
.cur{display:flex;align-items:center;gap:10px;margin-top:10px;padding-top:10px;border-top:1px solid var(--line);flex-wrap:wrap}
.cur span{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
code{font:500 14px "IBM Plex Mono",monospace}
button{font:600 13px "IBM Plex Sans",sans-serif;cursor:pointer}
.nav button,.copy{background:var(--accent);color:#fff;border:0;padding:9px 16px;font-size:14px}
.nav button.ghost,.keep{background:transparent;color:var(--ink);border:1px solid var(--line);padding:7px 12px}
.nav button:disabled{opacity:.4;cursor:default}
.cmd{background:var(--bg);color:var(--elec);border:1px solid var(--line);padding:4px 8px;font:500 12px "IBM Plex Mono",monospace;white-space:nowrap}
.cmd.primary{background:var(--accent);color:#fff;border-color:var(--accent);font:700 13px "IBM Plex Mono",monospace;padding:6px 10px}
.cmd.set{opacity:.75;font-size:11px}
button:focus-visible,input:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.filters{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:0 0 8px}
.filters input{flex:1 1 240px;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 10px;font:14px "IBM Plex Sans",sans-serif}
.chips{display:flex;gap:6px}.chips button{background:transparent;color:var(--muted);border:1px solid var(--line);padding:5px 10px;font:12px "IBM Plex Mono",monospace}
.chips button.on{color:var(--accent);border-color:var(--accent)}
.rows{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:4px}
.row{display:flex;align-items:center;gap:10px;background:var(--panel);border:1px solid var(--line);padding:6px 10px;flex-wrap:wrap}
.row.picked{background:var(--sel);border-color:var(--accent)}
.pickrow{display:flex;align-items:center;gap:10px;flex:1;cursor:pointer;min-width:0;flex-wrap:wrap}
.chip{font:11px "IBM Plex Mono",monospace;border:1px solid var(--line);padding:0 5px;border-radius:3px;color:var(--muted)}
.chip-one-shot{color:var(--accent);border-color:var(--accent)}.chip-loop{color:var(--elec);border-color:var(--elec)}
.chip-ours{color:var(--good);border-color:var(--good)}.chip-vanilla{color:var(--muted)}
li.row label input[type=radio]:checked + code{color:var(--accent)}
.row.today{outline:2px solid var(--good);outline-offset:-2px}
.row.today .chip-ours::after{content:" - today"}
.path{font:11px "IBM Plex Mono",monospace;color:var(--muted);flex-basis:100%;order:9}
.summary .list{font:13px/1.7 "IBM Plex Mono",monospace;white-space:pre-wrap;background:var(--panel);border:1px solid var(--line);padding:12px}
.summary textarea{width:100%;box-sizing:border-box;min-height:80px;margin:10px 0;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px;font:14px "IBM Plex Sans",sans-serif}
.foot{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:10px 20px;display:flex;justify-content:center;gap:10px;z-index:3}
.toast{position:fixed;bottom:64px;left:50%;transform:translateX(-50%);background:var(--ink);color:var(--bg);padding:6px 12px;font:13px "IBM Plex Mono",monospace;opacity:0;transition:opacity .2s;pointer-events:none}
.toast.on{opacity:1}
</style>
<div class="wrap">
<div class="top"><h1>Magmagat Effect Picker</h1><span class="progress" id="prog"></span></div>
<div class="track"><i id="bar" style="width:0%"></i></div>
<p class="banner"><b>Preview happens in game:</b> type the command in chat (needs <code>set mg_debug 1</code>), the effect plays 8 s where you aim.</p>
<p style="color:var(--muted);margin:0 0 14px;max-width:80ch">One quest role at a time (= one of this mod's 20 mg_fx_table() keys, mg_systems.gsc). Every candidate below is a KEY that is actually playable today: this mod's own $count_ours keys, plus every vanilla zm_prison effect the map already registers ($count_vanilla keys, tools/assets/fx_registered_zm_prison.txt). The big button on each row copies its <code>!mg fx &lt;key&gt;</code> command; the small "set" button copies a console line that permanently swaps the ROLE's own key to that candidate's asset path for the NEXT map load (mg_fx_init() reads a <code>mg_fx_&lt;key&gt;</code> override dvar). Tick the one you want, Next. <b>one-shot</b> = plays once; <b>loop</b> = stays on. The type is guessed from the name.</p>
$steps
<section class="step summary" data-id="summary" hidden>
  <div class="card"><div class="eyebrow">Done</div><h2>Your picks</h2><p>Copy this and paste it back. "keep" means the current effect stays.</p></div>
  <div class="list" id="sumlist"></div>
  <textarea id="notes" placeholder="Notes (too big, too small, wrong colour, wrong height...)"></textarea>
  <button class="copy" type="button" id="copy">Copy picks</button>
</section>
</div>
<div class="foot nav"><button type="button" class="ghost" id="prev">Previous</button><button type="button" class="ghost" id="skip">Skip</button><button type="button" id="next">Next</button></div>
<div class="toast" id="toast">copied</div>
<script>
(function(){
  var steps=Array.prototype.slice.call(document.querySelectorAll('.step')),cur=0,picks={},keep={},notes=document.getElementById('notes');
  try{var st=JSON.parse(localStorage.getItem('mg_wiz_fx')||'{}');picks=st.picks||{};keep=st.keep||{};cur=st.cur||0;notes.value=st.notes||'';}catch(e){}
  function save(){try{localStorage.setItem('mg_wiz_fx',JSON.stringify({picks:picks,keep:keep,cur:cur,notes:notes.value}))}catch(e){}}
  function toast(t){var el=document.getElementById('toast');el.textContent=t;el.classList.add('on');setTimeout(function(){el.classList.remove('on')},1200)}
  function copyText(t){if(navigator.clipboard){navigator.clipboard.writeText(t).then(function(){toast('copied: '+t)},function(){prompt('Copy this:',t)})}else{prompt('Copy this:',t)}}
  function summary(){var out=[];steps.forEach(function(s){var id=s.dataset.id;if(id==='summary')return;var t=s.querySelector('h2').textContent;var v=picks[id]?picks[id]:(keep[id]?'keep ('+s.dataset.cur+')':'-- not decided --');out.push(t+' = '+v)});return out.join('\\n')}
  function show(i){cur=Math.max(0,Math.min(steps.length-1,i));steps.forEach(function(s,k){s.hidden=k!==cur});
    document.getElementById('prog').textContent=cur<steps.length-1?('effect '+(cur+1)+' / '+(steps.length-1)):'summary';
    document.getElementById('bar').style.width=Math.round(100*cur/(steps.length-1))+'%';
    document.getElementById('prev').disabled=cur===0;document.getElementById('skip').disabled=cur===steps.length-1;
    document.getElementById('next').textContent=cur===steps.length-2?'Finish':'Next';document.getElementById('next').disabled=cur===steps.length-1;
    if(cur===steps.length-1)document.getElementById('sumlist').textContent=summary();
    window.scrollTo(0,0);save()}
  steps.forEach(function(s){var id=s.dataset.id;
    s.querySelectorAll('input[type=radio]').forEach(function(r){
      if(picks[id]===r.value){r.checked=true;r.closest('.row').classList.add('picked')}
      r.addEventListener('change',function(){picks[id]=r.value;delete keep[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});r.closest('.row').classList.add('picked');save()});
    });
    var k=s.querySelector('.keep');if(k)k.addEventListener('click',function(){keep[id]=1;delete picks[id];s.querySelectorAll('.row').forEach(function(x){x.classList.remove('picked')});s.querySelectorAll('input[type=radio]').forEach(function(r){r.checked=false});save();show(cur+1)});
    var search=s.querySelector('input[type=search]'),kindChips=s.querySelectorAll('.chips:nth-of-type(1) button'),srcChips=s.querySelectorAll('.chips:nth-of-type(2) button'),kind='',src='';
    function filter(){var q=(search?search.value:'').toLowerCase();s.querySelectorAll('.row').forEach(function(r){var hay=r.dataset.key+' '+(r.querySelector('.path')||{}).textContent;var ok=(!q||hay.toLowerCase().indexOf(q)>=0)&&(!kind||r.dataset.kind===kind)&&(!src||r.dataset.src===src);r.hidden=!ok})}
    if(search)search.addEventListener('input',filter);
    kindChips.forEach(function(c){c.addEventListener('click',function(){kind=c.dataset.kind;kindChips.forEach(function(x){x.classList.toggle('on',x===c)});filter()})});
    srcChips.forEach(function(c){c.addEventListener('click',function(){src=c.dataset.src;srcChips.forEach(function(x){x.classList.toggle('on',x===c)});filter()})});
  });
  document.querySelectorAll('.cmd').forEach(function(b){b.addEventListener('click',function(){copyText(b.dataset.cmd)})});
  document.getElementById('prev').addEventListener('click',function(){show(cur-1)});
  document.getElementById('next').addEventListener('click',function(){show(cur+1)});
  document.getElementById('skip').addEventListener('click',function(){show(cur+1)});
  notes.addEventListener('input',save);
  document.getElementById('copy').addEventListener('click',function(){var t=summary();if(notes.value)t+='\\n\\nNotes: '+notes.value;copyText(t)});
  show(cur);
})();
</script>
HTML
