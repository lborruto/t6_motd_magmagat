# Magmagat - owner test checklist

Solo (and co-op where noted) in game with `developer_script 1`. Console before loading the map:

```
developer 1
developer_script 1
set mg_debug 1
```

Install first: `perl tools/deploy.pl` from the repo (Git Bash). Check it loaded: console `set mg_debug 1`,
then in chat `!mg status` (it answers with the version, state, orbs, carrier, timer and every anchor
resolved). Every `!mg` answer is also printed to the console as `[MG] ...`.

Tick each box in game; where a `!mg goto <state>` shortcut exists it is given next to the honest-play check,
but do the honest-play pass too at least once per state - `goto` only fabricates the state, it does not
prove the surrounding checks (prompts, fx, timers) actually fire.

## 0. Load

- [ ] No red error popup on map load.
- [ ] `!mg status` prints the version, the state (`locked` at boot), orbs 0, no carrier, no timer, and a
      resolved line for every anchor.
- [ ] `!mg spots` lists `MG_HEARTH`, `MG_HEARTH_USE`, `MG_SKULL_1..3`, `MG_BARREL_1..5`, `MG_FORGE`,
      `MG_FORGE_GUN`; none say "undefined".
- [ ] `!mg help` lists `status`, `goto`, `spots`, `help`, `give`, `magma`, `shock`, `fx`, `snd`.

## 1. Locked / ready

- [ ] Before the bridge is raised: state stays `locked`, no prompt at the hearth even with a Blundergat in
      hand.
- [ ] Raise the bridge (or `!mg goto ready`): state becomes `ready`. Holding `blundergat_zm` or
      `blundergat_upgraded_zm`, a prompt appears at the hearth ("Temper the Blundergat"). Holding neither: no
      prompt.
      goto souls` also removes them.

## 2. The souls

- [ ] `!mg goto souls` (or press use at the hearth with a Blundergat in `ready`): the gun leaves your hands
      into the fire, the flame grows, the three skulls are dark, state is `souls`.
- [ ] Kill a zombie while standing inside the Warden's Office, with the zombie also dying inside it: an orb
      drops and, when collected, the count increases and travels visibly to the hearth.
- [ ] **Kills through the office window from outside do not count.** Stand outside the office and kill a
      zombie standing inside it (or the reverse): no orb. Confirm both directions of the rule (killer
      outside / zombie outside).
- [ ] Skulls turn blue at 6, 12 and 18 orbs (one skull per threshold).
- [ ] Orbs stop spawning once the count is already at 18 (kill one more zombie in-office: no extra orb).
- [ ] **Failure path**: leave the office with nobody inside for the fail window (watch for the warning line
      partway through). The fireplace resets: state goes back to `ready` and the collected souls are lost.
      Confirm the skulls go dark again and the count restarts at 0 on the next attempt.
- [ ] Co-op: a second player can collect orbs and press the hearth; the souls state is shared, not per
      player.

## 3. The pickup

- [ ] At 18 souls, press use at the hearth: the flame turns blue, the tempered Blundergat rises, state is
      `pickup`. (`!mg goto pickup` fabricates this directly.)
- [ ] Take the gun within the 30 s window: state moves to `run`, you are now the carrier.
- [ ] **Failure path**: let the 30 s expire without taking the gun. The gun is deleted; if the player who
      placed it is still alive he gets a plain `blundergat_zm` back, otherwise nothing. State returns to
      `ready`.

## 4. The run

- [ ] `!mg goto run` (or take the tempered gun honestly): state is `run`, you carry the tempered Blundergat,
      a visible flame rides the weapon, the five barrels are lit blue, and a temper timer/bar is running.
- [ ] Standing within range of any lit barrel (office exit, top of the spiral stairs, bottom of the tunnels,
      Generator Room door) refills the timer to full.
- [ ] Firing a shot costs time off the timer (5 s per shot) - fire once and watch the timer drop.
- [ ] **Failure path - timer expires**: let the temper run out without refilling. State returns to `ready`,
      the gun in hand becomes a plain Blundergat again, and the fireplace resets (souls included - confirm
      the skulls go dark and the count is back to 0).
- [ ] **Failure path - weapon switch**: switch away from the tempered gun for more than 1 second. Same
      failure as above (state `ready`, plain Blundergat, souls reset).
- [ ] **Failure path - going down**: as the carrier, go down (last stand / bleed out). Same failure as above.

## 5. The forge

- [ ] `!mg goto forge` (or carry the tempered gun to the powered generator honestly): state is `forge`.
- [ ] At the generator: press once to power it (spark fx + sound), then place the tempered gun - it rests
      on the generator and ghosts for a few seconds.
- [ ] Take the Magmagat: state becomes `done`, `!mg status` confirms it, and the weapon now behaves as the
      Magmagat (see section 6).
- [ ] **Forge stays open once done**: with the quest already `done`, place a fresh, unrelated plain
      Blundergat on the generator - it converts to a Magmagat directly, no new temper run required.

## 6. The weapon (Magmagat / Magmus Operandi)

- [ ] Fire the Magmagat at a zombie: a lava ball travels to the target.
- [ ] A ball that catches a zombie sticks and explodes it and nearby zombies a moment later (kill credit and
      points go to you, the shooter).
- [ ] **Crawlers catch the ball too**: down a zombie into a crawl, then land a ball on it - it should catch
      and link at the `J_SpineUpper` tag like a standing zombie, then explode normally.
- [ ] A miss (no zombie catches the ball) leaves a burning magma patch on the ground; zombies that walk
      through it keep taking damage for a few seconds.
- [ ] **Brutus vs the ball**: land a ball on Brutus directly. He burns steadily but does not die from the
      lava alone, however many balls land on him.
- [ ] **Brutus vs a patch**: walk Brutus through a magma patch. He burns and takes damage over time, but
      again never dies from the patch alone.
- [ ] **Pack-a-Punch carry-over ("Sweeper in, Magmus Operandi out")**: Pack-a-Punch a Magmagat
      (`blundergat_zm` with the personality). It comes back as `blundergat_upgraded_zm` (the Sweeper) and
      keeps the personality, now titled Magmus Operandi, with one more shell per shot.
- [ ] **Acid Gat kit refuses a Magmagat**: try to use the Acid Gat upgrade station on a weapon that already
      has the Magmagat personality. It must be refused with a hint (the forge already claimed the gun), and
      the weapon must remain unchanged.
- [ ] A plain Blundergat (no personality) still upgrades at the Acid Gat station normally - confirm the
      refusal is specific to a flagged Magmagat, not a blanket block.
- [ ] With a Magmagat in hand, a Brutus-locked craftable table still charges its unlock price and unlocks;
      other craftables (shield, plane parts) still craft normally.
- [ ] Losing the personality (box swap, wall buy replacing the weapon, death without Tombstone) clears the
      flag; the forge (once `done`) can re-grant it to a fresh Blundergat.

## 7. Debug tools

- [ ] `!mg give` gives and switches to a plain Blundergat.
- [ ] `!mg magma` grants the Magmagat personality to the Blundergat currently in hand (refuses with a message
      if you are not holding one).
- [ ] `!mg fx <n>` / `!mg fx <name>` / `!mg fx next` / `!mg fx prev` / `!mg fx stop` auditions a registered
      effect where you aim for 8 s, and the console prints the index/name. Confirm there is no fx grid (not
      part of this mod).
- [ ] `!mg snd <n>` / `!mg snd <alias>` / `!mg snd next` / `!mg snd prev` plays a curated sound alias to you
      at full volume and prints its name; silence on a name means the alias is in no bank.
- [ ] **Shock pistol on a shock box**: `!mg shock` toggles on, fire the shock weapon (`m1911_zm` by default)
      at an Afterlife shock box - it should zap as if hit by the real Afterlife interaction.
- [ ] **Shock pistol on a power panel**: same toggle, aim at an Afterlife power panel instead - it should
      zap that too. Toggle `!mg shock` off afterward and confirm shots no longer zap anything.

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
- [ ] `perl tools/deploy.pl` installs without error.
