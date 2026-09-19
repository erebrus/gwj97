class_name AsteroidStreamer
extends Node2D

## Spawns and frees asteroid nodes around a target as it flies.
##
## Setup: add as a child of your world, assign asteroid_scene and target, run.
## The asteroid scene's root should have a `setup(data: AsteroidData)` method.

signal asteroid_mined(data: AsteroidData)

@export var asteroid_scenes: Array[PackedScene]
@export var target: Node2D
@export var load_radius_cells: int = 8
@export var unload_padding_cells: int = 3
@export var cells_per_frame: int = 3      ## build budget, keeps frame times flat
@export var field: AsteroidField

var _loaded: Dictionary = {}              ## Vector2i -> Array[Node2D]
var _pending: Array[Vector2i] = []
var _last_cell := Vector2i(2147483647, 0)



func _process(_delta: float) -> void:
	if target == null:
		return

	var cell := field.world_to_cell(target.global_position)
	if cell != _last_cell:
		_last_cell = cell
		_refresh_queues(cell)

	var budget := cells_per_frame
	while budget > 0 and not _pending.is_empty():
		_build_cell(_pending.pop_front())
		budget -= 1


func _refresh_queues(centre: Vector2i) -> void:
	_pending.clear()

	var wanted: Array[Vector2i] = []
	for oy in range(-load_radius_cells, load_radius_cells + 1):
		for ox in range(-load_radius_cells, load_radius_cells + 1):
			if ox * ox + oy * oy > load_radius_cells * load_radius_cells:
				continue
			wanted.append(centre + Vector2i(ox, oy))

	# Nearest first, so rock appears ahead of the ship before it appears behind.
	wanted.sort_custom(func(a, b):
		return (a - centre).length_squared() < (b - centre).length_squared())

	for c in wanted:
		if not _loaded.has(c):
			_pending.append(c)

	var drop := load_radius_cells + unload_padding_cells
	for c in _loaded.keys():
		var off: Vector2i = c - centre
		if off.x * off.x + off.y * off.y > drop * drop:
			_free_cell(c)


func _build_cell(cell: Vector2i) -> void:
	if _loaded.has(cell):
		return

	var nodes: Array[Node2D] = []
	for data in field.get_cell_asteroids(cell):
		var node := asteroid_scenes[data.scene % asteroid_scenes.size()].instantiate() as Asteroid
		node.position = data.position
		if data.mineral > 0:
			node.type = data.mineral -1
			node.set_richness(data.richness)
		else:
			node.mineral_count = 0
		#if node.has_method("setup"):
			#node.call("setup", data)
		add_child(node)
		nodes.append(node)

	_loaded[cell] = nodes


func _free_cell(cell: Vector2i) -> void:
	for n in _loaded[cell]:
		if is_instance_valid(n):
			n.queue_free()
	_loaded.erase(cell)


## Call this when the ship finishes breaking a rock. The asteroid stays gone
## after the cell unloads and reloads.
func mine(data: AsteroidData) -> void:
	field.mark_mined(data)
	asteroid_mined.emit(data)

	var nodes: Array = _loaded.get(data.cell, [])
	for n in nodes:
		if is_instance_valid(n) and n.has_method("get_data") and n.call("get_data") == data:
			n.queue_free()
			nodes.erase(n)
			break
