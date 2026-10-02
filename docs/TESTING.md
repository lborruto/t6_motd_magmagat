# Magmagat - owner test checklist

Solo (and co-op where noted) in game with `developer_script 1`. Console before loading the map:

```
developer 1
developer_script 1
set mg_debug 1
```

Install first, from the repo (Git Bash): `perl tools/build_mod.pl` (mod.ff, its sound bank mod.all.sabl / .sabs,
and mod.json) and `perl tools/deploy.pl` (the scripts), both into `mods/zm_magmagat`; then Mods -> zm_magmagat in game. Check it loaded: console
`set mg_debug 1`, then in chat `!mg status` (it answers with the version, state, souls, carrier, timer, the gate flag
and every anchor resolved). Every `!mg` answer is also printed to the console as `[MG] ...`.

The `!mg ...` commands below are typed in chat. From the console, put `say` in front: `say !mg goto run`.

Tick each box in game; where a `!mg goto <state>` shortcut exists it is given next to the honest-play check,
but do the honest-play pass too at least once per state - `goto` only fabricates the state, it does not
prove the surrounding checks (prompts, fx, timers) actually fire.

## 0. Load

- [ ] No red error popup on map load.
- [ ] The five route barrels are the remaster's dark-green drums and the three mantle skulls its skulls
      (`!mg show` previews them; `!mg model mg_barrel_green` / `!mg model mg_skull` spawn one in front of you).
- [ ] `!mg status` prints the version, the state (`locked` at boot), souls 0/15, no carrier, the gate flag and the
      forge (closed), and a resolved line for every anchor.
- [ ] `!mg spots` lists `MG_HEARTH`, `MG_HEARTH_USE`, `MG_SKULL_1..3`, `MG_BARREL_1..5`, `MG_FORGE`,
      `MG_FORGE_GUN`; none say "undefined".
- [ ] `!mg help` lists `status`, `goto`, `spots`, `help`, `tour`, `lockdown`, `zone`, `bridge`, `give`, `magma`, `shock`
      (all at once) / `shock gun`, `fx`, `snd`, and the placement commands.

## 0a. The sound bank

- [ ] Console `printsoundalias mg_press`: the alias is known (the mod's `mod.all` bank loaded with `mod.ff`). If it
      is unknown, every `mg_*` sound is silent: report it (the bank then moves to a `mod_load` zone).

## 0b. The look, in one pass

- [ ] `!mg tour`: seven labelled stops. Every effect is visible and every sound heard (the BO3 remaster's own); note
      the step number of anything to change.
      1. The first press at the fireplace: the flame burst, the boards burn.
      2. A placed gun: the laugh, the office outlined in light, the door clip up.
      3. A soul: the essence a kill drops, low over the body; stepped on, it streaks into its skull.
      4. A lit skull (its blue flame).
      5. A drum burning, then its flare.
      6. The forge: the Machine powered, a gun pressed, with the real ram.
      7. A real Magmagat blob lobbed at the floor: it lays its pool, then the burst.

## 1. Locked / ready

- [ ] Before anyone has sat in the bridge chair after the first plane trip: state stays `locked`, no prompt at the
      hearth even with a Blundergat in hand, presses do nothing.
- [ ] Ride the plane and sit in a bridge chair, or `!mg bridge` (the same requirement met, without the plane), or
      `!mg goto ready`: state becomes `ready`. `!mg bridge` in any other state says the fireplace is already open.
- [ ] The first press at the hearth (gun or not, no prompt yet): the flame-burst sound and a fire over the boards for
      about 4 s; a second later "Hold [use] to place Blundergat" shows for every player near the hearth. This happens
      once per game (`!mg goto locked` resets it).
- [ ] No Blundergat, Sweeper, Acid Gat or Vitriolic Withering in your hands (none, or one put away): no prompt, and a
      press does nothing; nothing is taken.
- [ ] Two guns plus `!mg give`: the Blundergat replaces the gun in hand (never a third gun in no slot).

## 2. The souls and the lockdown

- [ ] Hold use with any of `blundergat_zm`, `blundergat_upgraded_zm`, `blundersplat_zm`, `blundersplat_upgraded_zm`
      (in hand or not): the gun leaves you and lies in the fire, with no sound on it; a laugh for all players; the
      laundry defend music; the office outlined in light. State is `souls`, the three skulls are dark.
      (`!mg goto souls` starts the same lockdown with you as the placer.)
- [ ] **Door clip**: players cannot pass the doorway the blue wall frames (north of the fireplace room, x -991 to -884
      at y 9183), from either side; zombies still come through. No gap above or below, nobody stuck. `!mg lockdown` puts
      the outline and clip up for 10 s at any time: the lines must sit on that doorway and along the walls (report any
      floating in the room or outside).
- [ ] **Kill zone**: `!mg zone` marks its sides for 15 s (the remaster's soul catcher volume: x -1070 to -440, y 8493
      to 9187, the fireplace room and the office north of it up to that doorway). They must run along the blue walls.
- [ ] Kill regular zombies in the zone (the killer inside or outside, any weapon): the soul-kill sound at the body, and
      an essence (the remaster's blue lightning soul) waits about 14 units over the body, humming. It does not count yet:
      `!mg status` shows no change. No blood.
- [ ] Step on an essence (within 40 units, any player): the soul-suck and wolf-head soul sounds where you stand, it
      hops and streaks into its skull in about 0.7 s (silent there), and the count goes up when it arrives. An essence
      nobody takes fades after 20 s.
- [ ] Kill more zombies than souls still missing without taking any: no more essences drop than souls still missing
      (15 lying = no new one); once some are taken, kills drop again.
- [ ] Brutus dying in the office, and a zombie dying outside it, give no soul.
- [ ] Skulls light at 5, 10 and 15: the blue flame only, the model unchanged, no sound. No soul counts past 15.
- [ ] 1 s after the 15th soul reaches its skull the laugh plays again; 2 s later the outline and the door clip go, and
      the essences still lying there vanish.
- [ ] **Fail**: the placer goes down (last stand or Afterlife) during the lockdown: the skulls go out at once, no
      sound; the essences lying there vanish; 2 s later the outline and clip go, the gun is lost, the place hint is back,
      state `ready`. Another player going down, or the placer leaving the office for any time, changes nothing.
- [ ] **The BO3 effects** (`!mg tour`): the blue flames (fireplace, drums, skulls, tempered gun), the essences, the
      press fire, the lava blob's trail / impact / burst and the lava pool are the remaster's own. Report any drawn as a
      black or white square, a wrong colour, or invisible.
- [ ] Co-op: any player's kills in the office drop essences and any player can take them; the souls state is shared.

## 3. The deposit and the pickup

- [ ] At 15 souls, only the placer sees "Hold [use] to deposit the essence" at the hearth; another player sees no prompt and his press does nothing. There is no time limit. (`!mg goto pickup`
      fabricates this with you as the placer.)
- [ ] Deposit: three souls streak from you into the gun in the fire (about 0.75 s), then the flame-burst sound, a flare
      and the fire burns blue. The skulls stay lit.
- [ ] The fire stays blue while nobody takes the gun (wait a minute), and the hint is now "Hold [use] to take the
      Tempered Blundergat", for the placer only.
- [ ] The take is refused while drinking a perk or holding a grenade, claymore or revive tool. With two primaries the
      weapon in hand is replaced.
- [ ] Take it: state moves to `run`, you are the carrier, the skulls stay lit, the blue fire goes out.
- [ ] The placer disconnecting before the take (before or after the deposit): the gun is lost, the blue fire goes out,
      state back to `ready`.

## 4. The run

- [ ] `!mg goto run` (or take the tempered gun honestly): state is `run`, a flame rides the gun and the five barrels
      burn (no timer on screen: the flame is the only indicator; `!mg status` prints the seconds left).
- [ ] In your hands the tempered gun is BO4's tempered Blundergat (a Sweeper gives the tempered Sweeper with its
      armour): its canisters glow blue; others see a blue flame on it.
- [ ] Fire it: its muzzle flash burns blue (`mg/fx_mg_tempered_flash`, the Magmagat's flash recoloured), in first
      person and as seen by another player.
- [ ] The five drums (the remaster's dark-green drums) burn blue from inside, the flames rising out of the rim.
- [ ] Each drum is solid: you cannot walk through it nor jump onto it (its clip stands 128 units high from its foot).
- [ ] Stand at a lit drum's foot (within 64 units, feet 0-64 above its base): the temper is back to 15 s, with a 5 s
      flare and the flame-burst sound. No whoosh, no rumble; the drum keeps burning. A second visit to the same drum
      gives nothing. Standing on top of a drum does not count.
- [ ] After a refill the run fails 15-16 s later.
- [ ] Firing the tempered gun does NOT end the run.
- [ ] Switching to another weapon (a perk drink, a box weapon) ends the run within about 0.1 s. Switching to a
      Blundergat, Sweeper, Acid Gat or Vitriolic Withering does not. The run does not fail at the pickup while the
      tempered gun is being raised (try with one and with two primaries).
- [ ] **Failure paths**: the timer runs out (do nothing for 15 s), you switch weapon, you go down. Each: silent, the flame
      and the barrels go out, you get your Blundergat back, the skulls go dark; 5 s later the state is `ready` and the
      fireplace takes a gun again.

## 5. The forge

- [ ] With the tempered gun at the forge, "Hold [use] to power the Machine" shows for the carrier only. Using it plays
      the power-panel sound and the sparks on the Machine; the run goes on (the timer still counts) and the gun stays in
      your hands. A second later the Warden's line plays to that player only. (`!mg goto forge` fabricates a Magmagat
      waiting for you.)
- [ ] Then "Hold [use] to place the Tempered Blundergat", for the carrier only: nobody else, and no plain Blundergat,
      gets a prompt, and only while it is in his hands. Letting the temper run out before placing it fails the run as
      anywhere else.
- [ ] The Machine has collision: you cannot walk through it.
- [ ] Place it: the run ends, the skulls go out and the fireplace takes a Blundergat again. The gun lies on the bed
      with a blue flare and a flame burst; the ram comes down at about 0.8-1.1 s and strikes in sparks with a slam, the
      press sound starts at 0.55 s and a fire loop roars until the end (all from the Machine), the press fire plays at
      about 1.35 s with a flame burst and the gun disappears. At about 4.35 s the Magmagat lies on the bed in a burst of
      flame, with the "build complete" chime, and the ram lifts.
- [ ] At about 5.65 s "Hold [use] to take the Magmagat" shows, for the placer only.
- [ ] Taking it: a Brutus spawns in the Generator Room about 1 s later.
- [ ] Every forge hint (power the Machine, place the Tempered Blundergat, take the Magmagat) and every fireplace hint shows the
      use key in yellow and the rest in white (`^3` / `^7`), like vanilla's.
- [ ] Take it: the weapon is `magmagat_zm` ("Magmagat" on the HUD). A Pack-a-Punched gun (Sweeper, Vitriolic
      Withering) gives `magmagat_upgraded_zm` (Magmus Operandi).
- [ ] **Failure path**: leave it 15 s: it disappears with no effect and no sound, and the forge offers placement again.
- [ ] Only the placer can take it; another player sees no prompt and his press does nothing.
- [ ] Place a second gun while you already own a Magmagat: taking it only refills the ammo of the one you own; a
      Pack-a-Punched gun pressed while you own a plain Magmagat makes it the Magmus Operandi (never the reverse).
- [ ] `!mg goto ready` in the middle of a press: the ram returns to rest and the entities are cleaned up.

## 6. The weapon (Magmagat / Magmus Operandi)

- [ ] Fire it: one orange blob (a little smaller than BO4's) flies with a trail and a small fire riding it, the
      remaster's fire-coloured muzzle flash (the Magmus: Harry's _ug one), no tracer streak, no bullet impact and no green
      acid splash where it lands. The clip holds one (the Magmus two). Both fire with the plain Blundergat's shot, as
      the remaster's own t8_magmagat_zm does.
- [ ] **Hit a zombie** (BO4's): 0.5 s later a zombie of 1000 health or less bursts in gore and dies; a tougher one
      burns, walks, and dies 4 s later. When it dies the blob bursts in flame with the Acid Gat's explosion sound (no
      green smoke): the zombies within 128 units catch fire, take 400 and burn to death, falling dead (no gore). No
      player is hurt. Other zombies are not drawn to a blob on a zombie.
- [ ] **Hit Brutus**: 100, then he burns 5 s (torso flames), then the blob is gone with no burst; zombies are not lured.
- [ ] **Hit the floor, a wall or a ceiling**: the blob stays where it landed, standing out of that surface, its fire
      turned the same way, for 5 s, then vanishes (no explosion). Near the floor it draws 3 zombies (the Magmus 6);
      high up a wall it draws none. A zombie touching its fire (64 units, 32 high) catches fire and burns to death
      (in early rounds within about 2 s); Brutus loses a tenth of his health once. Only its owner is hurt touching it:
      1 every 0.4 s.
- [ ] A burning zombie: the flames and the loop sound stay on it until it dies or for 12 s.
- [ ] Spam 5 or more pools: never more than 3 at once (the oldest goes).
- [ ] **Points**: hits and pool ticks give no +10; kills give the normal kill points.
- [ ] **Spoon**: stuck-blob kills in the showers count.
- [ ] Ammo: Magmagat 1 in the clip, 30 to start, 36 at most; Magmus 2 / 25 / 30.
- [ ] **Look**: in first person the Magmagat is the BO4 model (its own receiver, stock and chains, molten canisters and
      barrels that glow and flicker) and every Blundergat animation plays on it without parts drifting (raise, reload,
      the hammer, the swivel, the loader, the left chains, sprint); on the forge and in other players' hands it is the
      same model. No flame rides the held gun.
- [ ] **Pack-a-Punch**: a Magmagat comes back as `magmagat_upgraded_zm`, Magmus Operandi: the BO4 model with its
      armour kit, a 2-blob clip, the bigger pool and lure.
- [ ] **Acid Gat kit takes a Magmagat**: holding only a Magmagat, use the Acid Gat station: it goes in as a
      Blundergat and the Acid Gat comes out (a Magmus Operandi gives the Vitriolic Withering).
- [ ] A plain Blundergat still upgrades at the Acid Gat station normally. With a Magmagat and an Acid Gat already,
      the station keeps your Magmagat (no conversion).
- [ ] **Back and forth**: Magmagat -> Acid Gat kit -> Acid Gat -> fireplace -> Magmagat again; the same with a
      Magmus Operandi -> Vitriolic Withering -> Magmus Operandi. No step gives back a lower tier.
- [ ] With a Magmagat in hand, a Brutus-locked craftable table still charges its unlock price and unlocks;
      other craftables (shield, plane parts) still craft normally.
- [ ] Losing the Magmagat (box swap, wall buy replacing it, death without Tombstone) loses it like any weapon;
      the open forge converts a fresh gun again.
- [ ] The Mystery Box never offers a Magmagat.
- [ ] Watch the console for "missing fx key" and script errors, especially from the Acid Gat stun animation and
      `resetmissiledetonationtime`.

## 7. Debug tools

- [ ] `!mg give` gives and switches to a plain Blundergat.
- [ ] `!mg magma` swaps the Blundergat in hand for its Magmagat (a Sweeper for the Magmus Operandi; refuses
      with a message if you are not holding one).
- [ ] `!mg fx <n>` / `!mg fx <name>` / `!mg fx next` / `!mg fx prev` / `!mg fx stop` auditions a registered
      effect where you aim for 8 s, and the console prints the index/name. Confirm there is no fx grid (not
      part of this mod).
- [ ] `!mg snd <n>` / `!mg snd <alias>` / `!mg snd next` / `!mg snd prev` plays a curated sound alias to you
      at full volume and prints its name; silence on a name means the alias is in no bank.
- [ ] **Shock zap**: `!mg shock` zaps every shock box and panel at once (doors open, generator panels light). **Shock pistol**: `!mg shock gun` toggles on, fire the shock weapon (`m1911_zm` by default)
      at an Afterlife shock box - it should zap as if hit by the real Afterlife interaction.
- [ ] **Shock pistol on a power panel**: same toggle, aim at an Afterlife power panel instead - it should
      zap that too. Toggle `!mg shock gun` off afterward and confirm shots no longer zap anything.
- [ ] `!mg goto locked|ready|souls|pickup|run|forge|done` puts the stations in the matching state (`souls` starts a real
      lockdown with you as the placer; `pickup`, `run`, `forge` light the skulls).

## 8. Co-op

- [ ] Start a co-op test with the test client `motd_solo.gsc` spawns (or a real second player). Confirm the
      quest state is shared: both players see the same essences, the same souls count and the same lit
      barrels during `run`, and only one player at a time can be the temper carrier.
- [ ] Either player's kills in the office count. Only the placer can take the tempered gun, and only the placer can
      take the Magmagat from the forge.
- [ ] After a Magmagat, another player can temper his own: the fireplace takes a Blundergat again, and the powered
      Machine takes only his Tempered Blundergat (no plain Blundergat).

## 9. Lints and syntax (before every deploy)

- [ ] `perl tools/lint_includes.pl && perl tools/lint_calls.pl && perl tools/lint_sounds.pl && perl tools/check_links.pl .`
      all green.
- [ ] `"C:/Games/t6/gsc-tools/gsc-tool.exe" -m comp -g t6 -s pc -y <file>` prints `compiled t6/<file>` for
      every changed source.
- [ ] `perl tools/build_mod.pl` and `perl tools/deploy.pl` install without error.
