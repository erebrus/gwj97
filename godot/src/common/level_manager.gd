class_name LevelManager extends Node

signal unloading_level
signal loading_level
signal level_unloaded
signal level_ready

signal game_completed

@export var levels: Array[PackedScene]
@export var level_container:Node
@export var unload_delay:=0.0
@export var override_level:PackedScene


var current_level_idx = 0
var current_level: BaseLevel:
	get():
		if current_level and current_level.is_node_ready():
			return current_level
		
		GSLogger.warn("Trying to access level, but there is none there.")
		return null
	

func _ready():
	assert(level_container)
	assert(levels and not levels.is_empty())
	

func is_last_level() -> bool:
	return current_level_idx>=levels.size()-1
	

func load_first_level():
	if override_level:
		_load_level(override_level)
	else:
		current_level_idx = 0
		load_current_level()
	

func load_current_level():
	_load_level(levels[current_level_idx])
	

func load_level(level_idx: int):
	if level_idx < 0 or level_idx >= levels.size():
		GSLogger.warn("Tried to load invalid level (idx=%d)" % level_idx)
		return
	
	current_level_idx = level_idx
	_load_level(levels[current_level_idx])
	

func load_next_level():
	if is_last_level():
		game_completed.emit()
		return
		
	current_level_idx+=1
	_load_level(levels[current_level_idx])
	

func _has_loaded_level() -> bool:
	return level_container.get_child_count() > 0
	

func _load_level(scene:PackedScene):
	if _has_loaded_level():
		_unload_current_level()
	
	loading_level.emit()
	var new_level = scene.instantiate()
	current_level = new_level
	
	# TODO: call here any initialization of the level needed BEFORE adding to the tree (maybe we should set GameState here?)
	
	level_container.add_child.call_deferred(new_level)
	await new_level.ready
	level_ready.emit()
	

func _unload_current_level():
	unloading_level.emit()
	current_level = null
	
	if unload_delay > 0:
		await get_tree().create_timer(unload_delay).timeout
	GameUtils.clear_node(level_container)
	level_unloaded.emit()
	
