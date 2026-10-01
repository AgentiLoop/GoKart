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
