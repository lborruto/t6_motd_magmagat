# Magmagat for Mob of the Dead

A new wonder weapon and its quest for Black Ops II Zombies, Mob of the Dead, on Plutonium.

## Install

1. Download `zm_magmagat-<version>.zip` from the latest release and unzip it.
2. Drop the `zm_magmagat` folder into `%localappdata%\Plutonium\storage\t6\mods\`, so you end up with
   `...\t6\mods\zm_magmagat\mod.ff`, `mod.json` and `scripts\`.
3. In game: **Mods** → **zm_magmagat** → load it, then play Mob of the Dead.

That folder is the whole mod: the quest scripts, the Magmagat and the props. Nothing goes into `scripts\zm\`.
Updating from a version before the mod folder? Delete the old `zm_prison_magmagat*.gsc` from
`...\t6\scripts\zm\zm_prison\` first, or the game loads the quest twice and refuses it.

The Mods menu runs one mod at a time; loose scripts in `scripts\zm\` still load beside it.

## Play

The Warden's Office remembers fire. Our advice: discover it. If you are stuck, `docs/GUIDE.md` has the
walkthrough behind spoiler folds.

## Credits

Quest design after Treyarch's Black Ops 4 "Blood of the Dead" and the BO3 Workshop map "MOB OF THE DEAD" by
copforthat (with tupivere_, dobby, Xela, Hybs, Rayjiun, robit, GCP, Booris and Kingslayer Kyle). The Magmagat is
Treyarch's Black Ops 4 model; the blue barrels, the mantle skulls, the lava and the quest's sounds (the flame bursts,
the souls, the press, the warden's lines) come from that map; the gun plays BO2's Blundergat animations. Built with
OpenAssetTools and on the Dead Frequency toolchain. MIT licence (the code).
