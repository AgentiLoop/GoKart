extends RefCounted
## The kart's item slot: picking up a box starts a short roulette, then the rolled
## item is held until used. Pure logic (no nodes) so it can be unit tested.

const Items := preload("res://scripts/items.gd")

signal roulette_finished(item: int)

var held := Items.Type.NONE
var roulette_time := 0.0
var roulette_duration := 1.5
var charges := 0   # uses left of a multi-use item (triple shells)
var rng := RandomNumberGenerator.new()

func _init(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

func is_rolling() -> bool:
	return roulette_time > 0.0

## Item box touched. Ignored while holding or rolling. Returns true if a roulette started.
func pickup() -> bool:
	if held != Items.Type.NONE or is_rolling():
		return false
	roulette_time = roulette_duration
	return true

func update(delta: float) -> void:
	if roulette_time > 0.0:
		roulette_time -= delta
		if roulette_time <= 0.0:
			roulette_time = 0.0
			held = Items.roll(rng.randf())
			charges = Items.TRIPLE_CHARGES if held == Items.Type.TRIPLE_SHELL else 0
			roulette_finished.emit(held)

## Consume the held item (NONE if empty or still rolling).
func use() -> int:
	var t := held
	if t == Items.Type.TRIPLE_SHELL and charges > 1:
		charges -= 1
		return t
	held = Items.Type.NONE
	charges = 0
	return t

## Drop whatever is held or rolling (used when lightning strikes).
func clear() -> void:
	held = Items.Type.NONE
	charges = 0
	roulette_time = 0.0

## What the HUD should show: the held item, or a cycling preview while rolling.
func display_item(time: float) -> int:
	if is_rolling():
		return 1 + int(time * 12.0) % Items.count()
	return held
