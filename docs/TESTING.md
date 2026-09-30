# Magmagat - owner test checklist

Solo (and co-op where noted) in game with `developer_script 1`. Console before loading the map:

```
developer 1
developer_script 1
set mg_debug 1
```

Install first, from the repo (Git Bash): `perl tools/build_mod.pl` (mod.ff + mod.json) and `perl tools/deploy.pl`
(the scripts), both into `mods/zm_magmagat`; then Mods -> zm_magmagat in game. Check it loaded: console
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
- [ ] `!mg help` lists `status`, `goto`, `spots`, `help`, `tour`, `bridge`, `give`, `magma`, `shock` (all at once) /
      `shock gun`, `fx`, `snd`.

## 0a. The sound bank

- [ ] Console `printsoundalias mg_press`: the alias is known (the mod's `mod.all` bank loaded with `mod.ff`). If it
      is unknown, every `mg_*` sound is silent: report it (the bank then moves to a `mod_load` zone).

## 0b. The look, in one pass

- [ ] `!mg tour`: seven labelled stops. Every effect is visible and every sound heard (the BO3 remaster's own); note
      the step number of anything to change.
      1. The first press at the fireplace: the flame burst, the boards burn.
      2. A placed gun: the laugh, the office outlined in light, the door clip up.
      3. A soul rising over a body.
      4. A lit skull (its blue flame).
      5. A drum burning, then its flare.
      6. The forge: the Machine powered, a gun pressed, with the real ram.
      7. A real Magmagat bolt fired at the floor: it lays its pool, then the burst.

## 1. Locked / ready

- [ ] Before anyone has sat in the bridge chair after the first plane trip: state stays `locked`, no prompt at the
      hearth even with a Blundergat in hand, presses do nothing.
- [ ] Ride the plane and sit in a bridge chair, or `!mg bridge` (the same requirement met, without the plane), or
      `!mg goto ready`: state becomes `ready`. `!mg bridge` in any other state says the fireplace is already open.
- [ ] The first press at the hearth (gun or not, no prompt yet): the flame-burst sound and a fire over the boards for
      about 4 s; a second later "Hold [use] to place Blundergat" shows for every player near the hearth. This happens
      once per game (`!mg goto locked` resets it).
- [ ] Press without a Blundergat, Sweeper, Acid Gat or Vitriolic Withering: "Missing Blundergat" for 2 s, then the
      place hint again.

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
      the soul (the remaster's blue lightning streak) rises 60 units in 2 s, humming. `!mg status` shows the count go up
      0.5 s after each kill, with nothing to pick up. No blood.
- [ ] Brutus dying in the office, and a zombie dying outside it, give no soul.
- [ ] Skulls light at 5, 10 and 15: the blue flame only, the model unchanged, no sound. No soul counts past 15.
- [ ] 1 s after the 15th soul the laugh plays again; 2 s later the outline and the door clip go.
- [ ] **Fail**: the placer goes down (last stand or Afterlife) during the lockdown: the skulls go out at once, no
      sound; 2 s later the outline and clip go, the gun is lost, the place hint is back, state `ready`. Another player
      going down, or the placer leaving the office for any time, changes nothing.
- [ ] **The BO3 effects** (`!mg tour`): the blue flames (fireplace, drums, skulls, tempered gun), the souls, the
      press fire, the lava blob's trail / impact / burst and the lava pool are the remaster's own. Report any drawn as a
      black or white square, a wrong colour, or invisible.
- [ ] Co-op: any player's kills in the office count; the souls state is shared.

## 3. The pickup

- [ ] At 15 souls, only the placer sees "Hold [use] to take the Tempered Blundergat" at the hearth; another player's
      press does nothing. There is no time limit. (`!mg goto pickup` fabricates this with you as the placer.)
- [ ] The take is refused while drinking a perk or holding a grenade, claymore or revive tool. With two primaries the
      weapon in hand is replaced.
- [ ] Take it: state moves to `run`, you are the carrier, the skulls stay lit.
- [ ] The placer disconnecting before the take: the gun is lost, state back to `ready`.

## 4. The run

- [ ] `!mg goto run` (or take the tempered gun honestly): state is `run`, a flame rides the gun and the five barrels
      burn (no timer on screen: the flame is the only indicator; `!mg status` prints the seconds left).
- [ ] In your hands the tempered gun is BO4's tempered Blundergat (a Sweeper gives the tempered Sweeper with its
      armour): its canisters glow blue; others see a blue flame on it.
- [ ] The five drums (the remaster's dark-green drums) burn blue from inside, the flames rising out of the rim.
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

- [ ] With the tempered gun at the forge, "Hold [use] to power the Machine" shows for the carrier. Using it plays the
      power-panel sound and sparks on the Machine, gives your Blundergat back and ends the run in success (state
      `done`). A second later the Warden's line plays to that player only, and everyone near sees "Hold [use] to
      place the Blundergat". (`!mg goto done` opens the forge; `!mg goto forge` opens it with a Magmagat waiting for you.)
- [ ] The skulls stay lit for the rest of the game; the fireplace shows no prompt any more.
- [ ] Use the open forge without a Blundergat: "Missing Blundergat" for 2 s.
- [ ] Place a gun: the gun lies on the bed, the ram comes down at about 0.8-1.1 s, the press sound starts at 0.55 s, the
      press fire plays once at about 1.35 s and the gun disappears. At about 4.35 s the Magmagat lies still on the bed
      and the ram lifts. No smoke, no Brutus, no extra sounds or effects at the press.
- [ ] At about 5.65 s "Hold [use] to take the Magmagat" shows, for the placer only.
- [ ] Take it: the weapon is `magmagat_zm` ("Magmagat" on the HUD). A Pack-a-Punched gun (Sweeper, Vitriolic
      Withering) gives `magmagat_upgraded_zm` (Magmus Operandi).
- [ ] **Failure path**: leave it 15 s: it disappears with no effect and no sound, and the forge offers placement again.
- [ ] Only the placer can take it; another player sees no prompt and his press does nothing.
- [ ] Place a second gun while you already own a Magmagat: taking it only refills the ammo of the one you own.
- [ ] `!mg goto ready` in the middle of a press: the ram returns to rest and the entities are cleaned up.

## 6. The weapon (Magmagat / Magmus Operandi)

- [ ] Fire it: one orange blob flies with a trail, the remaster's fire-coloured muzzle flash (not the Acid Gat's green), no tracer streak, no bullet impact. The
      clip holds one (the Magmus two).
- [ ] **Hit a zombie**: the blob sticks, the zombie plays the Acid Gat stun and burns (torso fire and loop sound), and dies
      after about 1 s at any round; the blob bursts about 0.05 s later (explosion effect and sound). Zombies within
      about 300 units take heavy damage, and so do players near it (the Acid Gat dart's explosion, as the remaster's;
      its sound is the Acid Gat's, the only one the remaster ships). Other zombies gather on the blob during that second.
- [ ] **Hit Brutus**: one hit of about 250-375; the blob stays on him and bursts 3 s later; zombies are lured to it.
- [ ] **Hit the floor, a wall or a ceiling**: the blob stays where it landed, standing out of that surface, its fire
      turned the same way, for 6 s, then vanishes (no
      explosion). Zombies stepping in burn and die in about 0.75 s. Brutus walks through unharmed. Any player standing
      in it (you too) loses 20 health every 0.5 s with a sizzle loop. The Magmus pool is visibly wider (64).
- [ ] A zombie leaving a pool: the sound stops, the flames stay about 4 s, then go.
- [ ] Spam 10 or more pools: never more than 8 at once, no entity overflow.
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
- [ ] A plain Blundergat still upgrades at the Acid Gat station normally.
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
      quest state is shared: both players see the same hearth hint, the same souls count and the same lit
      barrels during `run`, and only one player at a time can be the temper carrier.
- [ ] Either player's kills in the office count. Only the placer can take the tempered gun, and only the placer can
      take the Magmagat from the forge.
- [ ] In `done`, either player can convert his own Blundergat at the open forge independently.

## 9. Lints and syntax (before every deploy)

- [ ] `perl tools/lint_includes.pl && perl tools/lint_calls.pl && perl tools/lint_sounds.pl && perl tools/check_links.pl .`
      all green.
- [ ] `"C:/Games/t6/gsc-tools/gsc-tool.exe" -m comp -g t6 -s pc -y <file>` prints `compiled t6/<file>` for
      every changed source.
- [ ] `perl tools/build_mod.pl` and `perl tools/deploy.pl` install without error.
