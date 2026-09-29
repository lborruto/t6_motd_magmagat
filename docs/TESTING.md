# Magmagat - owner test checklist

Solo (and co-op where noted) in game with `developer_script 1`. Console before loading the map:

```
developer 1
developer_script 1
set mg_debug 1
```

Install first, from the repo (Git Bash): `perl tools/build_mod.pl` (mod.ff + mod.json) and `perl tools/deploy.pl`
(the scripts), both into `mods/zm_magmagat`; then Mods -> zm_magmagat in game. Check it loaded: console
`set mg_debug 1`, then in chat `!mg status` (it answers with the version, state, orbs, carrier, timer and every anchor
resolved). Every `!mg` answer is also printed to the console as `[MG] ...`.

Tick each box in game; where a `!mg goto <state>` shortcut exists it is given next to the honest-play check,
but do the honest-play pass too at least once per state - `goto` only fabricates the state, it does not
prove the surrounding checks (prompts, fx, timers) actually fire.

## 0. Load

- [ ] No red error popup on map load.
- [ ] The five route barrels are the remaster's dark-green drums and the three mantle skulls its skulls
      (`!mg show` previews them; `!mg model mg_barrel_green` / `!mg model mg_skull` spawn one in front of you).
- [ ] `!mg status` prints the version, the state (`locked` at boot), orbs 0, no carrier, no timer, and a
      resolved line for every anchor.
- [ ] `!mg spots` lists `MG_HEARTH`, `MG_HEARTH_USE`, `MG_SKULL_1..3`, `MG_BARREL_1..5`, `MG_FORGE`,
      `MG_FORGE_GUN`; none say "undefined".
- [ ] `!mg help` lists `status`, `goto`, `spots`, `help`, `give`, `magma`, `shock` (all at once) / `shock gun`, `fx`, `snd`.

## 0a. The sound bank

- [ ] Console `printsoundalias mg_press`: the alias is known (the mod's `mod.all` bank loaded with `mod.ff`). If it
      is unknown, every `mg_*` sound is silent: report it (the bank then moves to a `mod_load` zone).

## 0b. The look, in one pass

- [ ] `!mg tour`: eight labelled stops (the fireplace, a soul orb rising, taken and flying to its skull, a full skull,
      the blue fire and the rising gun, a burning drum, the forge, the lava blob, the molten pool). Every
      effect is visible and every sound heard (the BO3 remaster's own: the flame burst when the gun goes in, the soul
      kill and its hum, the press at the forge, the warden's line at the end); note the step number of anything to change.

## 1. Locked / ready

- [ ] Before anyone reaches the Golden Gate Bridge (the plane's landing): state stays `locked`, no prompt at the hearth even with a Blundergat in
      hand.
- [ ] While `locked`, five broken boards cross the fireplace (`!mg goto locked` puts them back).
- [ ] Reach the bridge, or `!mg bridge` (the same requirement met, without the plane), or `!mg goto ready`: state
      becomes `ready` and the boards burn away (the remaster's burn effect, a flame burst). `!mg bridge` in any other
      state says the fireplace is already open.
- [ ] Holding a Blundergat, a Sweeper, an Acid Gat or a Vitriolic Withering (`blundergat_zm`, `blundergat_upgraded_zm`,
      `blundersplat_zm`, `blundersplat_upgraded_zm`), pressing use at the hearth lays the gun in the fire (no on-screen
      prompt, as the original) and a laugh plays. Holding none of them: nothing.

## 2. The souls

- [ ] `!mg goto souls` (or press use at the hearth with a gun in `ready`): the gun leaves your hands into the fire,
      the three skulls are dark, state is `souls`.
- [ ] A zombie a player kills that dies inside the Warden's Office: a blue burst and the soul-kill sound at the body,
      then a humming blue orb rises over it for 3 s. Walk into it: a flash and the soul-suck sound, and the soul (a
      blue lightning streak) flies to its skull and flashes in; the count increases (`!mg status`: x/15). No blood.
- [ ] An orb nobody takes fades after 3 s and does not count; later kills still reach 15.
- [ ] **Lockdown**: while the office takes souls, the remaster's lockdown outlines the office's door and walls in
      light; it goes at 15 souls or when the step ends. `!mg lockdown` shows it for 10 s at any time: the lines must
      sit on the door frame and along the walls (report any floating in the room or outside it).
- [ ] **The BO3 effects** (`!mg tour`): the blue flames (fireplace, drums, skulls, tempered gun), the souls, the
      press fire, Harry's lava blob trail / impact / burst, the lava pool and its scorch are the remaster's own. Report
      any drawn as a black or white square, a wrong colour, or invisible.
- [ ] The killer may stand outside (a shot through the window at a zombie inside counts); a zombie that dies
      outside the office never gives a soul.
- [ ] Skulls light at 5, 10 and 15 (the skull becomes the afterlife skull, a blue glow and a hum; the third has its
      own sound). No soul is released past 15.
- [ ] **Placer away 10 s**: with souls taken, the player who placed the gun leaves the office for 10 s: the souls
      are lost (skulls dark, count 0), a fail sound; the quest goes on.
- [ ] **Placer away 30 s**: 30 s out of the office: the gun is lost, a fail sound and the laugh, state `ready`.
- [ ] **Placer dies** (or leaves the game): the gun is lost the same way.
- [ ] Co-op: any player's kills in the office and pickups count; the souls state is shared.

## 3. The deposit and the pickup

- [ ] At 15 souls, press use at the hearth: the skulls go dark one by one (0.5 s apart, a soul drains from each into
      the fire), a flare-up, and a second later the fire burns blue and the tempered gun rises (BO4's, its canisters blue),
      state `pickup`. (`!mg goto pickup` fabricates this directly.)
- [ ] Take the gun within 30 s: state moves to `run`, you are now the carrier.
- [ ] **Failure path**: let the 30 s expire: the gun vanishes (fail sound, laugh) and is lost. State `ready`.

## 4. The run

- [ ] `!mg goto run` (or take the tempered gun honestly): state is `run`, a flame rides the gun and the five barrels
      burn (no timer on screen: the flame is the only indicator; `!mg status` prints the seconds left).
- [ ] In your hands the tempered gun is BO4's tempered Blundergat (a Sweeper gives the tempered Sweeper with its
      armour): its canisters glow blue and flicker in first person; others see a blue flame on it.
- [ ] The five drums (the remaster's dark-green drums) burn blue from inside, the flames rising out of the rim.
- [ ] Walking up to a burning drum (64 units) refills the temper to 25 s: a flare, a whoosh, a rumble, and that
      drum goes out for the rest of the run. A spent drum does nothing.
- [ ] Firing the tempered gun once ends the run (the essence is spent), state `ready`.
- [ ] In the last 5 s the flame flickers every half second with a rumble and a tick.
- [ ] **Failure paths**: the temper runs out; you switch away from the gun (a quarter second is forgiven); you go
      down. Each: the flame dies, the tempered gun turns back into the gun you placed, state `ready` (temper again at
      the fireplace). Going down: it turns back once you are up.

## 5. The forge

- [ ] `!mg goto forge` (or carry the tempered gun to the powered generator honestly): state is `forge`.
- [ ] At the generator: press once to power it (the generator's sparks and the power-panel sound), then place the
      tempered gun: the press sound for 5 s over fire and the generator's smoke, two flame bursts.
- [ ] After the ghosts: a burst, then the Magmagat rises out of a flame, turning once, and glows.
- [ ] Take it within 30 s: state `done`, the weapon is `magmagat_zm` ("Magmagat" on the HUD). A Pack-a-Punched gun
      (Sweeper, Vitriolic Withering) gives `magmagat_upgraded_zm` (Magmus Operandi).
- [ ] The first forge: a laugh, and a Brutus spawns.
- [ ] **Failure path**: do not take the Magmagat for 30 s: it vanishes (fail sound, laugh), state `ready`.
- [ ] **Forge stays open once done**: place any of the four guns on the generator: it converts at once. The
      fireplace takes no gun any more.

## 6. The weapon (Magmagat / Magmus Operandi)

- [ ] Fire at a zombie: a lava blob (a lumpy molten ball with a fire trail) tumbles to it, sticks half a second,
      then the zombie dies (kill credit and points to you); zombies within 128 units take 400 and catch fire.
- [ ] **No buckshot**: the shot itself does no damage (fire at a zombie behind a wall or at a Brutus helmet: nothing
      but the blob hurts). Ammo is BO4's: Magmagat 1 in the clip, 30 to start, 36 at most; Magmus 2 / 25 / 30.
- [ ] **The burn**: a zombie set alight burns until it dies, a share of its health each second that shrinks with
      the round (most of it before round 9, a fifth or less from round 29). At most 12 burn with flames showing.
- [ ] A strong zombie (high rounds, more than 1000 health) takes 1000, burns 4 s, then dies.
- [ ] **Crawlers catch the blob too** (it links at `J_SpineUpper`), and a crawler that enters a pool dies at once.
- [ ] A miss leaves a molten pool under the impact (a glowing splat with fire; a wall hit pools below it) for 5 s;
      a fourth pool removes the oldest. Zombies nearby walk to it (the lure), catch fire stepping in (10 % of their
      health, then the burn).
- [ ] Standing in your own pool hurts you a little.
- [ ] **Brutus**: a blob on Brutus burns him for 5 s (10-20 % of his health a second, half from round 15): enough
      to kill him. He walks through pools unharmed (as in BO4).
- [ ] **Look**: in first person the Magmagat is the BO4 model (its own receiver, stock and chains, molten canisters and
      barrels that glow and flicker) and every Blundergat animation plays on it without parts drifting (raise, reload,
      the hammer, the swivel, the loader, the left chains, sprint); on the generator and in other players' hands it
      is the same model.
- [ ] **Held flame**: a small flame rides the gun while it is in hand (bigger on the Magmus Operandi). It goes out
      when you switch weapon, go down or lose the gun, and comes back when you raise it again. Co-op: the other
      player sees it on your gun.
- [ ] **Shot**: an orange flash (bigger on the Magmus Operandi), one red streak and a fire whoosh with every shot, on
      top of the Blundergat's own sound; every shot throws a blob.
- [ ] **Pack-a-Punch**: a Magmagat comes back as `magmagat_upgraded_zm`, Magmus Operandi: the BO4 model with its
      armour kit, a 2-blob clip, the bigger pool lure.
- [ ] **Acid Gat kit takes a Magmagat**: holding only a Magmagat, use the Acid Gat station: it goes in as a
      Blundergat and the Acid Gat comes out (a Magmus Operandi gives the Vitriolic Withering).
- [ ] A plain Blundergat still upgrades at the Acid Gat station normally.
- [ ] With a Magmagat in hand, a Brutus-locked craftable table still charges its unlock price and unlocks;
      other craftables (shield, plane parts) still craft normally.
- [ ] Losing the Magmagat (box swap, wall buy replacing it, death without Tombstone) loses it like any weapon;
      the open forge converts a fresh gun again.
- [ ] The Mystery Box never offers a Magmagat.

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

## 8. Co-op

- [ ] Start a co-op test with the test client `motd_solo.gsc` spawns (or a real second player). Confirm the
      quest state is shared: both players see the same hearth prompt, the same souls count, the same lit
      barrels during `run`, and only one player at a time can be the temper carrier.
- [ ] Either player may collect orbs and press the hearth.
- [ ] In `done`, either player can convert his own Blundergat at the open forge independently.

## 9. Lints and syntax (before every deploy)

- [ ] `perl tools/lint_includes.pl && perl tools/lint_calls.pl && perl tools/lint_sounds.pl && perl tools/check_links.pl .`
      all green.
- [ ] `"C:/Games/t6/gsc-tools/gsc-tool.exe" -m comp -g t6 -s pc -y <file>` prints `compiled t6/<file>` for
      every changed source.
- [ ] `perl tools/build_mod.pl` and `perl tools/deploy.pl` install without error.
