use strict;
use warnings;
use FindBin;

# gen_mdl_motd.pl > wizard_mdl_motd.html : Magmagat Prop Picker, modelled on Dead Frequency's gen_wizard_mdl.pl.
# Reads the OpenAssetTools glTF dump of zm_prison (made with:
#   Unlinker.exe --model-format GLTF --include-assets xmodel
#     --search-path "<game>/zone/all;<game>/zone/english"
#     --output-folder "C:/Games/t6/model_dump/?zone?" "<game>/zone/all/zm_prison.ff"
# ), the asset list of the mod (tools/assets/assets_zm_prison.txt), computes each model's bounding box straight
# from its glTF accessors (min/max), and builds one prop role at a time with a three.js viewer, same as the
# TranZit picker.
my $DUMP   = 'C:/Games/t6/model_dump/zm_prison';
my $ASSETS = '$FindBin::Bin/../assets/assets_zm_prison.txt';

# ---- candidate xmodel names used by the map: p6_zm_al_* (this map's own props) plus generic p6_/p_/zombie_
# props, excluding characters/weapons/vehicles/fx/tags the same way gen_wizard_mdl.pl does.
my @names;
open my $af, '<', $ASSETS or die "$ASSETS: $!";
while (<$af>) {
    chomp;
    next unless /^xmodel,\s*(\S+)/;
    my $name = $1;
    next if $name =~ /^(c_|t6_|veh_|fx_|weapon_|tag_|skybox|world|projectile|fxanim|defaultvehicle)/;
    next unless $name =~ /^(p6_zm_al_|p6_|p_|zombie_)/;
    push @names, $name;
}
close $af;
my %seen;
@names = grep { !$seen{$_}++ } @names;

# xmodel name -> lod0 glTF path (from its xmodel/<name>.json "lods"[0]."file")
sub lod0_file {
    my ($name) = @_;
    my $j = "$DUMP/xmodel/$name.json";
    return undef unless -f $j;
    open my $fh, '<', $j or return undef;
    local $/;
    my $txt = <$fh>;
    close $fh;
    return $1 if $txt =~ /"file"\s*:\s*"(model_export\/[^"]+)"/;
    return undef;
}

# Overall bounding box: union of every POSITION accessor's min/max in the file (covers multi-primitive models).
# glTF axes here are COD's (Z up); width = X extent, depth = Y extent, height = Z extent.
sub gltf_bounds {
    my ($json) = @_;
    my ( @minx, @miny, @minz, @maxx, @maxy, @maxz );
    while ( $json =~ /"min"\s*:\s*\[\s*([\-0-9.eE]+)\s*,\s*([\-0-9.eE]+)\s*,\s*([\-0-9.eE]+)\s*\]/g ) {
        push @minx, $1;
        push @miny, $2;
        push @minz, $3;
    }
    while ( $json =~ /"max"\s*:\s*\[\s*([\-0-9.eE]+)\s*,\s*([\-0-9.eE]+)\s*,\s*([\-0-9.eE]+)\s*\]/g ) {
        push @maxx, $1;
        push @maxy, $2;
        push @maxz, $3;
    }
    return ( 0, 0, 0 ) unless @minx && @maxx;
    my ( $a, $b ) = sub_minmax( \@minx, \@maxx );
    my ( $c, $d ) = sub_minmax( \@miny, \@maxy );
    my ( $e, $f ) = sub_minmax( \@minz, \@maxz );
    return ( $b - $a, $f - $e, $d - $c );    # width(x), height(z), depth(y)
}

sub sub_minmax {
    my ( $mins, $maxs ) = @_;
    my $lo = $mins->[0];
    $lo = $_ < $lo ? $_ : $lo for @$mins;
    my $hi = $maxs->[0];
    $hi = $_ > $hi ? $_ : $hi for @$maxs;
    return ( $lo, $hi );
}

# Loads + measures one model. Returns undef if missing or (unless $force) over the 420 KB embed budget.
my %cache;
sub load_model {
    my ( $name, $force ) = @_;
    return $cache{$name} if exists $cache{$name};
    my $rel = lod0_file($name);
    return $cache{$name} = undef unless $rel;
    my $path = "$DUMP/$rel";
    return $cache{$name} = undef unless -f $path;
    my $size = -s $path;
    return $cache{$name} = undef if !$force && $size > 420_000;
    open my $fh, '<:raw', $path or return $cache{$name} = undef;
    local $/;
    my $json = <$fh>;
    close $fh;
    $json =~ s{</script}{<\\/script}gi;
    my ( $w, $h, $d ) = gltf_bounds($json);
    return $cache{$name} = { name => $name, json => $json, w => sprintf( '%.0f', $w ), h => sprintf( '%.0f', $h ), d => sprintf( '%.0f', $d ), size => $size };
}

my @models;
for my $name (@names) {
    my $m = load_model( $name, 0 );
    push @models, $m if $m;
}
@models = sort { $a->{name} cmp $b->{name} } @models;
printf STDERR "%d / %d candidate models embedded (glTF <= 420 KB)\n", scalar(@models), scalar(@names);

# Roles: id, title, when/where, today's model kind, fixed (1 = view only, no search/pick)
my @roles = (
    [ 'skull', 'The three mantle skulls', 'Stand on the fireplace mantle (MG_SKULL_1/2/3); each turns blue and glows as souls reach 6, 12 and 18. mg_hearth_init(), mg_skull_light().',
      'p6_zm_al_skull', 0 ],
    [ 'barrel', 'The five route barrels', 'Placed along the temper run (office exit, spiral stairs, Citadel tunnel, Generator Room door, dock); flare blue while the temper is live and refill it up close. mg_run_init(), mg_barrels_set().',
      'p6_zm_al_wood_barrel_01', 0 ],
    [ 'beacon', 'The use-point marker', 'Stand-in prop at MG_HEARTH_USE (and any other point anchor): marks where to press use. No dedicated prop exists yet in the map set, so a candle stands in. mg_models_init().',
      'p6_zm_al_candle_tall_on', 0 ],
    [ 'gun_rest', 'The gun rest (fixed)', 'The Blundergat laid in the hearth (MG_HEARTH) and on the forge (MG_FORGE_GUN) uses the actual weapon world model, not a stand-in prop: it is not meant to be replaced. View only.',
      't6_wpn_zmb_blundergat_world', 1 ],
    [ 'ball', 'The lava ball', 'The projectile spawned by every Magmagat shot (mg_lava_ball()); currently the plain Blundergat splat round, reused as a placeholder.',
      't6_wpn_zmb_projectile_blundergat', 1 ],
);

# Make sure every role's "today" model is embedded even if it would be excluded from the general candidate list
# (t6_wpn_* is filtered out of the searchable catalogue on purpose) or is over the size budget.
my %extra;
for my $r (@roles) {
    my $cur = $r->[3];
    next if $cache{$cur};
    my $m = load_model( $cur, 1 );
    $extra{$cur} = $m if $m;
}
my @extra_models = values %extra;

my $list = '';
for my $m (@models) {
    $list .= qq~<li class="mrow" data-name="$m->{name}"><code>$m->{name}</code><span class="dims">$m->{w} x $m->{h} x $m->{d}</span></li>\n~;
}

my $steps = '';
my $n     = scalar @roles;
for my $i ( 0 .. $#roles ) {
    my ( $id, $title, $when, $cur, $fixed ) = @{ $roles[$i] };
    my $k = $i + 1;
    my $m = $cache{$cur} || $extra{$cur} || { w => '?', h => '?', d => '?' };
    my $k1 = $i + 1;
    if ($fixed) {
        $steps .= <<"STEP";
<section class="step fixed" data-id="$id" data-cur="$cur" data-fixed="1" hidden>
  <div class="card">
    <div class="eyebrow">Prop $k1 of $n &middot; fixed</div>
    <h2>$title</h2>
    <p class="when">$when</p>
    <div class="cur"><span>Model:</span><code>$cur</code><span class="dims">$m->{w} x $m->{h} x $m->{d}</span><button class="view" type="button" data-name="$cur">View</button></div>
    <p class="fits" style="margin-top:8px">This role is fixed: there is nothing to pick here. Press Next when you are done looking.</p>
  </div>
</section>
STEP
    }
    else {
        $steps .= <<"STEP";
<section class="step" data-id="$id" data-cur="$cur" hidden>
  <div class="card">
    <div class="eyebrow">Prop $k1 of $n</div>
    <h2>$title</h2>
    <p class="when">$when</p>
    <div class="cur"><span>Today:</span><code>$cur</code><span class="dims">$m->{w} x $m->{h} x $m->{d}</span><button class="view" type="button" data-name="$cur">View</button><button class="keep" type="button">Keep it</button></div>
  </div>
</section>
STEP
    }
}

my @all_for_script = ( @models, @extra_models );
my $scripts = join( '', map { qq~<script type="application/json" data-model="$_->{name}">$_->{json}</script>\n~ } @all_for_script );
my $count   = scalar @models;

print <<"HTML";
<title>Magmagat Prop Picker</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght\@500;700&family=IBM+Plex+Sans:wght\@400;600&family=IBM+Plex+Mono:wght\@400;500&display=swap">
<style>
:root{--bg:#231710;--panel:#2c1d13;--ink:#f3e6d6;--muted:#b89b7f;--line:#4a3222;--accent:#e8641f;--elec:#3aa6c9;--good:#6fbf6f;--bar:#3a2717;--sel:#4a2a12;--canvas:#1a120b}
\@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--bg:#faf3ea;--panel:#ffffff;--ink:#241a10;--muted:#6b5a45;--line:#e3d3bd;--accent:#c9530f;--elec:#1f78b8;--good:#3f8f46;--bar:#efe2cd;--sel:#ffe6cf;--canvas:#e5d9c6}}
:root[data-theme="light"]{--bg:#faf3ea;--panel:#ffffff;--ink:#241a10;--muted:#6b5a45;--line:#e3d3bd;--accent:#c9530f;--elec:#1f78b8;--good:#3f8f46;--bar:#efe2cd;--sel:#ffe6cf;--canvas:#e5d9c6}
body{background:var(--bg);color:var(--ink);font:15px/1.5 "IBM Plex Sans",system-ui,sans-serif;margin:0}
.wrap{max-width:1180px;margin:0 auto;padding:22px 20px 90px}
.top{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:10px}
.top h1{font:700 34px/1 "Barlow Condensed","Arial Narrow",sans-serif;margin:0;flex:1}
.progress{font:13px "IBM Plex Mono",monospace;color:var(--muted)}
.track{height:4px;background:var(--bar);margin:0 0 16px}.track i{display:block;height:100%;background:var(--accent);transition:width .2s}
.grid{display:grid;grid-template-columns:minmax(0,1fr) minmax(320px,46%);gap:18px;align-items:start}
\@media (max-width:860px){.grid{grid-template-columns:1fr}.viewer{position:static}}
.card{background:var(--panel);border:1px solid var(--line);border-left:4px solid var(--accent);padding:16px 18px;margin-bottom:12px}
.eyebrow{font:600 11px "IBM Plex Sans",sans-serif;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
.card h2{font:700 30px/1.05 "Barlow Condensed",sans-serif;margin:4px 0 8px;text-wrap:balance}
.card p{margin:0 0 6px;max-width:70ch}.fits{color:var(--muted);font-size:14px}
.cur{display:flex;align-items:center;gap:10px;margin-top:10px;padding-top:10px;border-top:1px solid var(--line);flex-wrap:wrap}
.cur span:first-child{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
code{font:500 14px "IBM Plex Mono",monospace}
.dims{font:12px "IBM Plex Mono",monospace;font-variant-numeric:tabular-nums;color:var(--muted)}
button{font:600 14px "IBM Plex Sans",sans-serif;cursor:pointer}
.nav button,.pickbtn{background:var(--accent);color:#fff;border:0;padding:9px 16px}
.nav button.ghost,.keep,.view{background:transparent;color:var(--ink);border:1px solid var(--line);padding:7px 12px}
.nav button:disabled,.pickbtn:disabled{opacity:.4;cursor:default}
button:focus-visible,input:focus-visible{outline:2px solid var(--elec);outline-offset:2px}
.filters{display:flex;gap:10px;margin:0 0 8px}
.filters input{flex:1;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px 10px;font:14px "IBM Plex Sans",sans-serif}
.mlist{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:3px;max-height:56vh;overflow:auto;border:1px solid var(--line);background:var(--panel)}
.mrow{display:flex;align-items:center;gap:10px;padding:6px 10px;cursor:pointer;border-bottom:1px solid var(--line)}
.mrow:hover{background:var(--bg)}.mrow.viewing{outline:2px solid var(--elec);outline-offset:-2px}.mrow.picked{background:var(--sel)}
.viewer{position:sticky;top:12px;background:var(--panel);border:1px solid var(--line)}
.viewer canvas{display:block;width:100%;height:420px;background:var(--canvas)}
.vbar{display:flex;align-items:center;gap:10px;padding:10px 12px;flex-wrap:wrap;border-top:1px solid var(--line)}
.vbar .dims{margin-left:auto}
.hint{font-size:12px;color:var(--muted);padding:0 12px 10px}
.summary .list{font:13px/1.7 "IBM Plex Mono",monospace;white-space:pre-wrap;background:var(--panel);border:1px solid var(--line);padding:12px}
.summary textarea{width:100%;box-sizing:border-box;min-height:80px;margin:10px 0;background:var(--panel);color:var(--ink);border:1px solid var(--line);padding:8px;font:14px "IBM Plex Sans",sans-serif}
.foot{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:10px 20px;display:flex;justify-content:center;gap:10px;z-index:3}
</style>
<div class="wrap">
<div class="top"><h1>Magmagat Prop Picker</h1><span class="progress" id="prog"></span></div>
<div class="track"><i id="bar" style="width:0%"></i></div>
<p style="color:var(--muted);margin:0 0 14px;max-width:80ch">One prop role at a time. Read where it is used, view what is used today, then (except for the fixed roles) search the list, click a model to see it in 3D (grey: shape and size only, the game adds the textures), and press "Pick this one". $count zm_prison models from the mod's own p6_zm_al_ set plus generic p6_/p_/zombie_ props (models over ~420 KB of glTF are left out to keep the page small); sizes are measured straight from the glTF mesh bounds. The grid cells are 10 units, the post is a 70-unit player.</p>
<div class="grid">
<div class="left">
$steps
<section class="step summary" data-id="summary" hidden>
  <div class="card"><div class="eyebrow">Done</div><h2>Your picks</h2><p>Copy this and paste it back. "keep" means the current model stays; fixed roles are listed as-is.</p></div>
  <div class="list" id="sumlist"></div>
  <textarea id="notes" placeholder="Notes (too big, wrong pose, lay it flat, ...)"></textarea>
  <button class="pickbtn" type="button" id="copy">Copy picks</button>
</section>
<div id="listwrap">
<div class="filters"><input type="search" id="search" placeholder="Search a model name (e.g. skull, barrel, candle, wood)"></div>
<ul class="mlist" id="mlist">$list</ul>
</div>
</div>
<div class="viewer" id="viewer"><canvas id="c"></canvas>
<div class="vbar"><code id="vname">nothing loaded</code><span class="dims" id="vdims"></span><button class="pickbtn" type="button" id="pick" disabled>Pick this one</button></div>
<div class="hint">Drag to turn, wheel to zoom, right-drag to pan.</div></div>
</div>
</div>
<div class="foot nav"><button type="button" class="ghost" id="prev">Previous</button><button type="button" class="ghost" id="skip">Skip</button><button type="button" id="next">Next</button></div>
$scripts
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three\@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three\@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script>
(function(){
  var steps=Array.prototype.slice.call(document.querySelectorAll('.step')),cur=0,picks={},keep={},viewing=null;
  var notes=document.getElementById('notes');
  try{var st=JSON.parse(localStorage.getItem('mg_wiz_mdl')||'{}');picks=st.picks||{};keep=st.keep||{};cur=st.cur||0;notes.value=st.notes||'';}catch(e){}
  function save(){try{localStorage.setItem('mg_wiz_mdl',JSON.stringify({picks:picks,keep:keep,cur:cur,notes:notes.value}))}catch(e){}}
  var canvas=document.getElementById('c'),renderer,scene,camera,controls,model=null,ok=!!(window.THREE&&THREE.GLTFLoader&&THREE.OrbitControls);
  if(ok){
    renderer=new THREE.WebGLRenderer({canvas:canvas,antialias:true,alpha:true});renderer.setPixelRatio(window.devicePixelRatio||1);
    scene=new THREE.Scene();camera=new THREE.PerspectiveCamera(45,1,0.5,5000);camera.position.set(90,70,120);
    controls=new THREE.OrbitControls(camera,canvas);controls.enableDamping=true;
    scene.add(new THREE.HemisphereLight(0xffffff,0x5a4030,0.9));var dl=new THREE.DirectionalLight(0xffffff,0.8);dl.position.set(120,200,80);scene.add(dl);
    var grid=new THREE.GridHelper(400,40,0xe8641f,0x8a7060);grid.material.opacity=0.6;grid.material.transparent=true;scene.add(grid);
    var post=new THREE.Mesh(new THREE.BoxGeometry(6,70,6),new THREE.MeshStandardMaterial({color:0x3aa6c9,roughness:0.9}));post.position.set(-60,35,0);scene.add(post);
    function resize(){var w=canvas.clientWidth,h=canvas.clientHeight;if(canvas.width!==w||canvas.height!==h){renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix()}}
    (function loop(){requestAnimationFrame(loop);resize();controls.update();renderer.render(scene,camera)})();
  }else{document.getElementById('viewer').querySelector('.hint').textContent='The 3D libraries did not load; pick by name and size, I will check the shape.'}
  var loader=ok?new THREE.GLTFLoader():null,mat=ok?new THREE.MeshStandardMaterial({color:0xb89070,roughness:0.85,metalness:0.05,side:THREE.DoubleSide}):null;
  function show(name){
    var el=document.querySelector('script[data-model="'+name+'"]');if(!el)return;
    viewing=name;document.getElementById('vname').textContent=name;
    var row=document.querySelector('.mrow[data-name="'+name+'"]');document.querySelectorAll('.mrow.viewing').forEach(function(r){r.classList.remove('viewing')});
    if(row){row.classList.add('viewing');document.getElementById('vdims').textContent=row.querySelector('.dims').textContent+' units'}
    var s=steps[cur];document.getElementById('pick').disabled=!s||s.dataset.fixed==='1';
    if(!ok)return;
    loader.parse(el.textContent,'',function(g){
      if(model){scene.remove(model)}model=g.scene;model.traverse(function(o){if(o.isMesh){o.material=mat}});scene.add(model);
      var box=new THREE.Box3().setFromObject(model),size=box.getSize(new THREE.Vector3()),center=box.getCenter(new THREE.Vector3());
      var m=Math.max(size.x,size.y,size.z,8);controls.target.copy(center);camera.position.set(center.x+m*1.2,center.y+m*0.9,center.z+m*1.6);camera.near=m/100;camera.far=m*50;camera.updateProjectionMatrix();
    },function(e){document.getElementById('vname').textContent=name+' (could not parse)'});
  }
  function summary(){var out=[];steps.forEach(function(s){var id=s.dataset.id;if(id==='summary')return;var t=s.querySelector('h2').textContent;var v;if(s.dataset.fixed==='1'){v='fixed ('+s.dataset.cur+')'}else{v=picks[id]?picks[id]:(keep[id]?'keep ('+s.dataset.cur+')':'-- not decided --')}out.push(t+' = '+v)});return out.join('\\n')}
  function markPicked(){var s=steps[cur],p=s?picks[s.dataset.id]:null;document.querySelectorAll('.mrow').forEach(function(r){r.classList.toggle('picked',r.dataset.name===p)})}
  function go(i){cur=Math.max(0,Math.min(steps.length-1,i));steps.forEach(function(s,k){s.hidden=k!==cur});
    var last=cur===steps.length-1,fixed=!last&&steps[cur].dataset.fixed==='1';
    document.getElementById('listwrap').hidden=last||fixed;
    document.getElementById('prog').textContent=last?'summary':('prop '+(cur+1)+' / '+(steps.length-1));
    document.getElementById('bar').style.width=Math.round(100*cur/(steps.length-1))+'%';
    document.getElementById('prev').disabled=cur===0;document.getElementById('skip').disabled=last;document.getElementById('next').disabled=last;
    document.getElementById('next').textContent=cur===steps.length-2?'Finish':'Next';
    if(last)document.getElementById('sumlist').textContent=summary();else show(picks[steps[cur].dataset.id]||steps[cur].dataset.cur);
    markPicked();window.scrollTo(0,0);save()}
  steps.forEach(function(s){var id=s.dataset.id;
    var v=s.querySelector('.view');if(v)v.addEventListener('click',function(){show(v.dataset.name)});
    var k=s.querySelector('.keep');if(k)k.addEventListener('click',function(){keep[id]=1;delete picks[id];save();go(cur+1)});
  });
  document.querySelectorAll('.mrow').forEach(function(r){r.addEventListener('click',function(){show(r.dataset.name)})});
  document.getElementById('pick').addEventListener('click',function(){if(!viewing)return;var s=steps[cur];if(!s||s.dataset.id==='summary'||s.dataset.fixed==='1')return;picks[s.dataset.id]=viewing;delete keep[s.dataset.id];save();markPicked()});
  document.getElementById('search').addEventListener('input',function(){var q=this.value.toLowerCase();document.querySelectorAll('.mrow').forEach(function(r){r.hidden=q&&r.dataset.name.indexOf(q)<0})});
  document.getElementById('prev').addEventListener('click',function(){go(cur-1)});
  document.getElementById('next').addEventListener('click',function(){go(cur+1)});
  document.getElementById('skip').addEventListener('click',function(){go(cur+1)});
  notes.addEventListener('input',save);
  document.getElementById('copy').addEventListener('click',function(){var t=summary();if(notes.value)t+='\\n\\nNotes: '+notes.value;var b=this;function done(){b.textContent='Copied';setTimeout(function(){b.textContent='Copy picks'},1500)}if(navigator.clipboard){navigator.clipboard.writeText(t).then(done,function(){prompt('Copy this:',t)})}else{prompt('Copy this:',t)}});
  go(cur);
})();
</script>
HTML
