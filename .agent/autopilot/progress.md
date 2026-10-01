# Auto-pilot session — 2026-10-01 12:37
Goal: create a Mario Kart clone called GoKart. mkdir /Users/toddbruss/Documents/GitHub/GoKart with all Mario Kart effects. I believe Godot 4 can do the Mario Kart effects, but I haven't built any of them yet:
 • **Drift sparks and boost flames:** GPUParticles3D.
 • **Speed lines and boost blur:** screen-space shaders and the built-in glow and tonemapping.
 • **Item effects and tire trails:** shaders, plus Trail or ribbon meshes.
 • **Kart movement:** VehicleBody3D, or custom arcade physics for the Mario Kart handling. write unit tests and test the game frequently
Budget: no time limit, unlimited cycles


## Cycle 1
- Installed Godot 4.7.2 (brew cask), symlinked `godot` in /opt/homebrew/bin. git init (main).
- Added project skeleton, scripts/kart_physics.gd (pure model: speed, steer, drift, mini-turbo levels, boost), scripts/kart.gd, scripts/main.gd (ground+chase cam), tests/ runner + 11 physics tests (17 checks pass), run_tests.sh.
- TODO: drift sparks/boost flame GPUParticles3D, speed lines + boost blur shader, tire trails, track with checkpoints/laps, items (mushroom, shells, banana) w/ effects, UI, AI karts.
## Cycle 1 — 2026-10-01 12:39
Cycle 1 is committed (24ba080). It adds a Godot 4 project with a drivable kart; no effects yet. The 17 unit-test checks pass headless (`./run_tests.sh`). A 120-frame headless run of the main scene logged no errors, but I haven't looked at it in a window.

What I did:
- Installed Godot 4.7.2 via `brew install --cask godot` and symlinked `godot` into `/opt/homebrew/bin`. I ran `git init -b main` in GoKart, which wasn't a repo yet.
- Added `project.godot` with input actions: W/S accelerate/brake, A/D steer, Space drift.
- Added `scripts/kart_physics.gd`, a pure model with no scene dependencies. It covers acceleration, braking, reverse, friction and steering. Drifting is locked to the direction you started in and charges three mini-turbo levels, and boosts raise top speed and emit signals.
- Added `scripts/kart.gd`, a `CharacterBody3D` kart built from boxes, which drives the physics model.
- Added `scripts/main.gd` and `scenes/main.tscn`: a flat ground plane, sky, sun with shadows, glow and filmic tonemapping, and a chase camera.
- Added `tests/test_runner.gd` (auto-discovers `tests/test_*.gd`) and `tests/test_kart_physics.gd` with 11 tests.
- Added `README.md`, `.gitignore`, and the cycle notes in `.agent/autopilot/progress.md`.

What remains:
- GPUParticles3D for drift sparks and boost flames, tied to the `drift_level_changed` and `boost_started` signals.
- Speed-line and boost-blur screen shader.
- Tire trails.
- A real track with checkpoints and laps.
- Items (mushroom, shells, banana) with effects.
- HUD, and AI karts.
- A proper kart model.
- Add a headless smoke test that loads the main scene.

Blockers: none. No parity folders were specified, so none were mirrored.

Assumptions:
- I used custom arcade physics instead of `VehicleBody3D`, so the Mario Kart handling is easy to unit test.
- The Godot 4 line in `config/features` is set to "4.4" even though 4.7.2 is installed.


## Cycle 2
- Added scripts/kart_effects.gd (GPUParticles3D drift sparks colored per mini-turbo level, boost flames, 4 tire-trail ribbons), scripts/tire_trail.gd (ImmediateMesh ribbon), scripts/speed_fx.gd + shaders/speed_fx.gdshader (radial boost blur, speed lines, vignette), FOV kick in main.gd.
- tests/test_effects.gd (7 tests); test runner now uses _initialize so a live scene tree exists. 43 checks pass.
- tools/screenshot.gd: windowed run that drives the kart and saves /tmp/gokart_{drift,boost}.png (ran on Metal, no shader errors; images not visually inspected).
- TODO: track with checkpoints/laps, items (mushroom, shells, banana) w/ effects, HUD, AI karts, proper kart model, boost pads, mini-turbo flash/star effects.
## Cycle 2 — 2026-10-01 12:41
Cycle 2 is committed (9a60b82). Drift sparks, boost flames, tire trails and the speed-line/boost-blur shader are in. All 43 unit-test checks pass headless (`./run_tests.sh`). I haven't looked at the screenshots, so I can't say how the effects look.

What I did:
- **Kart effects:** `scripts/kart_effects.gd` adds drift sparks as GPUParticles3D at the rear wheels, coloured by mini-turbo level (warm white, then blue, orange, purple). It also adds GPUParticles3D boost flames at the exhausts, and tire trails. Everything is driven by the `KartPhysics` drift and boost signals.
- **Tire trails:** `scripts/tire_trail.gd` is a ribbon mesh that fades and expires. One trail per wheel is drawn while drifting, tinted by drift level.
- **Screen shader:** `shaders/speed_fx.gdshader` and `scripts/speed_fx.gd` give a radial boost blur, speed lines and a vignette with a boost tint. Camera FOV widens with speed and boost in `main.gd`. `kart.gd` and `main.gd` are wired up.
- **Tests:**
  - `tests/test_effects.gd` adds 7 tests (spark colours, emitter wiring, trail growth, expiry and gaps, shader parameters).
  - I changed the test runner from `_init` to `_initialize` so tests get a live scene tree.
- **Visual check:** `tools/screenshot.gd` runs the game windowed on Metal, drives a drift and boost, and saves `/tmp/gokart_drift.png` and `/tmp/gokart_boost.png`. The run logged no shader or script errors, and the screenshots were saved. The saved drift frame was still at drift level 0.
- `progress.md` is updated.

What remains:
- A real track with checkpoints and laps, and boost pads.
- Items (mushroom, shells, banana) with their effects.
- HUD.
- AI karts.
- A proper kart model.
- A mini-turbo flash/star effect.
- Look at the screenshots and tune the effect parameters.

Blockers: none. No parity folders were specified, so none were mirrored.

Assumption: tire trails only draw while drifting, not during normal driving.

## Cycle 3
- Added procedural track (scripts/track_data.gd pure geometry: Catmull-Rom loop resampled at 3 m, road queries; scripts/track.gd: road ribbon, striped walls w/ box colliders, start gate, boost pads), scripts/boost_pad.gd, shaders/boost_pad.gdshader (scrolling chevrons, HDR emission -> glow), scripts/lap_tracker.gd (8 ordered checkpoints, 3 laps, shortcut/wrong-way proof), scripts/hud.gd (lap, timers, speed, boost/mini-turbo state, FINISH banner).
- KartPhysics.surface_scale (off-road halves top speed, boost overrides); kart.gd loses speed on wall hits; main.gd wires track/laps/pads/HUD.
- tests/test_track.gd: 14 new tests incl. an end-to-end pursuit bot finishing 3 laps (~62 s) -> 90 checks pass.
- tools/screenshot.gd now uses a bot + physics-frame stages; ran windowed on Metal with no errors, drift_charged and boost shots saved (not visually inspected).
- Observation: drift min turn radius (~17-40 m) is tighter than the track's broad bends, so drifting on the gentle curves hits the inside wall; tune track corners / drift arc.
- TODO: items (mushroom, shells, banana) w/ shader effects, AI karts, proper kart model, mini-turbo flash/star, tighter drift-friendly corners, countdown + start boost, minimap.
