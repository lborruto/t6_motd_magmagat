# Magmagat - owner test checklist

Solo (and co-op where noted) in game, with console `developer 1` and `developer_script 1` set before loading the
map (script errors show). Every test session then starts with, in the console once the map is loaded:

```
set mg_debug 1
say !mg bridge
```

(`!mg bridge` opens the fireplace without the plane.)

Install first, from the repo (Git Bash): `perl tools/build_mod.pl` (mod.ff, its sound bank mod.all.sabl / .sabs,
and mod.json) and `perl tools/deploy.pl` (the scripts and the client script `zm_prison_magmagat.csc`), both into `mods/zm_magmagat`; then Mods -> zm_magmagat in game. Check it loaded: console
`set mg_debug 1`, then `say !mg bridge` and `say !mg status` (it answers with the version, state, souls, carrier, timer, the gate flag
and whether the forge is open). Every `!mg` answer is also printed to the console as `[MG] ...`.

The `!mg ...` commands below are typed in chat. From the console, put `say` in front: `say !mg goto run`.

Tick each box in game; where a `!mg goto <state>` shortcut exists it is given next to the honest-play check,
but do the honest-play pass too at least once per state - `goto` only fabricates the state, it does not
prove the surrounding checks (prompts, fx, timers) actually fire.

## 0. Load

- [ ] No red error popup on map load.
- [ ] The client script is installed: `mods\zm_magmagat\scripts\zm\zm_prison\zm_prison_magmagat.csc` sits beside the
      packed `.gsc`, and it runs: type `mg_csc` in the console, it prints `fx <id> weapon <name> played <n>` (the
      flame effect, the weapon in your hands, the flames it played). `started` or `clients <n>` that never changes
      means it is stuck before its watcher (no client snapshot); an unknown dvar, that it never ran.
- [ ] The five route barrels are the remaster's dark-green drums and the three mantle skulls BO4's plain skulls
      (`!mg show` previews them; `!mg model mg_barrel_green` / `!mg model mg_skull_bo4` spawn one in front of you).
- [ ] `!mg status` prints the version, the state (`ready` after the start block's `!mg bridge`, `locked` before it), souls 0/15, no carrier, the gate flag and the
      forge (closed).
- [ ] `!mg spots` lists `MG_HEARTH`, `MG_HEARTH_USE`, `MG_SKULL_1..3`, `MG_BARREL_1..5`, `MG_FORGE`,
      `MG_FORGE_GUN`, `MG_PRESS`, `MG_LEVER`, `MG_FORGE_FX`, `MG_GHOUL_1`, `MG_GHOUL_2`; none say
      "undefined".
- [ ] `!mg help` lists `status`, `goto`, `spots`, `help`, `tour`, `press`, `power`, `lockdown`, `zone`, `bridge`, `give`, `magma`, `brutus`, `shock`
      (all at once) / `shock gun`, `fx`, `snd`, and the placement commands.

## 0a. The sound bank

- [ ] Console `printsoundalias mg_press`: the alias is known (the mod's `mod.all` bank loaded with `mod.ff`). If it
      is unknown, every `mg_*` sound is silent: report it (the bank then moves to a `mod_load` zone).
- [ ] `printsoundalias mg_fire_plr`, `printsoundalias mg_burn_loop` and `printsoundalias mg_reload_open`: Black Ops
      4's aliases are known too.

## 0b. The look, in one pass

- [ ] `!mg tour`: seven labelled stops. Every effect is visible and every sound heard (the BO3 remaster's own; step 7's are Black Ops 4's); note
      the step number of anything to change.
      1. The first press at the fireplace: the flame burst, the boards burn.
      2. A placed gun: the laugh, the office outlined in light, the door clip up.
      3. A soul: the essence a kill drops, low over the body; stepped on, it streaks into its skull.
      4. A lit skull (its blue flame).
      5. A drum burning, then its flare.
      6. The forge: the Machine powered, a gun pressed, with the real ram.
      7. A real Magmagat blob lobbed at the floor: it lays its pool, then the burst.

## 1. Locked / ready

(Type `say !mg goto locked` first: the start block's `!mg bridge` has opened the fireplace.)

- [ ] Before anyone has sat in the bridge chair after the first plane trip: state stays `locked`, no prompt at the
      hearth even with a Blundergat in hand, presses do nothing.
- [ ] Ride the plane and sit in a bridge chair, or `!mg bridge` (the same requirement met, without the plane), or
      `!mg goto ready`: state becomes `ready`. `!mg bridge` in any other state says the fireplace is already open.
- [ ] The first press at the hearth (gun or not, no prompt yet): the flame-burst sound, an orange burst of flame in
      the fire and embers on the floor before it; a second later "Hold [use] to place Blundergat" shows for every player near the hearth. This happens
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
- [ ] **Door clip, a player in the doorway** (co-op): P2 stands in that doorway as P1 places the gun. P2 is not stuck:
      the pillar on him comes up only once he has stepped out (the others at once). Then the doorway is shut.
- [ ] **Door, a teammate down inside** (co-op): P2, with no Afterlife left, goes down in the office during the
      lockdown: the door clip goes (console `MG: a teammate is down in the office: the door opens until he is up`),
      P3 walks in and revives him; once he is up the clip comes back (`the door shuts again`), never on a player.
      Again with P2 going into Afterlife in the office: if his ghost spawns outside, he can walk back in to his body.
      And P2 going into Afterlife just outside the doorway: if his ghost spawns inside, the door opens too.
      Report whether a ghost is held by the clip at all, and whether the Afterlife spawn lies outside the office.
- [ ] **Kill zone**: `!mg zone` marks its sides for 15 s (the remaster's soul catcher volume: x -1070 to -440, y 8493
      to 9187, the fireplace room and the office north of it up to that doorway). They must run along the blue walls.
- [ ] A Nuke in the office: its kills drop no essence (console `MG: kill not counted: no player attacker`).
- [ ] Kill regular zombies in the zone (the killer inside or outside, any weapon): the soul-kill sound at the body, and
      an essence (the remaster's blue skull flame) rises off the body over 2 s and waits there, humming. It does not count yet:
      `!mg status` shows no change. No blood.
- [ ] Step on an essence (within 40 units, any player): the soul-suck and wolf-head soul sounds where you stand, it
      hops and streaks into its skull in about 0.7 s (silent there), and the count goes up when it arrives. An essence
      nobody takes fades after 20 s.
- [ ] Kill more zombies than souls still missing without taking any: no more essences drop than souls still missing
      (15 lying = no new one); once some are taken, kills drop again.
- [ ] Brutus dying in the office, and a zombie dying outside it, give no soul.
- [ ] Skulls light at 5, 10 and 15: the blue flame, at the skull's foot and turned with it, and the plain skull turns into the Afterlife skull; no sound. No soul counts past 15.
- [ ] 1 s after the 15th soul reaches its skull the laugh plays again; 2 s later the outline and the door clip go, and
      the essences still lying there vanish.
- [ ] **Fail**: the placer goes down (last stand or Afterlife) during the lockdown: the skulls go out at once, no
      sound; the essences lying there vanish; 2 s later the outline and clip go, the gun is lost, the place hint is back,
      state `ready`. Another player going down, or the placer leaving the office for any time, changes nothing.
- [ ] **No fail after the 15th soul**: the placer goes down in the second between the 15th soul's arrival and the
      laugh (`!mg goto souls`, take the 15th essence, then let a zombie down you): the lockdown is still won.
- [ ] **The BO3 effects** (`!mg tour`): the blue flames (fireplace, drums, skulls, tempered gun), the essences, the
      press fire, the lava blob's trail / impact / burst and the lava pool are the remaster's own. Report any drawn as a
      black or white square, a wrong colour, or invisible.
- [ ] Co-op: any player's kills in the office drop essences and any player can take them; the souls state is shared.

## 3. The deposit and the pickup

- [ ] At 15 souls, only the placer sees "Hold [use] to deposit the essence" at the hearth; another player sees no prompt and his press does nothing. There is no time limit. (`!mg goto pickup`
      fabricates this with you as the placer.)
- [ ] Deposit: three souls streak from you into the gun in the fire (about 0.75 s), then the flame-burst sound, a flare
      and the fire burns blue, over the map's own fire. The three skull flames go out.
- [ ] **Double press**: press use twice quickly to deposit. The second press does nothing: the fire still turns blue,
      the skull flames go out, the gun stays in the fire until a press after that.
- [ ] The fire stays blue while nobody takes the gun (wait a minute), and the hint is now "Hold [use] to take the
      Tempered Blundergat", for the placer only.
- [ ] The take is refused while drinking a perk or holding a grenade, claymore or revive tool. With two primaries the
      weapon in hand is replaced.
- [ ] Take it: state moves to `run`, you are the carrier, the blue fire goes out.
- [ ] The placer disconnecting before the take (before or after the deposit): the gun is lost, the blue fire goes out,
      state back to `ready`.

## 4. The run

- [ ] `!mg goto run` (or take the tempered gun honestly): state is `run`, a flame rides the gun and the five barrels
      light together (no timer on screen: the flame is the only indicator; `!mg status` prints the seconds left).
- [ ] In your hands the tempered gun is BO4's Tempered Blundergat (a Sweeper gives the tempered Sweeper with its
      armour): its canisters glow blue and the remaster's blue flame burns at its muzzle in your own view, the whole
      time it is in hand. The flame in your view goes when you lower it (a perk, a revive) and comes back when it is in
      hand again. Console `mg_csc` meanwhile: weapon `mg_tempered_zm` (`mg_tempered_upgraded_zm` for the Sweeper) and
      `played` climbing about ten a second. The flame in your view stays full as the temper runs low (no fading).
- [ ] Co-op: another player sees the blue flame on the gun in your hands for the whole run (wait out a refill or two),
      not just as you take it.
- [ ] Fire it: the plain Blundergat's muzzle flash (no blue flash), in first person and as seen by another player.
- [ ] The five drums (the remaster's dark-green drums, filled 2/3 with ash and burnt wood) burn blue from inside, the flames rising out of the rim.
- [ ] Each drum is solid: you cannot walk through it nor jump onto it (its clip stands 128 units high from its foot).
- [ ] Stand at a lit drum's foot (within 64 units, feet 0-64 above its base): the temper is back to 15 s, with a 5 s
      flare and the flame-burst sound. No whoosh, no rumble; the drum keeps burning. A second visit to the same drum
      gives nothing. Standing on top of a drum does not count.
- [ ] After a refill the run fails 15-16 s later.
- [ ] Each shot of the tempered gun takes 6 s off the temper (`!mg status`) and refills its ammo; three shots in a
      row from a full 15 s fail the run ("the flame died"). Once the Machine is powered, shots cost nothing.
- [ ] Co-op: as the temper runs low (under 10 s) the flame another player sees on your gun thins out (sparser the
      lower it gets), and is full again at a drum, or once you power the Machine.
- [ ] Switching to another weapon (a perk drink, a box weapon) ends the run within about 0.1 s. Switching to a
      Blundergat, Sweeper, Acid Gat or Vitriolic Withering does not. The run does not fail at the pickup while the
      tempered gun is being raised (try with one and with two primaries).
- [ ] **Failure paths**: the timer runs out (do nothing for 15 s), you switch weapon, you go down, you revive a
      teammate (co-op: the syrette in your hands counts as a switch, the remaster's rule). Each: silent, the flame
      and the barrels go out, you get your Blundergat back, the skulls go dark; 5 s later the state is `ready` and the
      fireplace takes a gun again.
- [ ] When the run fails or the gun is laid on the forge, no blue flame stays in your view.
- [ ] **Box or wall gun, hands full**: with two primaries (the tempered gun in hand), take a Mystery Box gun or buy a
      wall gun: the run fails and the new gun has replaced the tempered one; no Blundergat comes back. With Mule Kick
      and a free slot: the Blundergat comes back next to the new gun.

## 5. The forge

- [ ] With the tempered gun at the forge, "Hold [use] to power the Machine" shows for the carrier only. Before that
      the press stands closed. Using it plays the power-panel sound and the sparks on the Machine, played out in full (about 4 s, twice); the press shudders and opens in fire;
      the run goes on but its timer stops (`!mg status`: `temper left stopped (Machine powered)`; waiting there past
      15 s does not fail it, 60 s without placing the gun does, and a weapon switch or going down still does) and the gun stays in your hands. A drum reached
      after that does not flare. 1 s after the press the Warden's line
      plays to that player only (not later, not at the press itself); the forge's place prompt comes about 1.5 s after it. (`!mg goto forge` fabricates a Magmagat
      waiting for you.)
- [ ] Then "Hold [use] to place the Tempered Blundergat", for the carrier only: nobody else, and no plain Blundergat,
      gets a prompt, and only while it is in his hands. Letting the temper run out before powering the Machine fails the
      run as anywhere else; once it is powered, only a weapon switch, going down or leaving does. On a later run (the
      Machine already powered) the timer runs until the gun is placed.
- [ ] The Machine has collision: you cannot walk through it.
- [ ] Place it: the run ends, the skulls go out, the drums go out 1 s later (not at once) and the fireplace takes a
      Blundergat again. The gun lies on the bed with a blue flare; two ghouls rise out of the bed (one appearance effect
      and sound for both) to the lever's grips and pull it at about 3.4 s; the ram
      strikes the gun at 4 s with a slam, no electricity (the gun disappears) and works it for 7.4 s in fire, the fire loop
      roaring; the press's fires burn the whole time (lit again at each slam), never dying out before the ram lifts.
      At about 11.6 s the ram and lever lift, a burst sprays upward (not sideways across the bed) and the Magmagat
      floats over the bed over tiny flames that stay until it is taken or lost, with the
      "build complete" chime; the ghouls are gone through the roof.
- [ ] At about 13 s "Hold [use] to take the Magmagat" shows, for the placer only.
- [ ] Taking it: a Brutus spawns about 1 s later, where vanilla's Brutus spawning puts him. With a Brutus already
      out (`!mg brutus` first), none comes (console `MG: a Brutus is already out`), and the next round's Brutus is not
      held back by a guardian on top of the cap.
- [ ] While a Magmagat is pressed or waits on the bed, the fireplace shows no place hint (co-op: P2 cannot start a
      run that would reach a busy forge); it comes back once the Magmagat is taken or lost.
- [ ] Every forge hint (power the Machine, place the Tempered Blundergat, take the Magmagat) and every fireplace hint shows the
      use key in yellow and the rest in white (`^3` / `^7`), like vanilla's.
- [ ] Take it: the weapon is `magmagat_zm` ("Magmagat" on the HUD). A Pack-a-Punched gun (Sweeper, Vitriolic
      Withering) gives `magmagat_upgraded_zm` (Magmus Operandi).
- [ ] **Failure path**: leave it 15 s: it disappears with no effect and no sound, and the forge offers placement again.
- [ ] Only the placer can take it; another player sees no prompt and his press does nothing.
- [ ] Place a second gun while you already own a Magmagat: taking it only refills the ammo of the one you own; a
      Pack-a-Punched gun pressed while you own a plain Magmagat makes it the Magmus Operandi (never the reverse).
- [ ] `!mg goto ready` in the middle of a press: the ram returns to rest (the press closed, the Machine unpowered) and the gun and
      ghouls are cleaned up.

## 6. The weapon (Magmagat / Magmus Operandi)

- [ ] Fire it: one orange blob (a little smaller than BO4's) flies with a trail of soft glints and a small fire riding
      it (no burst of solid star sparks round it, in first person too), the remaster's fire-coloured muzzle flash
      (the Magmus: Harry's _ug one), no tracer streak, no bullet impact and no green acid splash where it lands. The
      clip holds one (the Magmus two). Both fire Black Ops 4's own shot (the Magmus with its Pack-a-Punch layer over
      it) once every 0.4 s, reload in 2.3 s, and an empty trigger plays BO4's dry fire. A blob that sticks plays BO4's
      stick sound, then its burning loop until it goes (a little quieter than BO4's, the owner's call).
- [ ] **Reload and raise sounds**: reload (with a round left and empty): BO4's cylinder opening, the shells going in
      and the cylinder closing, each as the Blundergat's reload animation does it, with the Blundergat's cloth sound
      and a light rumble on a pad. The first raise of a fresh Magmagat (from the forge, or `!mg magma`): BO4's cock as
      the gun is cocked. Nothing plays twice or out of step, on the Magmus Operandi too.
- [ ] **No crash** (a game-ending "Could not play rumble asset" error): reload, empty reload and the first raise with
      each gun.
- [ ] **Hit a zombie** (BO4's): 0.5 s later a zombie of 1000 health or less bursts in gore and dies; a tougher one
      burns, keeps its gait at about 60 % of its speed (a sprinter stays a slower sprinter, its legs not sliding), and
      dies 4 s later. A second blob on a tough one hurts it again (1000) and starts its own 4 s. When the Magmagat
      kills it, it bursts in gore and the blob bursts in flame at its upper body (the upper spine, not where the blob
      stuck), with Black Ops 4's explosion sound (no green smoke): the zombies within 128 units of it lose limbs (some
      crawl on), catch fire, take 400 and burn to death (the burst hits them from the dead zombie's middle: their
      flames start at the body part facing it). Until then the blob keeps burning on it. Killed by another weapon (or
      a trap), it falls whole and the blob goes with it. No player is hurt. Other zombies are not
      drawn to a blob on a zombie. Near a hungry wolf head (the Hell's Retriever's) the stuck zombie dies whole.
- [ ] **Hit Brutus** (`!mg brutus` sends one): 0.5 s later 100, then he burns 5 s (his torso flames light only 2.5 s after the blob sticks, as BO4's, then an arm or a leg 1 s later and the rest 1 s after that, with no ignite or burning sound on him: Brutus burns silently; not while 12 enemies already burn) losing 10 to 20 % of his health each second (from round 15, 5 to 10 %), so before round 15 one blob usually kills him in 3 to 5 s; then the blob is gone with no burst; zombies are not lured. Two blobs a second apart: both burns stop when the first blob goes, but his flames stay until the last blob goes. A blob ending while a pool's burn still runs on him leaves his flames on until that burn ends (and the reverse).
- [ ] **Hit the floor, a wall or a ceiling**: the blob stays where it landed, standing out of that surface, its fire
      turned the same way, for 5 s, then vanishes (no explosion). Near the floor it draws zombies into its fire, 3 at a time
      (the Magmus Operandi 6, while it is in hand), the next coming as each dies: nearly every zombie near it. High up a wall,
      or outside the playable area, it draws none. A zombie touching its fire (64 units, 32 high) catches fire and
      burns to death (in early rounds within about 2 s). Brutus walking through it loses a tenth of his health each
      frame until his flames light 2 s later (with the burn compensation he usually dies in it). Only its owner is
      hurt touching it: 1 every 0.4 s, with a light rumble (a pad's), down or not.
- [ ] A blob fired into the sky (it never lands): a pool appears where it is after 5 s of flight, with no landing
      splash in mid-air (it stays there, it does not drop).
- [ ] A blob that hits a zombie dying in that moment (one bursting as it lands), or left in the air where a body
      vanished, drops to the floor under it and pools there, never hanging at chest height. A blob on the gondola
      pools where it stuck.
- [ ] A pool burns from the moment it lands: a blob landing at a zombie's feet sets it alight at once.
- [ ] A burning zombie: BO4's ignite sound, then its burning loop; Mob's torso fire up its spine and a small fire on an
      arm and a leg, the first at the body part nearest where it caught fire, one more every 0.5 s (watch them spread).
      The flames and the loop stay on it until it dies or for 8 s.
- [ ] The blob's landing splash flies out of the surface it hit (floor: upward; wall: out of the wall), for the Magmus
      Operandi too; a zombie's burst sprays upward, not sideways.
- [ ] **12 burning at most**: with 12 or more enemies burning (a big train through two pools), the next ones take
      only the first hit (no flames, no burn): a pool keeps hitting them while they stand in it.
- [ ] Spam 5 or more pools: never more than 2 at once (the oldest goes).
- [ ] **Points**: each burn pays +10 (its ticks at most every 0.5 s), each burst hit +10 on a survivor; the shot and
      the blob's impact pay nothing (the impact deals BO4's 10 damage; shoot a zombie point-blank, the blob blocked:
      no points); kills give the normal
      kill points (a burst kill +10 torso bonus); Brutus pays none per hit, as for any weapon.
- [ ] **Insta-Kill**: from round 10 (zombies over 1000 health), a blob kills the zombie it hits on contact, its head
      gibbed, with no burst and no splash on its neighbours, and its blob drops to the floor under it and pools there
      (never in the air at its chest); any pool or burn kills at once too.
      Brutus is not killed by it.
- [ ] **Co-op burst**: player A sticks a blob on a tough zombie, player B a second one: when B's blob kills it (0.5 s
      on), the burst's kills and points go to B (to A when A's burn kills it first).
- [ ] A burst in a crowd: its gibs and 400s land two by two, 0.1 s apart (BO4's throttle), not all in one frame.
- [ ] **Throttle under load** (co-op): two players burst trains back to back into a dozen burning zombies: the
      bursts' gibs and 400s still land within a second or so of the burst effect, never seconds later. A zombie
      caught in two bursts before its hit lands takes both 400s, as in Black Ops 4.
- [ ] **Spoon**: stuck-blob kills in the showers count.
- [ ] Ammo: Magmagat 1 in the clip, 30 to start, 36 at most; Magmus 2 / 25 / 30.
- [ ] **Look**: in first person the Magmagat is the BO4 model (its own receiver, stock and chains, molten canisters and
      barrels that glow and flicker) and the Blundergat's view animations play on it without parts drifting, the gun
      at the Blundergat's place on screen: idle, fire (hip and ADS), ADS in and out, reload (and empty reload), first
      raise, raise and drop, sprint, crawl. In the reload the right chains move with the right barrel and the
      Magmus Operandi's armour with the breaking action, none left standing in the air. The same on the Magmus Operandi. On the forge and in other players'
      hands it is the same model. No flame rides the held gun.
- [ ] **Pack-a-Punch**: a Magmagat comes back as `magmagat_upgraded_zm`, Magmus Operandi: the BO4 model with its
      armour kit, a 2-blob clip, the bigger pool and lure.
- [ ] **Acid Gat kit takes a Magmagat**: holding only a Magmagat, use the Acid Gat station: the kit shows the
      Magmagat going in (the Magmus Operandi for a Magmus), never a Blundergat, and the Acid Gat comes out (a Magmus
      Operandi gives the Vitriolic Withering) with the Magmagat's reserve ammo (fire a few first: the Acid Gat's
      reserve matches, up to its maximum).
- [ ] A plain Blundergat still upgrades at the Acid Gat station normally. With a Magmagat and an Acid Gat already,
      the Magmagat goes in and the Acid Gat is refilled, as BO4's kit does.
- [ ] **Back and forth**: Magmagat -> Acid Gat kit -> Acid Gat -> fireplace -> Magmagat again; the same with a
      Magmus Operandi -> Vitriolic Withering -> Magmus Operandi. No step gives back a lower tier.
- [ ] With a Magmagat in hand, a Brutus-locked craftable table still charges its unlock price and unlocks;
      other craftables (shield, plane parts) still craft normally.
- [ ] Losing the Magmagat (box swap, wall buy replacing it, death without Tombstone) loses it like any weapon;
      the open forge converts a fresh gun again.
- [ ] The Mystery Box never offers a Magmagat, nor a Blundergat to a player holding a Magmagat (or a Tempered
      Blundergat); a teammate without one can still get it (vanilla's one-Blundergat limit permitting). Nor to the
      player whose Blundergat lies in the fireplace (lockdown, pickup) or on the forge (pressed, waiting): co-op, with
      vanilla's limit free, he gets none while a teammate can.
- [ ] Watch the console for "missing fx key" and script errors, especially from the burning zombies and the lure.

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
- [ ] **Shock pistol and mg_debug**: toggle `!mg shock gun` on, then console `set mg_debug 0`: the next shot (and
      every one after) zaps nothing. Back to `set mg_debug 1`, `!mg shock gun` turns it on again (not off).
- [ ] `!mg brutus` with a Brutus already out: "MG: a Brutus is already out (vanilla's limit)", and no second one.
- [ ] `!mg power` plays the Machine's power step (once powered, its effects again); `!mg press` the forge's sequence on a
      Tempered Blundergat (the power step first if the Machine is not powered).
- [ ] `!mg grab MG_LEVER` pins the lever: `!mg move <forward> <right> <up>` nudges it from where you look; `!mg press`
      then shows the ghouls at its grips.
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
      every changed source; `"C:/Games/t6/gsc-tools/gsc-tool.exe" -m comp -g t6 -s pc -i client -y
      csc/zm_prison_magmagat.csc` for the client script.
- [ ] `perl tools/build_mod.pl` and `perl tools/deploy.pl` install without error.
