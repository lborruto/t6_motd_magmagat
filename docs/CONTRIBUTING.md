# Contributing to Magmagat (developer documentation)

This file is for people who want to read, build, test or change the mod. Players should read the
[README](../README.md) and, for spoilers, [GUIDE.md](GUIDE.md). The owner's in-game test protocol is
[TESTING.md](TESTING.md).

The sources are the `mg_*.gsc` files in the repository root. The release is a BUILD of them: `tools/pack.pl`
concatenates the sources into one loadable file (or a few, when the sources no longer fit one). Never edit a
packed file; edit a source and pack again.

The version string `!mg status` prints (`level.mg_version` in `mg_main.gsc`) moves whenever the mechanics
change.

## Toolchain facts that bite

- Plutonium T6 loads every `*.gsc` in `scripts\zm\` and `scripts\zm\zm_prison\` (root level only) and all
  loaded scripts share ONE namespace: a function defined twice is a fatal duplicate at load. So the packed
  files and the sources must never sit in the game folder together (`tools/deploy.pl` handles this for you).
- A compiled T6 script addresses every function and import name as a 16-bit offset into its string block, so
  that block cannot pass 65535 bytes. Over it the game reads names from the wrong place and prints nonsense
  `Unresolved external` errors. Today the nine `mg_*.gsc` sources fit into ONE packed file
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
| `mg_coords.gsc` | anchor registry `mg_coord( key )` / `mg_coord_set`, `mg_apply_overrides()` (owner spots pasted here), `mg_models_init` / `mg_model( kind )` / `mg_precache()` |
| `mg_place.gsc` | live placement mode `!mg grab <KEY>` / `drop` / `cancel` / `rot` / `up` (ported from Dead Frequency's `df_place.gsc`), anchor previews `mg_preview_show` / `mg_preview_refresh` / `mg_preview_hide` / `mg_preview_teleport` |
| `mg_quest.gsc` | `level.mg_state`, `mg_state_set( s )`, `mg_state_is( s )`, `level notify( "mg_state", s )`, bridge gate, `mg_goto( state )` fabrication, `mg_status_lines()` |
| `mg_hearth.gsc` | fireplace prompt, souls (orbs, skulls), pickup window |
| `mg_run.gsc` | temper timer, barrels, carrier fail rules |
| `mg_forge.gsc` | forge power, place, ghosts, take; open forge in `done` |
| `mg_weapon.gsc` | Magmagat personality: `mg_weapon_grant( player, weapon )`, shot watcher, lava ball, magma patch, Acid Gat refusal, Pack-a-Punch carry-over |
| `mg_debug.gsc` | shock pistol, `!mg fx` / `!mg snd` audition (ported), `!mg give`, `!mg magma`, `!mg spots` |
| `tools/pack.pl`, `tools/deploy.pl`, `tools/lint_*.pl`, `tools/check_links.pl`, `tools/gsc_header.pl`, `tools/gen_vanilla_map.pl`, `tools/vanilla_namespaces.txt` | build chain, copied from the Dead Frequency mod's tools and re-pointed to this mod's prefix and map |
| `.github/workflows/release.yml` | release when the packed build changes |
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

### tools/deploy.pl (install into the game folder)

```
perl tools/check_links.pl .
perl tools/deploy.pl                # packed: one file if it fits, else two, else three
perl tools/deploy.pl --parts N      # force N packed files
perl tools/deploy.pl --multi        # the sources side by side (development install)
perl tools/deploy.pl --game DIR
```

Game folder: `%localappdata%\Plutonium\storage\t6\scripts\zm\zm_prison\`. Each mode removes what the other
modes installed before, because the two layouts must never coexist. Never hand-edit an installed file.

### The GitHub Action (`.github/workflows/release.yml`)

On every push to `main` / `master` that touches a `mg_*.gsc`, the pack / lint tools, the sound bank tables
or the workflow itself: run `lint_includes`, `lint_calls`, `lint_sounds` and `check_links`, then pack (one
file, else two, else three), then publish a GitHub Release tagged with the version, with every
`release/zm_prison_magmagat*.gsc` attached. A release is only published when the packed build actually
changed from the latest one. A push that only touches docs creates no release. `workflow_dispatch` starts
one by hand.

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
| `!mg goto <locked\|ready\|souls\|pickup\|run\|forge\|done>` | fabricate the state (gives a Blundergat when the state needs one) |
| `!mg spots` | print every anchor (`[SPOT] KEY \| x y z \| p y r`) |
| `!mg help` | full command list |
| `!mg give` | give a plain Blundergat |
| `!mg magma` | grant the Magmagat personality to the Blundergat in hand |
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
[SPOT] MG_BARREL_1 | -600 9100 1336 | 0 0 0 | p6_zm_al_wood_barrel_01
mg_coord_override( "MG_BARREL_1", ( -600, 9100, 1336 ), ( 0, 0, 0 ), "p6_zm_al_wood_barrel_01" );
```

Paste the `mg_coord_override(...)` line into `mg_apply_overrides()` in `mg_coords.gsc` to make it permanent
(the 4th, model, argument is only printed when the anchor carries a prop of its own). An override always wins
over the placeholder default. The anchor keys to fill in are `MG_HEARTH`, `MG_HEARTH_USE`, `MG_SKULL_1..3`,
`MG_BARREL_1..5`, `MG_FORGE`, `MG_FORGE_GUN`.

The cheats script (`cheats_zm.gsc`) and its old `!place` / `!spot` placement flow are not part of this
repository and are never edited here — see "Rules every change must keep" below.

## Rules every change must keep

1. **Loose GSC only.** No fastfile, no edits to any file outside this repository except the game folder
   install done by `tools/deploy.pl`.
2. **Never edit another mod's files.** In particular `zm_scavenger.gsc`, `cheats_zm.gsc`, `motd_solo.gsc`,
   `b2op-plutonium.gsc` and `nav_autocomplete.gsc` are off limits; read them for reference only.
3. **Every source starts with the three utility includes**, then `#include scripts\zm\zm_prison\mg_<other>;`
   lines for the mg files it calls.
4. **Every function and level/player field is prefixed `mg_`** (one namespace once packed; a duplicate name
   is a fatal load error).
5. **No builtin that does not exist in T6** (`array_remove`, `toupper`, `stopfxontag`, ...). Grep the
   decompiled vanilla scripts before using anything unfamiliar.
6. **`precachemodel` only inside `init()`, before any wait.** Model names must appear in
   `tools/assets/assets_zm_prison.txt`; fx names must appear there too and be registered with `loadfx` in
   `mg_fx_init`; sound aliases must exist in `tools/assets/soundbank/*.aliases.csv`.
7. **Console output via `mg_out` / `mg_debug_print`, gated by dvar `mg_debug`**; screen text via
   `iprintln`. `!mg` commands need `set mg_debug 1`.
8. **Run the four lints and the syntax check before every push**, then test in game with
   `developer_script 1` against the checklist in [TESTING.md](TESTING.md).
