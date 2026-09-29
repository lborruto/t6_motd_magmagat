# Contributing to Magmagat (developer documentation)

This file is for people who want to read, build, test or change the mod. Players should read the
[README](../README.md) and, for spoilers, [GUIDE.md](GUIDE.md). The owner's in-game test protocol is
[TESTING.md](TESTING.md).

The mod is ONE folder, `mods\zm_magmagat\`: a `mod.ff` fastfile (the props and the Magmagat weapons), a
`mod.json`, and the quest scripts in `scripts\zm\zm_prison\`. The scripts' sources are the `mg_*.gsc` files in the
repository root; the release carries a BUILD of them: `tools/pack.pl` concatenates the sources into one loadable
file (or a few, when the sources no longer fit one). Never edit a packed file; edit a source and pack again.
The fastfile is built from the game's own files and a Greyhound export of the BO3 map (see "The mod.ff").

The version string `!mg status` prints (`level.mg_version` in `mg_main.gsc`) moves whenever the mechanics
change.

## Toolchain facts that bite

- Plutonium T6 loads every `*.gsc` in `scripts\zm\` and `scripts\zm\zm_prison\` (root level only), and the same
  folders inside the mod picked in the Mods menu (`mods\zm_magmagat\scripts\zm\zm_prison\`). All loaded scripts
  share ONE namespace: a function defined twice is a fatal duplicate at load. So the packed files and the
  sources must never sit in the game folders together, nor an old loose install beside the mod
  (`tools/deploy.pl` handles both for you).
- A compiled T6 script addresses every function and import name as a 16-bit offset into its string block, so
  that block cannot pass 65535 bytes. Over it the game reads names from the wrong place and prints nonsense
  `Unresolved external` errors. Today the ten `mg_*.gsc` sources fit into ONE packed file
  (`release/zm_prison_magmagat.gsc`); if the sources grow past the limit, `tools/pack.pl --parts N` splits
  them into `zm_prison_magmagat_1.gsc` / `_2.gsc` (or more) instead, and both `tools/deploy.pl` and the
  release workflow already try 1, then 2, then 3 parts, so nothing else needs to change when that day comes.
- `"C:/Games/t6/gsc-tools/gsc-tool.exe" -m comp -g t6 -s pc -y <file>` (xensik's gsc-tool) catches SYNTAX
  errors only. It does not catch a misspelled or non-existent function name; those show up as script errors
  in the game console when the map loads (needs `developer 1; developer_script 1`). The lints below exist for
  exactly that gap.
- `precachemodel` works only inside `init()`, before any wait; only models the map precached (or this mod
  precached) can be spawned. Builtins that do not exist in T6 (`array_remove`, `toupper`, `stopfxontag`, ...)
  must never be called: grep the decompiled vanilla scripts for `name(` before using anything unfamiliar.
- Perl 5 core modules only in every tool (no CPAN). From PowerShell use
  `"C:\Program Files\Git\usr\bin\perl.exe"`; the examples below assume Git Bash from the repo folder.

## Layout of the sources

| File | Responsibility |
|---|---|
| `mg_main.gsc` | `init()` (zm_prison guard, precache, version), `mg_boot()`, chat listener `!mg`, command dispatch, help |
| `mg_systems.gsc` | ported helpers: `mg_debug_print`, `mg_out`, `mg_fx_init`, `mg_fx_loop/once/stop`, `mg_fx_keepalive`, `mg_snd_near`, `mg_prompt`, `mg_press_use`, `mg_bar_*`, `mg_hud_title`, `mg_death_listen_add/remove`, `mg_zombies_near`, `mg_trail`, HUD disconnect cleanup |
| `mg_coords.gsc` | anchor registry `mg_coord( key )` / `mg_coord_set`, `mg_apply_overrides()` (owner spots pasted here), `mg_models_init` / `mg_model( kind )` / `mg_precache()` (the barrel and skull models come from our mod.ff) |
| `mg_place.gsc` | live placement mode `!mg grab <KEY>` / `drop` / `cancel` / `rot` / `up` (ported from Dead Frequency's `df_place.gsc`), anchor previews `mg_preview_show` / `mg_preview_refresh` / `mg_preview_hide` / `mg_preview_teleport` |
| `mg_quest.gsc` | `level.mg_state`, `mg_state_set( s )`, `mg_state_is( s )`, `level notify( "mg_state", s )`, bridge gate, `mg_goto( state )` fabrication, `mg_status_lines()` |
| `mg_hearth.gsc` | fireplace prompt, souls (orbs, skulls), pickup window |
| `mg_run.gsc` | temper timer, barrels, carrier fail rules |
| `mg_forge.gsc` | forge power, place, ghosts, take; open forge in `done` |
| `mg_weapon.gsc` | the Magmagat weapons (`magmagat_zm`, `magmagat_upgraded_zm` from our mod.ff): precache, Pack-a-Punch registration, `player mg_weapon_grant( blundergat )`, shot watcher, lava ball, magma patch |
| `mg_debug.gsc` | shock pistol, `!mg fx` / `!mg snd` audition (ported), `!mg give`, `!mg magma`, `!mg spots` |
| `tools/pack.pl`, `tools/deploy.pl`, `tools/lint_*.pl`, `tools/check_links.pl`, `tools/gsc_header.pl`, `tools/gen_vanilla_map.pl`, `tools/vanilla_namespaces.txt` | build chain, copied from the Dead Frequency mod's tools and re-pointed to this mod's prefix and map |
| `tools/dump_game.pl`, `tools/import_all.pl`, `tools/import_prop.pl`, `tools/bake_layers.pl`, `tools/build_weapon.pl`, `tools/build_magmagat_model.pl`, `tools/gen_lava_fx.pl`, `tools/recolor.pl`, `tools/build_mod.pl`, `tools/release.pl`, `tools/png2dds.pl`, `tools/dds2png.pl`, `tools/MgPng.pm`, `tools/MgDds.pm` | the mod.ff chain and the release (see "The mod.ff") |
| `mod/zone_source/mod.zone`, `mod/mod.json`, `mod/templates/` | the fastfile's asset list (its blocks are written by the tools), the mod's name card, the material template for BO3 props |
| `.github/workflows/check.yml`, `.github/workflows/release.yml`, `tools/publish.pl` | lints and a pack test on every push; the player zip when a release is published (see "The GitHub Actions") |
| `README.md`, `LICENSE`, `docs/GUIDE.md`, `docs/CONTRIBUTING.md`, `docs/TESTING.md` | end-user and contributor docs |

Anchor keys (all in `mg_coords.gsc`): `MG_HEARTH` (gun rest in the fire), `MG_HEARTH_USE` (where the player
stands to press), `MG_SKULL_1`, `MG_SKULL_2`, `MG_SKULL_3`, `MG_BARREL_1..5`, `MG_FORGE` (use point at the
generator), `MG_FORGE_GUN` (gun rest on the generator). Defaults are placeholders near the vanilla free
Blundergat desk struct and the dock generator; the owner replaces them through `mg_apply_overrides()` (see
"Coordinate workflow" below).

State names (strings, exactly): `"locked"`, `"ready"`, `"souls"`, `"pickup"`, `"run"`, `"forge"`, `"done"`.

## The build

### tools/pack.pl (what the release uses)

```
perl tools/pack.pl                  # -> release/zm_prison_magmagat.gsc, refuses an oversized file (exit 3)
perl tools/pack.pl --parts 2        # -> release/zm_prison_magmagat_1.gsc + _2.gsc
perl tools/pack.pl --keep-comments  # readable output, twice the size
```

Concatenates the sources in the order `tools/pack.pl` lists them, strips comments, qualifies the unqualified vanilla helper calls from
`tools/vanilla_namespaces.txt` (so the packed file needs no `#include` resolution at load), estimates the
string block and refuses a file over 62000 bytes (margin under the 65535 engine limit); when `gsc-tool.exe`
is available it also compiles the result and reads the exact number from the binary
(`tools/gsc_header.pl`). Every `mg_*.gsc` in the repo MUST be listed there: a source left out compiles fine
alone and fails at load with `Unresolved external`; `pack.pl` dies if one is missing. Today the sources pack
into ONE file.

### tools/deploy.pl (install the scripts into the mod folder)

```
perl tools/check_links.pl .
perl tools/deploy.pl                # packed: one file if it fits, else two, else three
perl tools/deploy.pl --parts N      # force N packed files
perl tools/deploy.pl --multi        # the sources side by side (development install)
perl tools/deploy.pl --game DIR
```

Game folder: `%localappdata%\Plutonium\storage\t6\mods\zm_magmagat\scripts\zm\zm_prison\`. Each mode removes what
the other modes installed before, and the loose install of the older releases in `scripts\zm\zm_prison\`,
because two layouts must never coexist. Never hand-edit an installed file. `tools/build_mod.pl` installs the
`mod.ff` and `mod.json` beside them.

### The mod.ff (props and the Magmagat)

```
perl tools/import_all.pl       # the BO3 props from the Greyhound export -> mod/props
perl tools/build_weapon.pl     # the Magmagat weapons from BO2's Blundergat -> mod/weapon (--redump to dump again)
perl tools/import_sounds.pl    # the BO3 remaster's quest sounds -> mod/sound (the mod.all sound bank)
perl tools/bo3_fx.pl           # the BO3 remaster's effects -> mod/fx (needs the BO3 snapshot, see PORTING_BO3_ASSETS.md)
perl tools/build_mod.pl        # OpenAssetTools Linker -> mod/out/mod.ff + mod.json, installed into the mod folder
perl tools/deploy.pl           # the scripts, beside it
perl tools/release.pl          # release/zm_magmagat/ (the folder players drop into mods\) + its zip, to try it locally
perl tools/publish.pl          # the GitHub Release: mod.ff up, the release workflow attaches the player zip
```

Needs OpenAssetTools (`C:/Games/t6/openassettools`, env `MG_OAT`), the BO2 install (env `MG_BO2`) and, for the
props, Greyhound's export of the BO3 map "Mob of the Dead Remastered" (`C:/Games/t6/Greyhound-1.49.4.0`, env
`MG_GREYHOUND`: its models in `exported_files/black_ops_3_sp/xmodels`, the map's textures loaded from its `.xpak` in
`exported_files/black_ops_3/ximages`). `mod/props`, `mod/weapon`, `mod/work` and `mod/out` are generated from the
games' files and are never committed (so is `mod/sound`).

- **Props** (`tools/import_all.pl` lists them): each BO3 model becomes a rigid T6 xmodel (Greyhound's glTF, Z-up
  centimetres, turned to the Linker's Y-up inches; at most 4 LODs), one material per surface cloned from a vanilla
  lit template, and its textures embedded in the fastfile as `*mg_<name>` images. A texture given a plain name makes
  the Linker write a STREAMED image, which T6 only looks for in its own `.ipak` files: it never shows. A BO3 layered
  material (a paint and a rust layer through a mask) is baked into one colour map by `tools/bake_layers.pl`;
  `--skip` drops surfaces T6 cannot draw (the barrel's transparent shell, its alpha decal). Textures are block
  compressed by `tools/MgDds.pm` (BC1 colour, BC5 normal): the fastfile stays small.
- **The Magmagat** (`tools/build_weapon.pl`): the Unlinker dumps zm_prison's weapons, models, materials and images
  (the map's images sit in DLC `.ipak` files it only opens under a name it loads itself, so they are hard-linked as
  unused language bases for the dump, `tools/dump_game.pl`). The gun is the real BO4 Magmagat
  (`tools/build_magmagat_model.pl`, from Greyhound's `wpn_t8_zm_magmagat_view`): Treyarch built it on the BO2
  Blundergat's rig, so every BO4 bone sits where its T6 bone does and only the names differ. The T6 skeleton is kept
  exactly as dumped (joint nodes, inverse bind matrices) and only the mesh is replaced: BO4 vertices moved into the
  T6 mesh space, their joints renamed (`tag_weapon` = `j_gun`, `tag_cap_le_animate` = `j_cap_le`, ...; the BO4-only
  armour and right-chain bones ride `j_gun`). So `magmagat_zm` plays every Blundergat animation. Its lava parts are on
  the Acid Gat's bones, so the weapon takes the Acid Gat's `hideTags`. `magmagat_upgraded_zm` (Magmus Operandi) is the
  same model with the BO4 armour kit (the `tag_armor_acid` kit dropped, as BO2 hides it). The world model's LOD0 is
  the same mesh fitted on BO2's world gun; its far LODs are BO2's world gun recoloured (`tools/recolor.pl`).
  Materials: BO4's colour / normal maps on the Blundergat's lit material (a gloss map derived from the colour); the
  molten parts on the Acid Gat's emberglow shader (reveal = BO4's crack mask, ember = BO4's magma glow noise on a
  molten ramp, heat = BO2's flicker; `%lava` turns up glow, flicker and scroll). The display names come from
  `english/localizedstrings/mg_weapons.str`.
- **The effects are meshes, as in BO4** (`tools/gen_lava_fx.pl`): BO4's Magmagat flies a lava blob model and lays
  splat meshes. The two are generated (a noise-displaced sphere, an irregular domed splat) and skinned with the BO3
  remaster's lava (`i_pbr_lava_magma_emissive_1_mtl`) on the emberglow shader; the script flies the blob (tumbling,
  with a fire trail) and lays the pool under every miss.
- **The sounds** (`tools/import_sounds.pl`, the list in `tools/assets/bo3_sounds.tsv`): BO3 banks are the same `2UX#`
  container as T6's (version 15), every sound plain FLAC 48 kHz. The map's zone data names them: each alias record
  holds the alias hash (T6's `SND_HashName`) and, 0x30 after it, the bank entry it plays (`tools/MgBo3.pm`). Every
  variant of an alias is copied out: a `loaded` one decoded to a plain 44-byte-header PCM WAV (`tools/flac2wav.pl`), a
  `streamed` one kept FLAC, as BO2 stores its own. The zone line `soundbank,mod.all` makes the Linker write
  `mod.all.sabl` / `mod.all.sabs` beside `mod.ff`; they ship in the mod folder. Our aliases are `mg_*`; `lint_sounds`
  reads the manifest. In game, `printsoundalias mg_press` (console) shows whether the bank is loaded.
- **What the fastfile cannot carry** (OpenAssetTools v0.33): new particle effects (FxEffectDef is not loaded), new
  tracers (the T6 tracer loader is not registered) and BO3 animations (no tool turns T7 xanims into T6 ones; the
  rig is shared, so the Blundergat's animations fit the BO4 gun). So the particles are zm_prison's own: orange
  buckshot muzzle flashes, `lmg_enemy` red tracers, fire over the pool, the flame riding a held Magmagat
  (`mg_weapon_hold_loop`), the fire whoosh of each shot, the forge reveal.

### The GitHub Actions

- `.github/workflows/check.yml`, every push and pull request: `lint_includes`, `lint_calls`, `lint_sounds`,
  `check_links`, then a pack test (one file, else two, else three) to prove the scripts still load.
- `.github/workflows/release.yml`, when a GitHub Release is published: the player zip. The mod.ff is built from the
  games' files, which never leave the maintainer's PC, so `perl tools/publish.pl` builds it and publishes the release
  `v<version>` (`level.mg_version`) with `mod.ff` attached, on the pushed commit (needs `gh auth login`). The workflow
  checks the tag against the version, lints, packs the scripts from the tagged sources, assembles `zm_magmagat/`
  (mod.ff, mod.json with the version, the packed scripts), attaches `zm_magmagat-<version>.zip` and removes the bare
  `mod.ff`. `workflow_dispatch` rebuilds the zip of an existing release. `tools/release.pl` builds the same folder and
  zip locally, to try a release before publishing it.

## The lints (run all four before every push)

```
perl tools/lint_includes.pl && perl tools/lint_calls.pl && perl tools/lint_sounds.pl && perl tools/check_links.pl .
```

| Tool | Catches |
|---|---|
| `tools/lint_includes.pl` | a `mg_*.gsc` that calls a vanilla SCRIPT helper (not an engine builtin) without the three utility includes (`common_scripts\utility`, `maps\mp\_utility`, `maps\mp\zombies\_zm_utility`) |
| `tools/lint_calls.pl` | a function name called in the sources that is defined in no `mg_*.gsc` and used by name in no vanilla T6 zombies script: almost surely a helper from another CoD |
| `tools/lint_sounds.pl` | a sound alias played by a source that is in none of the game's real alias tables (`tools/assets/soundbank/*.aliases.csv`), i.e. silent in game |
| `tools/check_links.pl` | a `mg_*` function called in a file that is defined neither there nor in a `mg_*` file it `#include`s, and duplicate definitions across files (all mg files share one namespace) |

Run `tools/deploy.pl` after the lints and the syntax check pass, then test the checklist in
[TESTING.md](TESTING.md) in game.

## Debug tools (`!mg`, needs console `set mg_debug 1`)

| Command | Effect |
|---|---|
| `!mg status` | state, orbs, carrier, timer, anchors resolved |
| `!mg tour` | every step's effects and sounds in their real place, one after the other (teleports you, labels each step): the quick review of the quest's look |
| `!mg lockdown` | the office lockdown (the remaster's effect outlining the door and walls) for 10 s, to check its placement |
| `!mg bridge` | meet the bridge requirement (the gate's own event: setting the vanilla flag would also open the bridge's spawn zone) |
| `!mg goto <locked\|ready\|souls\|pickup\|run\|forge\|done>` | fabricate the state (gives a Blundergat when the state needs one) |
| `!mg spots` | print every anchor (`[SPOT] KEY \| x y z \| p y r`) |
| `!mg help` | full command list |
| `!mg give` | give a plain Blundergat |
| `!mg magma` | swap the Blundergat in hand for its Magmagat (the Sweeper for the Magmus Operandi) |
| `!mg model <xmodel>` | spawn any precached model 80 units in front of you (the mod.ff props: `mg_barrel_green`, `mg_skull`) |
| `!mg shock` | zap every Afterlife shock box and panel of the map at once (doors, generator panels) |
| `!mg shock gun` | toggle the debug shock pistol (zaps the shock box or panel you shoot) |
| `!mg fx [<n>\|<name>\|next\|prev\|stop]` | audition a registered effect where you aim, 8 s (no fx grid in this mod) |
| `!mg snd [<n>\|<alias>\|next\|prev]` | audition a curated sound alias at full volume |
| `!mg grab <KEY>` | live placement mode: the anchor's prop follows your crosshair (FIRE place, MELEE cancel, ADS freeze, 1/2 turn, 3/4 raise, F surface/float, jump reset) |
| `!mg drop` / `!mg cancel` | place the held prop (prints the paste-ready `mg_coord_override(...)` line) / leave the anchor as it was |
| `!mg rot <deg>` / `!mg up <units>` | turn / raise the held prop by chat instead of the buttons |
| `!mg show [KEY]` / `!mg hide` | preview one anchor (or every anchor) in place / remove the preview |
| `!mg tp <KEY>` | teleport to an anchor to judge it in person |

Every `!mg` answer is also printed to the console as a `[MG] ...` line.

## Coordinate workflow

`mg_coords.gsc` ships placeholder anchors near the vanilla free-Blundergat desk and the dock generator. The
owner records the real spots in game with this mod's own live placement mode (`mg_place.gsc`, needs console
`set mg_debug 1`):

```
!mg show               spawn a preview of every anchor (or !mg show KEY for just one), !mg hide removes it
!mg grab <KEY>          the anchor's prop follows your crosshair
                         FIRE place, MELEE cancel, ADS freeze, 1/2 turn, 3/4 raise, F surface/float, jump reset
!mg drop / !mg cancel   place it (prints the paste-ready line below) / leave the anchor as it was
```

A `!mg drop` prints two lines, both to the console:

```
[SPOT] MG_BARREL_1 | -600 9100 1336 | 0 0 0 | mg_barrel_green
mg_coord_override( "MG_BARREL_1", ( -600, 9100, 1336 ), ( 0, 0, 0 ), "mg_barrel_green" );
```

Paste the `mg_coord_override(...)` line into `mg_apply_overrides()` in `mg_coords.gsc` to make it permanent
(the 4th, model, argument is only printed when the anchor carries a prop of its own). An override always wins
over the placeholder default. The anchor keys to fill in are `MG_HEARTH`, `MG_HEARTH_USE`, `MG_SKULL_1..3`,
`MG_BARREL_1..5`, `MG_FORGE`, `MG_FORGE_GUN`.

The cheats script (`cheats_zm.gsc`) and its old `!place` / `!spot` placement flow are not part of this
repository and are never edited here — see "Rules every change must keep" below.

## Rules every change must keep

1. **One mod folder.** Everything the player installs is `mods\zm_magmagat\` (`tools/release.pl`). No edits to any
   file outside this repository except the installs done by `tools/build_mod.pl` and `tools/deploy.pl`. Files
   generated from the games (`mod/props`, `mod/weapon`, `mod/work`, dumps, textures) are never committed.
2. **Never edit another mod's files.** In particular `zm_scavenger.gsc`, `cheats_zm.gsc`, `motd_solo.gsc`,
   `b2op-plutonium.gsc` and `nav_autocomplete.gsc` are off limits; read them for reference only.
3. **Every source starts with the three utility includes**, then `#include scripts\zm\zm_prison\mg_<other>;`
   lines for the mg files it calls.
4. **Every function and level/player field is prefixed `mg_`** (one namespace once packed; a duplicate name
   is a fatal load error).
5. **No builtin that does not exist in T6** (`array_remove`, `toupper`, `stopfxontag`, ...). Grep the
   decompiled vanilla scripts before using anything unfamiliar.
6. **`precachemodel` / `precacheitem` only inside `init()`, before any wait.** Model names must appear in
   `tools/assets/assets_zm_prison.txt` or in our `mod/zone_source/mod.zone`; fx names must appear there and be registered with `loadfx` in
   `mg_fx_init`; sound aliases must exist in `tools/assets/soundbank/*.aliases.csv`.
7. **Console output via `mg_out` / `mg_debug_print`, gated by dvar `mg_debug`**; screen text via
   `iprintln`. `!mg` commands need `set mg_debug 1`.
8. **Run the four lints and the syntax check before every push**, then test in game with
   `developer_script 1` against the checklist in [TESTING.md](TESTING.md).
