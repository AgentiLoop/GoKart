# GoKart

A Mario Kart–style arcade kart racer built with **Godot 4** and GDScript. Everything — track, karts, effects — is generated procedurally from code; there are no imported art assets.

## Features

- **Arcade kart physics** with drifting and mini-turbo boosts (release a drift to boost), off-road slowdown and wall collisions (`scripts/kart_physics.gd`)
- **Procedural closed-circuit tracks** with meshes, walls and animated boost pads; three tracks (Green Hills, Sunset Speedway, Frosty Peaks) with their own layout, item boxes, hazards and sky/ground colours (`scripts/track_data.gd`, `scripts/track.gd`, `scripts/track_library.gd`)
- **Title menu** to pick the track (A / D or arrows) and the lap count (W / S, 1/2/3/5/7 laps), Enter to race; Esc in a race returns to it (`scripts/menu.gd`)
- **3-lap races** with ordered checkpoints and live race ranking (`scripts/lap_tracker.gd`, `scripts/race_ranking.gd`)
- **Start countdown** (3-2-1-GO) with a rocket-start boost for well-timed throttle (`scripts/race_start.gd`)
- **AI opponents** using pure-pursuit steering, corner speed limiting, stuck recovery and item use (`scripts/ai_driver.gd`)
- **Items** from rainbow `?` item boxes with a roulette: mushroom, banana, green shell (ricochets), red homing shell, triple shells (three orbiting green shells fired one by one), blue spiny shell (hunts the leader along the road and explodes), star and lightning (`scripts/items.gd`, `item_holder.gd`, `item_manager.gd`, `item_projectile.gd`). Getting hit spins the kart out; lightning shrinks and slows every rival (`lightning_bolt.gd`).
- **Visual effects**: drift sparks, boost flames, tire trails, speed lines / boost blur, and custom shaders in `shaders/`
- **Results screen**: after you finish, an autopilot takes over and a standings table with points appears; Enter restarts (`scripts/race_results.gd`)
- **Procedural audio**: synthesized engine loop (pitch follows speed), tire screech while drifting, countdown beeps, boost / mini-turbo / item / hit / explosion / lightning / star sounds and a finish jingle, plus positional 3D engine hum on each AI kart, with no audio files (`scripts/ai_engine_audio.gd`, `scripts/sound_synth.gd`, `scripts/game_audio.gd`)
- **HUD** with place, lap, item slot and a track minimap (`scripts/hud.gd`, `scripts/minimap.gd`)
- **Procedural kart model** with steering front wheels and spinning wheels (`scripts/kart_model.gd`)

## Controls

| Key | Action |
| --- | --- |
| W / S | Accelerate / brake |
| A / D | Steer |
| Space | Drift (release for mini-turbo) |
| E | Use item |
| Enter | Race again (on the results screen) / start race (menu) |
| Esc | Back to the track menu |

## Running

Requires [Godot 4.4+](https://godotengine.org/).

```sh
godot --path .          # run the game (opens the title menu: scenes/menu.tscn)
```

## Testing

```sh
./run_tests.sh                                  # headless unit tests (tests/)
godot --headless --path . -s tools/smoke.gd -- 1  # headless race smoke test with AI karts (arg = track index)
godot --headless --path . -s tools/menu_check.gd  # menu -> race -> Esc flow check
godot --path . -s tools/screenshot.gd           # visual check, writes /tmp/gokart_*.png
```

## Project layout

```
scenes/   menu and race scenes
scripts/  game logic (physics, track, AI, items, HUD, effects)
shaders/  boost pad, item box, shell, star and speed-fx shaders
tests/    unit tests and test runner
tools/    smoke test and screenshot helper
```
