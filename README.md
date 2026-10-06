# Magmagat for Mob of the Dead

Port of Black Ops 4's Magmagat to Black Ops II's Mob of the Dead, with the same quest as in copforthat's BO3 remaster of MOTD (released with his permission).

**[⬇ Download the latest release](https://github.com/lborruto/t6_motd_magmagat/releases/latest)** ·
[What's new](CHANGELOG.md) · [Full walkthrough](docs/GUIDE.md)

---

## Install

1. Download `zm_magmagat-<version>.zip` from the
   [latest release](https://github.com/lborruto/t6_motd_magmagat/releases/latest).
2. Unzip it into `%localappdata%\Plutonium\storage\t6\`. Its `mods` folder merges with yours, so you end up with
   `...\t6\mods\zm_magmagat\`.
3. In game: **Mods** → **Magmagat** → load it, then play **Mob of the Dead**.

To check it loaded, the console prints `[MG] Magmagat <version> loaded`.

> The Mods menu runs one mod at a time. Loose scripts you keep in `scripts\zm\` still load beside it.

## How to get the Magmagat

**You need:** a Blundergat, Sweeper, Acid Gat or Vitriolic Withering, and the plane must have flown once (the quest
opens when someone sits in the chair on the Golden Gate Bridge after the first trip).

1. **Open the fireplace.** In the Warden's Office, use the fireplace once (no gun needed).
2. **Place your gun.** With your Blundergat (or any of the four) **in your hands**, hold use on the fireplace. The
   office locks down: nobody can walk through its door until it ends.
3. **Collect 15 souls.** Kill regular zombies **inside the office**: each one drops a soul essence. **Walk over it**
   to collect it; it fades after 20 seconds. If you (the one who placed the gun) go down before the 15th soul, the
   lockdown fails and the gun is lost.
4. **Deposit the essence.** When the lockdown ends, hold use on the fireplace.
5. **Take the Tempered Blundergat.** Hold use again once the fire burns blue: you now carry the tempered gun.
6. **Run to the forge.** You have **15 seconds** before the temper burns out. Five drums burning blue along the way
   (the office exit, the stairs, the Citadel, the tunnels, the docks) each refill it to 15 seconds **once per run**.
   Don't switch to another weapon (reviving a teammate counts as one) and don't go down, or the run fails and you
   start again from step 2.
7. **Use the forge** in the Generator Room by the docks: first **power the Machine** (the temper stops burning out
   there: you then have 60 seconds to place the gun, and a weapon switch or going down still fails the run), then
   **place the Tempered Blundergat** on it.
8. **Take the Magmagat** from the forge within 15 seconds. Taking it calls a **Brutus** (unless one is already out),
   so be ready.

A Sweeper or a Vitriolic Withering comes out as the **Magmus Operandi**. The fireplace then takes a new gun, so the
next player can forge his own. For every detail and edge case, see the [full walkthrough](docs/GUIDE.md).

## The weapon

A lobbed lava blob that sticks to whatever it hits.

| | Magmagat | Magmus Operandi (Pack-a-Punched) |
|---|---|---|
| Clip / start / max ammo | 1 / 30 / 36 | 2 / 25 / 30 |
| Fires every / reloads in | 0.4 s / 2.3 s | 0.4 s / 2.3 s |
| Lava pool pulls in | 3 zombies at a time | 6 zombies at a time, from twice as far |

- **Hit a zombie:** half a second later it blows apart. A tough one (over 1000 health, in later rounds) burns instead,
  slows down and dies 4 seconds later.
- **Burst:** a zombie the Magmagat kills bursts, tearing limbs off the zombies close to it and setting them on fire.
- **Hit Brutus:** he burns; in early rounds one blob kills him in a few seconds.
- **Miss:** the blob leaves a lava pool for 5 seconds (two at most). Zombies walking in catch fire, and it pulls nearby
  zombies into its fire, the next coming as each dies. It burns Brutus hard. Standing in your own pool burns you a
  little; teammates are safe.
- **Burning:** zombies burn for up to 8 seconds, dying fast in early rounds, slower later. Twelve enemies burn at most
  at once; the others only take the first hit.
- **Points:** burns and bursts pay points; the shot and the blob's impact don't.
- **Insta-Kill:** every Magmagat hit kills, and a blob kills on contact, with no burst.
- **Acid Gat kit:** it turns the Magmagat into an Acid Gat, keeping its ammo.
- **Mystery Box:** it won't give you a Blundergat while you hold a Magmagat or while your Blundergat is in the quest.

### Where the rules come from

The Magmagat plays by Black Ops 4's own rules: its damage, timings, the lure, burning, the burst, Brutus, points and
Insta-Kill were checked line by line against Black Ops 4's weapon script, as decompiled by the community (its fire
rate, reload, ammo and sounds, which the script doesn't hold, were read from the game itself):
[`zm_weap_blundergat.gsc`](https://github.com/shiversoftdev/t8-src/blob/main/scripts/zm/weapons/zm_weap_blundergat.gsc)
(shiversoftdev/t8-src). A few details differ where Black Ops II works differently. The quest, by contrast, follows
copforthat's Black Ops III remaster.

## Credits

- **copforthat** and the Mob of the Dead BO3 port team (tupivere_, dobby, Xela, Hybs, Rayjiun, robit, GCP, Booris and
  Kingslayer Kyle): the quest this mod follows and the quest's effects, released with copforthat's permission.
- **Harry**: the Magmagat's blob and muzzle-flash effects, as that map ships them.
- **Treyarch / Activision**: every model, texture and sound. From Black Ops 4: the Magmagat, the Tempered
  Blundergat, the lava blob, the forge with its lever and ghouls, the skulls, the drums' ash and burnt wood, the
  Magmagat's sounds and, as far as we can tell, the quest's sounds. From Black Ops III: the drums, the lava and the effects' textures. From
  Black Ops II: Mob of the Dead itself and the Blundergat animations.
- **Tools**: OpenAssetTools (Laupetin and contributors), Greyhound and HydraX (Scobalula), atian-cod-tools (ate47)
  and Iced (0xd4d).
- **Plutonium**, for keeping Black Ops II alive.

## Assets and takedown

A free, non-commercial fan project, not affiliated with or endorsed by Activision, Treyarch or Plutonium. Call of
Duty and Black Ops are trademarks of Activision. The models, textures and sounds in the mod come from Call of Duty:
Black Ops 4, Black Ops III and Black Ops II and remain the property of Activision / Treyarch; the effects from the
Workshop map "MOB OF THE DEAD" are its team's, used with copforthat's permission. If you hold rights to any asset
and want it removed, [open an issue](https://github.com/lborruto/t6_motd_magmagat/issues) and it will be removed
promptly.

## License

The mod's own code is MIT licensed; the patch in `tools/oat` is GPL-3.0; the game assets in the release belong to
their owners. See [LICENSE](LICENSE). To build it yourself or help out, see [CONTRIBUTING](docs/CONTRIBUTING.md).
