# Porting the BO3 remaster's assets into Plutonium T6

How the mod carries the BO3 Workshop map "MOB OF THE DEAD" (copforthat) and Black Ops 4 assets into a T6 `mod.ff`:
the props, the Magmagat, the effects and the sounds. [CONTRIBUTING.md](CONTRIBUTING.md) lists the prerequisites and
the commands; this page explains the parts that are not obvious.

## History

This page began as a feasibility study before the project. It expected a reskin at best: no T7 to T6 animation
converter exists, and OpenAssetTools has no T6 material pipeline or effect loader. Most of that has since been solved
or worked around. The real BO4 Magmagat sits on BO2's Blundergat rig (Treyarch built it on that rig), so BO2's own view
animations fit it. Materials are cloned from vanilla ones. Effects go through a patched OpenAssetTools (below). The
scripts ship inside the mod folder, not as loose `scripts\zm\` files. The study's estimates and recommendations are
obsolete and have been removed; its sources are kept at the end.

## The pipeline

### Extraction
Workshop maps are plain BO3 fastfiles plus `.xpak` files (not the Ricochet-encrypted format of later titles, so
Cordycep is not needed). **Greyhound** (Scobalula) exports their models and images from the running game, and the mod
reads the map's own `zm_prison.ff` and sound banks for the sounds (`tools/import_sounds.pl`, `tools/MgBo3.pm`). BO3
streams meshes and textures in on demand, so export a model while it is in view in game. The Magmagat's lava blob
(`p8_fxp_magma_blob`) is only loaded once the Magmagat has fired.

Black Ops 4's own forge props (the smelter's lever, the mantle skulls, the ghouls and their animations, the burnt
splinters) come from a Greyhound export of BO4 on Blood of the Dead (`black_ops_4_sp`).

### Props (`tools/import_all.pl`, `tools/import_prop.pl`)
Each Greyhound xmodel export becomes a rigid T6 xmodel, one material per surface cloned from vanilla's wood barrel,
with its textures embedded as `*mg_<name>` images (a plain image name makes the Linker write a streamed image, which T6
only looks for in its own `.ipak` files).
- **LODs.** Greyhound's LOD numbers are not a detail order (`p8_zm_esc_machinery_01`'s LOD0 is its coarsest), so the
  LODs are sorted most detailed first by file size, and at most 4 are kept. A LOD exported without meshes (not
  streamed in at export) is skipped. A model whose LODs are all empty exits with code 3, and `import_all.pl` leaves it
  out of the zone, so whatever uses it falls back on a vanilla model.
- **Surfaces.** `--skip-color <regex>` drops the surfaces whose colour texture matches: the press's decal layers
  (rust grunge, dirt, bolts), which BO3 blends over the machine and T6's lit template would draw as opaque patches.
  `--bones` splits a skinned model into parts script can move (the press's body and its ram). `--material` puts every
  surface on an existing material (the splat meshes and the blob wear the mod's lava, `mc/mg_lava`, since their BO3
  shader is procedural). `--color` swaps a colour map, such as the drum's, whose paint tint `tools/paint_mask.pl`
  bakes in. `--skinned` keeps a model's skeleton for its xanims (the ghouls), `--material-rename` puts their parts on
  the mod's ghost materials (`tools/build_ghoul_mats.pl`: Mob's Afterlife ghost with BO4's normal maps), `--tail`
  shortens and tapers their ghost tail, `--stretch` fits the lever. `--skip <regex>` drops surfaces by material name,
  `--offset`, `--scale` move and scale the mesh about its pivot, `--tints` bakes in BO3's colour constants
  (`tools/model_tints.pl`). `tools/barrel_fill.pl` builds the drums' filling
  (BO4's ash and burnt splinters) as a Greyhound-style export.

### The weapon (`tools/build_weapon.pl`, `tools/build_magmagat_model.pl`)
BO4's Magmagat and Tempered Blundergat view models were built on BO2's Blundergat rig, so the T6 skeleton is kept as
dumped and only the mesh is replaced, bone names mapped; a BO4-only bone (the right chains, the armour, the rails)
rides the T6 bone of its nearest BO4 parent, so it follows the reload. The comments in both tools give the details. Its view
animations are the Blundergat's: BO4's own (`vm_ww_blundergat_*`) were tried and don't fit BO2's view hands (the gun
filled the screen). The Blundergat's reload, empty reload and first raise are copied into mod.ff by
`tools/build_weapon.pl` with their sound notes rewritten to BO4's reload sounds (see CONTRIBUTING.md, "The reload
sounds").

### The effects (`tools/bo3_fx.pl`)
BO3 effects port 1:1. Neither upstream OpenAssetTools nor Greyhound handles effects, so the mod carries both halves:

1. **A T6 effect format for OAT.** `tools/oat/t6-fx-json.patch` (against OpenAssetTools `f8f54426`, GPL-3.0 like OAT)
   adds a T6 `FxEffectDef` JSON dumper to the Unlinker and a loader to the Linker (and a static-model list,
   `gfxworld/<map>_smodels.csv`: which prop stands where), field for field (`fx/<name>.json`;
   a vanilla effect round-trips byte for byte). Build: clone OAT, `git apply` the patch, `generate.bat` (or
   `premake5 vs2022`), then MSBuild the solution targets `Tools\LinkerCli` and `Tools\UnlinkerCli` (Release, Win32)
   with the VS 2022 Build Tools (C++). `tools/build_mod.pl` uses that Linker (`MG_OAT_FX`).
2. **BO3's compiled effects.** A compiled T7 effect points at its materials by address, so it is read from the
   running game: start BO3 on the remaster's map and run `tools/bo3mem/Bo3Snapshot.exe mod/work/bo3mem/fx.bin`
   from the repo root (build line in its source; it finds the asset pools with HydraX's signature and copies every
   loaded effect with the memory it reaches, read-only). That memory includes each material with its techset, its
   textures and its settings buffers, so the material settings (the HDR scale below) come from the snapshot too.
   `tools/MgFx7.pm` turns a T7 effect into T6's; its layout was worked out against the BO2 effects the remaster ported
   unchanged (header 144 bytes, element 608, velocity samples 96 = T6's, visual samples 80; the element fields, flags,
   atlas, trail and rotation conversions are commented there).
3. **Textures.** Greyhound with "Load xImage from the game" on, images only, exports the effect textures
   (`black_ops_3_sp/ximages` or `black_ops_3/ximages`). `tools/bo3_fx.pl` clones a vanilla zm_prison effect material
   per BO3 material (blend, emissive blend, additive, distortion, cloud, decal) and embeds the texture.
4. **HDR.** T6 has no HDR. BO3's emissive materials carry an `hdrScale` (8 for a soft glow, 256 for fire, 2048+ for a
   white-hot core), read from the material's settings buffer in the snapshot (named by the pass shader's DXBC, as
   HydraX reads them). `HDR_WHITE` (64) is the scale taken as plain white. A material above it draws additive, and
   gets a gain of `hdrScale / 64`: its elements' colours are multiplied by that gain (saturating, as BO3's tone map
   does), and so is its texture's colour, never its alpha, with the gain capped at `IMAGE_GAIN_CAP` (2), clamped (one
   copy of the texture per gain, `mg_<image>_rgb<gain>`, since the colours alone saturate: BO3's blue flame is
   (0, 76, 255) times 256 over a texture whose brightest pixels are 146). The full gain on colour and alpha squared it
   on an additive sprite and turned the faint rays of Harry's trail stars solid (a firework round the blob). A
   `fullgain` line of `tools/assets/bo3_fx.tsv` keeps the old full gain, colour and alpha (`mg_<image>_x<gain>`), for
   its effect, the effects it runs and any material they share: the effects tuned in game before the cap (the blue
   flames, the lockdown, the press fire, the lava pool). A material at or below 64 keeps its colours and BO3's alpha
   blend. Tune `HDR_WHITE` or `IMAGE_GAIN_CAP` in `tools/bo3_fx.pl` if the effects look too hot or too dim.
5. **Copies.** A line of `tools/assets/bo3_fx.tsv` can carry `as=<name>`: instead of the effect itself, a copy
   `mg/<name>` is shipped, with `tint=r,g,b` every colour replaced by its brightness times the tint, `spread=k` and
   `size=k` its sideways origins and its sprites scaled (the drums' flame and flare).
   (`scale=x,y` stretches an effect's element origins instead: the lockdown outline, fitted from the remaster's slightly
   smaller office to BO2's. `surface` turns the elements that run relative to the world to their spawn, so the effect
   lies on the surface it is played on: the lava pool on a wall.)

A visual the snapshot missed is dropped (a null material crashes T6 when drawn), and so is an element left with none.

The effects in the mod are listed in `tools/assets/bo3_fx.tsv`; they become `mg/<name>`. Most are the remaster's own
(`_copforthat/_zm_prison/*`: the blue flames, the lockdown, the press fire, the lava pool, the soul). The rest are
Harry's effects, which the remaster ships: `harry/magmagat/*` (the blob's trail, impact and burst,
`mg/fx_magmagat_trail_bolt`, `_impact`, `_explode`, which the Magmagat weapon files name) and `harry/blundersplat/*`
(the fire-coloured Acid Gat muzzle flash the Magmagat fires with). Two more are Mob's
own fires with their glow taken out, for the forge and the fireplace (`mg/fx_mg_forge_fire`, `mg/fx_mg_forge_flare`,
from `fx_alcatraz_fire_sm` and `fx_alcatraz_falling_fire_impact`). The lava pool a miss
lays is `mg/fx_prison_magmagat_aoe`. Not carried over: BO3's sound elements and spawn sounds (BO3 aliases; the mod
plays its sounds from script) and BO3-only element types. A server script cannot play an effect on the view model,
so the tempered gun's `_vm` flame is played by the mod's client script (`csc/zm_prison_magmagat.csc`, installed
beside the packed `.gsc`, where Plutonium runs it on the client; `playviewmodelfx`, replayed every 0.1 s), as the
remaster does, always full; the others see the same flame replayed on the world gun by `mg_run.gsc`, thinning out
under 10 s of temper.

## Limits found
- No T6 material authoring pipeline in OAT — you edit an existing compiled material's image
  slots/settings rather than writing one from a human-readable source format.
- Mods menu loads one mod.ff at a time; must merge multiple mods into a single .ff to combine them.
- No known automated T7 (BO3) → T6 (BO2) xanim converter; skeleton/rig differences mean new
  animations are effectively a manual re-creation, not a port. BO4's animations do carry over (the ghouls'):
  Greyhound exports them as Direct XAnim (BO1 compatibility), which OAT's Linker reads. BO4's view animations load
  too but don't fit BO2's view hands (their joints are oriented for BO4's arms).
- Some GfxImage encodings aren't supported by OAT yet, which can bite on certain BO3 texture
  formats (needs a per-texture check during extraction).
- Multiteam/asset-count ceilings exist in T6 fastfiles (the JezuzLizard player-model pack's own
  README warns its pack blows the image asset limit on multiteam) — a large added-asset mod should
  budget for hitting the zone's image/asset caps.

## Legal / etiquette note
Of what the mod takes from the Workshop map, only the effect definitions are the team's own work
(`_copforthat/_zm_prison/*`, and Harry's `harry/*`); the models, the textures inside the effects and, by their BO4
names, the sounds are Treyarch's (BO3 `p7_`, BO4 `p8_`, `fxt_`/`fxt8_` images). Workshop custom-map credits sections commonly acknowledge
third-party asset sources, and the wider BO3 modding community (Modme wiki, CabConModding,
ZGC/DEVRAW asset sites) routinely shares and reuses ported assets between titles, but expects
attribution. Standard etiquette in this scene: message the map author (copforthat) via the Steam
Workshop page or Discord before redistributing extracted assets, credit both the original modeler
and, if applicable, the underlying game the asset was first ripped from (Activision/Treyarch, via
BO4), and keep the resulting T6 mod as a free, non-commercial fan release with credits in the
mod's README/forum post — consistent with how sehteria's and JezuzLizard's released mods and the
BO2-Reimagined project all publish credits alongside their GitHub/forum releases.
([Jbleezy/BO2-Reimagined](https://github.com/Jbleezy/BO2-Reimagined),
[sehteria/T6-ZM-Weapons](https://github.com/sehteria/T6-ZM-Weapons))

## Sources
- https://github.com/Scobalula/Greyhound
- https://scobalula.github.io/Greyhound/
- https://github.com/Starz0r/AreWeAntiCheatYet/issues/190
- https://github.com/Laupetin/OpenAssetTools
- https://github.com/Laupetin/OpenAssetTools/blob/main/docs/SupportedAssetTypes.md
- https://openassettools.dev/reference/zone-file.html
- https://github.com/JezuzLizard/t6-fastfile-mods
- https://forum.plutonium.pw/topic/43387/tutorial-t6-zombies-how-to-add-custom-playermodels-to-bo2-zombies
- https://plutonium.pw/docs/modding/loading-mods/
- https://forum.plutonium.pw/topic/37428/using-the-mods-folder-in-bo2-plutonium
- https://forum.plutonium.pw/topic/39670/i-try-to-play-with-2-different-mods-at-the-same-time-and-i-can-t
- https://forum.plutonium.pw/topic/42944/white-complete-zombies-weapons-explosives-viewmodel-retexture-pack-all-maps-compatible
- https://github.com/sehteria/T6-ZM-Weapons
- https://forum.plutonium.pw/topic/41625/mp-zm-custom-animations-animation-swap-tutorial
- https://forum.plutonium.pw/topic/22918/how-to-port-weapons-from-iw5-t6-to-t5
- https://github.com/Jbleezy/BO2-Reimagined
