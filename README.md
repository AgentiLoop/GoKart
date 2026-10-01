# GoKart
Mario Kart style racer in Godot 4.

- Run tests: `./run_tests.sh`
- Controls: W/S accelerate/brake, A/D steer, Space drift (release for mini-turbo boost), E use item
- Track: procedural closed circuit (`scripts/track_data.gd` geometry, `scripts/track.gd` meshes/walls/pads), 3 laps with ordered checkpoints (`scripts/lap_tracker.gd`), boost pads (animated shader), off-road slowdown, HUD.
- Visual check: `godot --path . -s tools/screenshot.gd` (writes /tmp/gokart_*.png)
- Items: item boxes (rainbow `?` cube shader) start a roulette (`scripts/item_holder.gd`); mushroom boost, banana (dropped behind), green shell (fired ahead, ricochets off walls, `shaders/shell.gdshader`). Getting hit spins the kart out (`KartPhysics.spin_out`). Logic is in `scripts/items.gd`, `item_projectile.gd`, `item_box.gd`; `item_manager.gd` wires them into the race. Two bananas are pre-placed as road hazards.
