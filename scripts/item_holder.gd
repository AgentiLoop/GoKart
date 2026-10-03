extends RefCounted
## The kart's item slot: picking up a box starts a short roulette, then the rolled
## item is held until used. Pure logic (no nodes) so it can be unit tested.

const Items := preload("res://scripts/items.gd")

signal roulette_finished(item: int)

var held := Items.Type.NONE
var roulette_time := 0.0
var roulette_duration := 1.5
var rank := 0      # race position when the box was hit (0 = unknown), biases the roll
var racers := 0
var charges := 0   # uses left of a multi-use item (triple shells / triple mushrooms / banana bunch)
var golden_time := 0.0   # seconds of unlimited boosts left once a golden mushroom is fired
var rng := RandomNumberGenerator.new()

func _init(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

func is_rolling() -> bool:
	return roulette_time > 0.0

## A golden mushroom has been fired and is still handing out boosts.
func is_golden_active() -> bool:
	return golden_time > 0.0

## Item box touched. Ignored while holding or rolling. Returns true if a roulette started.
func pickup(at_rank := 0, field_size := 0) -> bool:
	if held != Items.Type.NONE or is_rolling():
		return false
	rank = at_rank
	racers = field_size
	roulette_time = roulette_duration
	return true

func update(delta: float) -> void:
	if golden_time > 0.0:
		golden_time -= delta
		if golden_time <= 0.0:
			golden_time = 0.0
			if held == Items.Type.GOLDEN_MUSHROOM:
				held = Items.Type.NONE
	if roulette_time > 0.0:
		roulette_time -= delta
		if roulette_time <= 0.0:
			roulette_time = 0.0
			held = Items.roll(rng.randf(), rank, racers)
			charges = Items.charges_for(held)
			roulette_finished.emit(held)

## Consume the held item (NONE if empty or still rolling). Multi-use items (triples, banana
## bunch) spend one charge; a golden mushroom stays in the slot and keeps boosting until
## GOLDEN_DURATION runs out.
func use() -> int:
	var t := held
	if t == Items.Type.GOLDEN_MUSHROOM:
		if golden_time <= 0.0:
			golden_time = Items.GOLDEN_DURATION
		return t
	if charges > 1:
		charges -= 1
		return t
	held = Items.Type.NONE
	charges = 0
	return t

## Drop whatever is held or rolling (used when lightning strikes).
func clear() -> void:
	held = Items.Type.NONE
	charges = 0
	golden_time = 0.0
	roulette_time = 0.0

## What the HUD should show: the held item, or a cycling preview while rolling.
func display_item(time: float) -> int:
	if is_rolling():
		return 1 + int(time * 12.0) % Items.count()
	return held
