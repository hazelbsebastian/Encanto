# Encanto

| | |
|---|---|
| Student | Sebastian, Hazel B. - BSIT-4A - 23-10584 |
| Game title | Encanto |
| Theme | Philippine Games and Sports |
| Platform | Android (APK) and Windows (exe) - same project, same commit |
| Engine | Godot 4.7.2 (GL Compatibility renderer) |
| Version | 0.16.0 (Week 16) - tags `v0.13.0-week13`, `v0.14.1-week14`, `v0.15.0-week15`, `v0.16.0-week16` |
| Repository | https://github.com/hazelbsebastian/Encanto |
| Current commit | see `git log -1`; Week 16 build: tag `v0.16.0-week16` |

## Weekly log

| Week | Output | Tag | Main changes |
|---|---|---|---|
| 13 | SA5, PT5 | `v0.13.0-week13` | Local player profiles, encrypted saves, 18 tests, debug APK |
| 14 | PT6 | `v0.14.1-week14` | Accessibility fixes (48 dp touch targets, readable touch/keyboard hints, 13.6:1 contrast, volume saved per profile, auto-pause); playtest fixes (hit/miss/damage feedback, first-enemy tip); Windows build |
| 15 | AS3 milestone | `v0.15.0-week15` | 31 automated gameplay tests + 20 save tests; 5 defects found and fixed (D01-D05); APK also runs on x86_64 (emulator) |
| 16 | SA6, AS3 report | `v0.16.0-week16` | Repeatable benchmark (`tests/PerfBenchmark.tscn`); static map batching: draw calls -36% in combat, -36% to -55% per map |

## Install (Windows)

1. Unzip `Sebastian_Hazel_AS3_Windows.zip`.
2. Run `Encanto/Encanto.exe` (keep `Encanto.pck` next to it).
   Windows may show "Windows protected your PC" because the exe is unsigned:
   More info -> Run anyway.

## Install (Android)

1. Copy `Sebastian_Hazel_AS3.apk` to the phone (Android 7.0 or newer; ARM phones, or an x86_64 emulator).
2. Allow "Install unknown apps" for your file manager, then open the APK.
3. The app requests no permissions (no internet access).

Build it yourself: Godot 4.7.2 + Android export templates, then
`Project > Export > Android` (preset included; arm64-v8a + armeabi-v7a + x86_64).

## Week 16 changes - performance (SA6 / AS3 report)

- **Benchmark** `tests/PerfBenchmark.tscn` (needs a window, not headless):
  loads all 5 maps (load time + 3 s view each), then 60 s of scripted combat
  and 15 s of the boss on Banaue. Writes per-frame CSV + summary to
  `user://perf/`. Run:
  `Godot_v4.7.2-stable_win64_console.exe --path . res://tests/PerfBenchmark.tscn -- --label=mytest`
  (add `--no-bake` to switch optimisation O1 off for an A/B run).
- **O1 static batching** (`M3.bake_static`, called from `MapBuilder3D.build`):
  static, opaque map parts are merged into one mesh per material and per 64 m
  cell. Draw calls: combat 547 -> 350, Mayon 620 -> 293, Boracay 433 -> 197.
  Trade-off: more triangles are drawn (coarser culling) and map build takes
  30-60 ms longer. Tweened boats/foam and transparent parts are not merged.
- **Found, not fixed yet:** memory grows about 32-38 MB during the 75 s run
  with a stable node count; a 100-150 ms stutter when the boss stage starts
  and 45-70 ms when the first puzzle opens; the APK is 105 MB because it
  carries the engine for 3 CPU types (84 MB).

## Week 15 changes - testing and defect correction (AS3 milestone)

- **New test suite** `tests/TestGameplay.gd` (31 cases): loads the real
  scenes and plays them - shooting, waves, puzzle, boss, Game Over, pause,
  reward, wardrobe - plus rapid input, missing data and app backgrounding.
  Run:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/TestGameplayRunner.tscn`
  (add `-- --only=F03,N12` for a subset). First run on 0.14.1: 25 passed,
  5 failed. After the fixes: 31 passed, plus 20/20 save tests.
- **Fixed:**
  - D01 - direct hits that touched a creature's body showed MINTIS and did
    no damage (10 of 12 test shots). Now 12 of 12 hit.
  - D02 - double-tapping "Laban na!" after a puzzle skipped a whole stage.
  - D03 - the Week 14 auto-pause never opened on a real focus loss (the OS
    path locks the node; the menu is now opened deferred).
  - D04 - the Kapre blew smoke during his intro while the player could not
    move.
  - D05 - smoke still in the air after the tree fell could cause Game Over
    after winning, and then the win was not saved.
- The APK now also includes x86_64 so the same file runs on the Android
  emulator used for compatibility testing.

## Week 14 changes - usability and accessibility (PT6)

- **Touch targets:** everything tappable is at least 60 canvas px (about
  48 dp on a phone, the Android minimum). Title menu is now a 2x2 grid.
- **Hints:** on-screen hints are 15 px on a dark chip and follow the input in
  use - TIRA / TALON / GALAW / HINTO on touch, X / SPACE / WASD / ESC on
  keyboard (`Controls.touch_mode`).
- **Volume** is saved per profile (was reset every launch).
- **Auto-pause** when the app loses focus (phone call, home button, alt-tab).
- **Playtest fixes (3 testers):** TAMA! / MINTIS feedback for hits and misses,
  red screen-edge flash when a heart is lost, first-enemy tip.
- **Audit tool:** `tests/AccessibilityAudit.tscn` measures every button and
  label on the real screens and saves screenshots.
- Tests: 20 automated cases (T19-T20 for volume), all passing.

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
- The charged throw needs press-and-hold; there is no tap-to-toggle option yet
  (players with limited hand control may find it hard).
- Text size cannot be changed in settings.
- No fire-rate limit on normal shots: tapping very fast fires a rock per
  tap (40 in one frame in test N01) and builds the 5-shot charge quickly.
  Deferred to Week 16 (performance and balance).
- The wardrobe preview shows the Salakot icon for the Traditional Kerchief
  (the 3D model in the game is correct).
- The Week 13 APK is a debug build (signed with the Android debug key). A
  release keystore is needed for Week 17 and must never be committed.

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
