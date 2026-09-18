# Pickers

Generators of three self-contained HTML pages used to choose the mod's sounds, props and effects by ear and eye:
one quest role at a time, the candidates under it, pick, Next, a copyable "role = choice" list at the end.

- `gen_snd_motd.pl` - Sound Picker: candidate cues of the zm_prison bank (`zmb_alcatraz.all`), playable (downsampled).
- `gen_mdl_motd.pl` - Prop Picker: the zm_prison models in a three.js viewer (glTF from the OpenAssetTools Unlinker).
- `gen_fx_motd.pl` - Effect Picker: every zm_prison effect with its `!mg fx <key>` command (effects render only in game).

Inputs are not in the repository (game data): the soundbank dump (`Unlinker.exe --include-assets soundbank` on
zm_prison.ff, patch_zm.ff, common_zm.ff) and the glTF model dump (`Unlinker.exe --model-format GLTF --include-assets
xmodel` on zm_prison.ff). Paths are set at the top of each script. Output: `perl gen_snd_motd.pl > wizard_snd.html`, etc.
