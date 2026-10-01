# GoKart
Mario Kart style racer in Godot 4.

- Run tests: `./run_tests.sh`
- Controls: W/S accelerate/brake, A/D steer, Space drift (release for mini-turbo boost)
- Track: procedural closed circuit (`scripts/track_data.gd` geometry, `scripts/track.gd` meshes/walls/pads), 3 laps with ordered checkpoints (`scripts/lap_tracker.gd`), boost pads (animated shader), off-road slowdown, HUD.
- Visual check: `godot --path . -s tools/screenshot.gd` (writes /tmp/gokart_*.png)
