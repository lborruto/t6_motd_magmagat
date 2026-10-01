# Magmagat for Mob of the Dead

A new wonder weapon and its quest for Black Ops II Zombies, Mob of the Dead, on Plutonium.

## Install

1. Download `zm_magmagat-<version>.zip` from the latest release and unzip it.
2. Drop the `zm_magmagat` folder into `%localappdata%\Plutonium\storage\t6\mods\`, so you end up with
   `...\t6\mods\zm_magmagat\mod.ff`, `mod.all.sabl` and `mod.all.sabs` (the sound bank), `mod.json` and `scripts\`.
3. In game: **Mods** → **zm_magmagat** → load it, then play Mob of the Dead.

That folder is the whole mod: the quest scripts, the Magmagat, the props, the effects and the sounds. Nothing goes
into `scripts\zm\`.

The Mods menu runs one mod at a time; loose scripts in `scripts\zm\` still load beside it.

What each release brings is in [CHANGELOG.md](CHANGELOG.md).

## Play

The Warden's Office remembers fire. Our advice: discover it. If you are stuck, `docs/GUIDE.md` has the
walkthrough behind spoiler folds.

## Credits

- The quest follows the BO3 Workshop map "MOB OF THE DEAD" by copforthat (with tupivere_, dobby, Xela, Hybs, Rayjiun,
  robit, GCP, Booris and Kingslayer Kyle). The dark-green drums, the mantle skulls, the lava, the quest's effects (the
  blue flames, the souls, the lockdown, the press fire, the lava pool) and its sounds (the flame bursts, the souls,
  the press, the warden's lines) come from that map.
- Harry's effects, as that map ships them (`harry/magmagat` and `harry/blundersplat`): the lava blob's trail, impact
  and burst, and the Magmagat's and the tempered gun's muzzle flashes.
- Treyarch: the Black Ops 4 models of the Magmagat, the Tempered Blundergat, the lava blob (`p8_fxp_magma_blob`) and
  the press (`p8_zm_esc_machinery_01`); Black Ops II's Mob of the Dead, whose Blundergat animations the gun plays.
- Tools: OpenAssetTools (Laupetin and contributors) builds the fastfile; Greyhound and HydraX (Scobalula) for the
  extraction from BO3; built on the Dead Frequency toolchain.

The mod's own code is MIT licensed; the patch in `tools/oat` is GPL-3.0, and the game assets in the release belong to
their owners. See [LICENSE](LICENSE).
