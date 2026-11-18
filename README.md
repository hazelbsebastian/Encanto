# Encanto

| | |
|---|---|
| Student | [LASTNAME], [FirstName] - [Student Number] |
| Game title | Encanto |
| Theme | Philippine Games and Sports |
| Platform | Android (target), Windows (development and testing) |
| Engine | Godot 4.7.2 (GL Compatibility renderer) |
| Version | 0.13.0 (Week 13) - tag `v0.13.0-week13` |
| Repository | [paste GitHub URL here] |
| Current commit | see `git log -1` / the Week 13 submission README |

## Week 13 changes - local player profiles (PT5)

- **Profiles:** up to 4 local profiles per device, each with a nickname
  (2-12 letters/numbers/spaces/-/_). First launch opens the profile screen;
  the title screen shows the active player and has a PROFILE button.
- **Protected saves:** each profile has its own encrypted save
  (`user://profiles/<id>.sav`). The key comes from the device id plus a random
  per-install value (`device.key`), so no key is in the source code or repo.
  Edited or damaged saves are rejected; the last good backup is restored.
- **Old saves:** a pre-Week-13 `encanto_save.json` is moved into a profile
  called "Player 1" on first launch, then the plain-text file is deleted.
- **No network, no analytics, no real names.** See the Week 13 SA5 data
  inventory for every data item.
- **Tests:** `tests/TestProfiles.gd` has 18 automated cases. Run:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/TestRunner.tscn -- --run-tests`
  (uses a separate test folder and never touches real saves).


A Filipino-folklore-inspired 3D action game, built as a playable Godot 4
project. The battles take place in real 3D recreations of five Philippine
places (third-person camera); menus and pop-ups are a themed 2D UI on top. All art is generated with smooth, anti-aliased vector-style
painting (HD, exported at 2x and shown at scale 0.5) and the SFX are
synthesized — nothing is a placeholder box.

## How to open

1. Install **Godot 4.3+** (Forward+/Compatibility, either works — the
   project is set to GL Compatibility for widest hardware support).
2. Open Godot -> Import -> select this folder's `project.godot`.
3. Press **F5** (or the Play button). It starts at the title screen.
   The first launch will take a few extra seconds while Godot imports the
   generated PNG/WAV assets.

## Controls

Every on-screen touch button has a keyboard (and gamepad) twin, registered
in `scripts/systems/Controls.gd`. All menus and pop-ups are keyboard-driven:
arrows/WASD move the gold focus ring, Enter/Space presses, Esc goes back.

- **Move:** W A S D or the arrow keys, or drag the on-screen joystick.
- **Camera:** Q / E, the right stick, or drag anywhere on the screen.
- **Jump:** Space, or the on-screen JUMP button. Double jump unlocks
  once you reach the Tikbalang stage.
- **Pause:** Esc / P, or the II button (top-right).
- **Shoot:** X (or J/K), or the on-screen SHOOT button (bottom-right).
  - Tap = a normal, auto-aimed rock at the nearest enemy.
  - After 5 taps, "CHARGE READY" appears — **hold** the button to charge
    a stronger, manually-aimed shot (aim with left/right, and up/down to
    arc it). Release to fire. This is also the only way to hurt the
    Kapre's tree in the final fight.

## Full loop implemented

Title -> Jeepney intro ("San punta mo?") -> pick 1 of 5 Philippine
locations -> jeepney travel/loading -> arrival ("Bayad ko, manong.") ->
Tyanak x4 -> stage clear (Congrats -> picture puzzle -> reveal) -> Manananggal x4 (flying upper body +
running lower body) -> puzzle -> Tikbalang x4 (double jump) -> puzzle ->
Kapre boss (dodge random smoke attacks, break the tree with charged shots)
-> victory -> jeepney ride out -> **Pera o Bayong** reward -> wardrobe
(spend Pera money on outfits, or unlock outfits for free from the Bayong)
-> Play Again. Money and wardrobe unlocks are saved per player profile in
`user://profiles/<id>.sav` (encrypted) and persist between sessions.

## 3D + audio (scripts/3d/, assets/audio/)

- Everything 3D is built in code from primitive meshes (`M3.gd` modelling kit,
  `Models.gd` characters/props, `MapBuilder3D.gd` the five locations) - no
  external model files. `Level3D.gd` runs the jeepney arrival, waves,
  stage-clear puzzle, the Kapre + balete tree boss and the ending.
- Creatures: Tyanak (crawls + lunges), Manananggal (flying torso dives, legs
  kick), Tikbalang (rears up, then charges), Kapre (immune, blows smoke;
  break his tree with charged shots). Normal shots auto-aim (gold ring).
- Voice lines ("San ka punta?", "Bayad ko, manong.", "Kongrats!"...) are
  Windows text-to-speech with phonetic Tagalog spelling, listed in
  `gen_scripts/voice_lines.json`. Replace any `assets/audio/voice/<id>.wav`
  with a real recording (same file name) and the game uses it.
- Music (kulintang-style gong melodies), ambience per place and extra SFX are
  synthesized by `gen_scripts/gen_audio_more.py`.

## Project layout

```
scenes/   main/ player/ jeepney/ maps/ enemies/ ui/ puzzles/
scripts/  player/ enemies/ systems/ ui/
assets/   player/ enemies/ maps/ jeepney/ weapons/ ui/ audio/
gen_scripts/   the Python/Pillow tools used to generate every sprite and
               the synthesized SFX (run_all.py -> HD art: gen_maps_hd,
               gen_sprites_hd, gen_portraits) (not part of the Godot project itself -
               kept for reference/regeneration, ignored via .gdignore).
```

Systems are autoloaded singletons: `GameManager` (run state: hearts,
stage, streak), `SaveSystem` (local profiles + encrypted per-profile saves),
`ClothingData` (wardrobe catalogue + Bayong reward pool - easy to extend),
`Audio` (SFX playback pool).

## Known limitations

- The save key lives on the same device as the save. Encryption stops casual
  editing and copying saves between devices/profiles, but a player with full
  access to the device and the game files could still recover the key. That is
  acceptable here because the game is offline and single-player (no
  leaderboard, no purchases), but it would not be enough for online data.
- No cloud backup: uninstalling the game or clearing app data deletes all
  profiles.
- No export templates were installed in Week 13, so there is no packaged
  .apk/.exe yet; the game runs from the Godot editor.

## Known prototype simplifications

- **Wardrobe visuals:** the farmer sprite is a single flattened image
  (not layered by garment), so equipping a different top/bottom tints the
  whole sprite rather than recoloring just that garment. Accessories
  (e.g. Salakot) *do* render correctly as a real overlay above the head.
  Everything else about the system (buying, unlocking from Bayong,
  equipping, saving) is fully functional.
- **Puzzle minigame:** each defeated enemy drops one piece of the NEXT
  creature's portrait (`assets/puzzles/`). After a stage: Congrats pop-up ->
  swap the 4 scrambled pieces until the picture is whole -> the finished
  picture reveals the next enemy -> next wave. It is a 2x2 swap puzzle rather
  than a jigsaw with irregular edges.
- Enemy waves are capped at 2 concurrent creatures per stage (of 4 total)
  for readability rather than spawning all 4 at once.

Everything else in the design brief - the mobile-style joystick/buttons,
shot-streak -> charged-attack unlock, heart-based health with
invulnerability frames, all four enemy types with their described attack
patterns, the Tyanak/Manananggal/Tikbalang/Kapre progression with puzzle
interludes between each, the Kapre-can't-be-shot/tree-is-the-real-target
boss mechanic, the Pera/Bayong reward system with a random, extensible
loot pool, and the money/wardrobe save system - is implemented and
playable start to finish.
