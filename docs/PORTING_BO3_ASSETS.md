# Porting BO3 Custom-Map Assets (Magmagat, Blundergat, blue-flame barrels, forge) into Plutonium T6

## Verdict: Partly

Extracting the models/textures and getting a static prop or a re-skinned weapon into a T6 mod.ff
is realistic. Adding it as a genuinely **new** weapon with its own animation set is much harder,
because BO3 (T7 engine) and BO2 (T6 engine) use different skeleton/animation formats, and
OpenAssetTools has **no material authoring pipeline for T6** — materials can only be dumped/loaded
in their already-compiled form. The hard blocker for a full "new weapon with custom hands anims"
goal is animations: there is no known tool that converts T7 xanims to T6 xanims automatically, so
new viewmodel animation would have to be manually re-created (reused BO2 anims retargeted, or
hand-animated in Blender against a T6 viewhands rig). A visual reskin/prop-only mod (no new anims)
is the realistic scope for a first pass.

## Pipeline

### 1. Extract assets from the BO3 Workshop map
- The Workshop map is stored as `usermaps/<mapname>/zm_<mapname>.ff` + `.xpak` (not the encrypted
  Ricochet format — BO3 predates Ricochet, which only covers MW19/Cold War/Vanguard onward, so
  **Cordycep is not needed here**; Cordycep is for Ricochet-era titles, not BO3.
  ([AreWeAntiCheatYet #190](https://github.com/Starz0r/AreWeAntiCheatYet/issues/190))
- Use **Greyhound** (Scobalula's actively maintained fork of Wraith Archon) to open the map's `.ff`/`.xpak`
  and export xmodels, images, and materials. Greyhound explicitly targets BO3-era IW-engine titles and
  had a fix specifically for the LZ4 xpak-cache decompression error that blocked exporting BO3 assets,
  which is the exact container format custom Workshop maps ship in.
  ([Greyhound repo](https://github.com/Scobalula/Greyhound), [Greyhound docs](https://scobalula.github.io/Greyhound/))
- Export format to request: XMODEL_EXPORT (or OBJ) for the mesh, plus the material's linked
  images as DDS/PNG. Weapon rigs (Magmagat/Blundergat) will also need the associated xanims
  exported if you want the original BO3 hand animations as *reference* (they cannot be used
  directly in T6, see step 4).
- Practical note: Greyhound reads the map's own loaded fastfile once it's pointed at the game
  install with the usermap present, i.e. this is the base-game-plus-mod extraction path (it's
  not extracting anything Activision-encrypted or DRM'd) — it works the same for a Workshop
  mod .ff as for a retail zone.

### 2. Bring the model into T6 format with OpenAssetTools (OAT)
- OAT (`Laupetin/OpenAssetTools`) supports T6 XModel data in three interchange formats:
  `XMODEL_EXPORT`/`XMODEL_BIN`, `OBJ`, and `GLB/GLTF`.
  ([SupportedAssetTypes.md](https://github.com/Laupetin/OpenAssetTools/blob/main/docs/SupportedAssetTypes.md))
- **Materials are the weak point**: OAT's docs state plainly "Dumping/Loading is currently possible
  for materials in their compiled form. There is currently no material pipeline" — i.e. there is
  no JSON/source material format you author from scratch; you take an existing T6 material as a
  template, edit it in its compiled structure, and repoint its image slots.
  ([SupportedAssetTypes.md](https://github.com/Laupetin/OpenAssetTools/blob/main/docs/SupportedAssetTypes.md))
- Images (GfxImage) are dumped/loaded normally (DDS in, IWI equivalent handled by the tool), with a
  caveat that a few special image encodings aren't supported yet — same source as above.
- Real-world confirmation this works end-to-end today: **JezuzLizard/t6-fastfile-mods** is a live
  collection of OAT-built T6 mods (a player-model pack, an AI pack, a weapons pack `zm_coolweps`)
  that ships custom xmodels/materials/images compiled into mod.ff via OAT.
  ([t6-fastfile-mods](https://github.com/JezuzLizard/t6-fastfile-mods))
- The community-written tutorial "[Tutorial][T6][Zombies] How to Add Custom Playermodels to BO2
  Zombies" walks the exact chain used in practice: Blender 3.x + BetterBlenderCod add-on +
  the OpenAssetTool Blender add-on to build/export an XMODEL_EXPORT, DDS→IWI conversion for
  textures, then OAT's Linker compiles model+material+image+gdt into an .ff.
  ([forum thread](https://forum.plutonium.pw/topic/43387/tutorial-t6-zombies-how-to-add-custom-playermodels-to-bo2-zombies))
- New weapons are added the same GDT-driven way: create a `bulletweapon` asset in APE
  (Asset Property Editor)/GDT, point its viewmodel/worldmodel xmodel fields and its XAnims fields
  at your assets, then build with OAT's Linker into a fastfile.
  ([Zone Files reference](https://openassettools.dev/reference/zone-file.html))

### 3. Load the compiled mod.ff in Plutonium
- Plutonium's own docs ("Loading Mods into Plutonium") and forum posts agree: drop the mod folder
  containing `mod.ff` (it can also carry `.iwd`/soundbanks) into
  `%localappdata%\Plutonium\storage\t6\mods\<modname>\`, then pick it from the in-game **Mods**
  menu before loading a map. ([plutonium.pw/docs/modding/loading-mods](https://plutonium.pw/docs/modding/loading-mods/),
  [forum: Using the mods folder in bo2 plutonium](https://forum.plutonium.pw/topic/37428/using-the-mods-folder-in-bo2-plutonium))
- The Mods menu is effectively single-select: forum reports confirm you can't run two different
  mod.ff's simultaneously through the menu — you either merge assets into one mod.ff, or install
  one mod's loose files to `scripts/zm` and load the other via the Mods menu.
  ([forum: "I try to play with 2 different mods at the same time and I can't"](https://forum.plutonium.pw/topic/39670/i-try-to-play-with-2-different-mods-at-the-same-time-and-i-can-t))
- Loose GSC scripts are a **separate, parallel loading path**: `.gsc` files placed in
  `%localappdata%\Plutonium\storage\t6\scripts\zm\` (named `zm_*.gsc`) autoload independently of
  whatever is selected in the Mods menu — so this project's existing `mg_*.gsc` scripts keep
  loading normally alongside a selected mod.ff. ([Loading Mods into Plutonium](https://plutonium.pw/docs/modding/loading-mods/))

### 4. New weapon vs. reskin — what's actually been done
- **Reskins/retextures** are common and low-risk: e.g. the forum's "WHITE — Complete Zombies
  Weapons, Explosives & Viewmodel Retexture Pack" swaps textures/materials on stock weapon
  xmodels without touching animations or the weapon file's skeleton binding.
  ([forum thread](https://forum.plutonium.pw/topic/42944/white-complete-zombies-weapons-explosives-viewmodel-retexture-pack-all-maps-compatible))
- **Adding whole existing weapons to maps that don't have them** (not new content, but new-to-map)
  is also proven: `sehteria/T6-ZM-Weapons` (`zm_weapons`) adds every BO2 Pack-a-Punchable weapon,
  with correct map-specific PaP camo, to every map's mystery box, distributed as a mod.ff via the
  Mods menu. This is pure reuse of stock BO2 xmodels/xanims — no cross-game anim problem.
  ([sehteria/T6-ZM-Weapons](https://github.com/sehteria/T6-ZM-Weapons))
- **Truly new weapon meshes with new animations**: the JezuzLizard `zm_coolweps` pack and the
  player-model pack show new *models* are being shipped, but I found no documented case of a
  fully new BO3/other-game hand-animation set (pullout/reload/idle/ADS) ported wholesale into T6 —
  the "[MP/ZM] Custom Animations/Animation Swap Tutorial" thread only covers **reassigning existing
  T6 xanims to different weapon slots**, not importing foreign-engine anims.
  ([forum thread](https://forum.plutonium.pw/topic/41625/mp-zm-custom-animations-animation-swap-tutorial))
- A cross-game weapon-porting precedent exists in the other direction (IW5/T6 → T5, an older/simpler
  engine), confirming modders do this kind of cross-title weapon port, but it's manual, per-bone
  rework, not a pushbutton conversion — and BO3→BO2 is the harder direction (newer, more complex
  T7 rig going into an older T6 rig). ([How to port weapons from IW5/T6 to T5](https://forum.plutonium.pw/topic/22918/how-to-port-weapons-from-iw5-t6-to-t5))
- **Practical recommendation**: treat the Magmagat as a **worldmodel/viewmodel reskin or static
  prop swap onto the existing Blundergat's T6 skeleton and animation set** (mesh + material only,
  reuse stock wonder-weapon anims), rather than trying to also import BO3 animations. That collapses
  the task to the proven "reskin" pipeline above.

### 5. Loading a model without a fastfile
- Not viable for a distributable/normal-use mod. Plutonium's raw/IWD loading path does exist for
  **development iteration only**: OAT's own workflow has you drop `xmodel`, `model_export`,
  and `materials` folders under the OAT `raw/t6` working directory, but this is explicitly a
  pre-compile staging area — the asset still has to be built into an .ff (or an IWD) before the
  game will actually load it in a normal play session; a raw folder is not an alternative
  runtime asset source on its own. IWDs are supported as a mods-folder companion to a mod.ff, and
  a `weapon_load_order` dvar lets raw/IWD-loaded weapon files override fastfile ones for
  development, but this is a dev/debug convenience, not a way to skip building a fastfile for
  a shareable mod. (Confirmed via the JezuzLizard mod repo structure and OAT raw-folder
  convention: [t6-fastfile-mods](https://github.com/JezuzLizard/t6-fastfile-mods),
  [Loading Mods into Plutonium](https://plutonium.pw/docs/modding/loading-mods/))

## Limits found
- No T6 material authoring pipeline in OAT — you edit an existing compiled material's image
  slots/settings rather than writing one from a human-readable source format.
- Mods menu loads one mod.ff at a time; must merge multiple mods into a single .ff to combine them.
- No known automated T7 (BO3) → T6 (BO2) xanim converter; skeleton/rig differences mean new
  animations are effectively a manual re-creation, not a port.
- Some GfxImage encodings aren't supported by OAT yet, which can bite on certain BO3 texture
  formats (needs a per-texture check during extraction).
- Multiteam/asset-count ceilings exist in T6 fastfiles (the JezuzLizard player-model pack's own
  README warns its pack blows the image asset limit on multiteam) — a large added-asset mod should
  budget for hitting the zone's image/asset caps.

## Effort estimate
- Extraction + inspection of the four assets (Magmagat, Blundergat retexture reference, barrels,
  forge prop) with Greyhound: **0.5–1 day**.
- Getting one static prop (forge or barrel) into T6 as a placed map prop via OAT + mod.ff,
  including material/image rebuild: **1–2 days** (mostly OAT/GDT learning curve if new to it).
- Reskinning the Blundergat viewmodel/worldmodel with the Magmagat mesh+textures, keeping stock
  BO2 animations and weapon file: **2–4 days**, including iterating on rig weighting so the mesh
  deforms correctly on the existing T6 viewhands/worldmodel skeleton.
- Full new weapon with ported/rebuilt custom animations (stretch goal): **5–10+ days**, and carries
  real risk of not converging, since it requires effectively hand-animating or heavily reworking a
  viewmodel anim set rather than a straight port.
- **Total realistic scope (props + reskinned weapon, no new anims): ~4–7 days.**

## Legal / etiquette note
The Workshop map's own assets may be nekoBoy's original work, or may themselves be ported from
BO4 (Blood of the Dead) or other titles — Workshop custom-map credits sections commonly acknowledge
third-party asset sources, and the wider BO3 modding community (Modme wiki, CabConModding,
ZGC/DEVRAW asset sites) routinely shares and reuses ported assets between titles, but expects
attribution. Standard etiquette in this scene: message the map author (nekoBoy) via the Steam
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
