class_name Game extends Node2D

@export var start_state:GameState
@export var game_state:GameState


@onready var level_manager: LevelManager = $LevelManager
@onready var fade_panel: FadePanel = %FadePanel

func _ready():
	Events.level_ended.connect(_on_level_ended)
	fade_panel.show()
	fade_panel.fade_in()
	level_manager.load_first_level()
	Debug.set_levels(level_manager.levels)
	Globals.game = self

func _on_level_ended():
	fade_panel.fade_out()
	await fade_panel.fade_out_completed
	if not level_manager.is_last_level():
		fade_panel.fade_in()
	level_manager.load_next_level()
	


func _on_level_manager_game_completed() -> void:
	Globals.do_win()
	

func _on_level_manager_level_unloaded() -> void:
	pass
	

func get_level()->BaseLevel:
	return level_manager.current_level
	

func _on_level_manager_level_ready() -> void:
	if get_level().override_game_state:
		get_level().set_state(get_level().override_game_state)
	else:
		if level_manager.current_level_idx==0:
			game_state = start_state.duplicate()
		get_level().set_state(game_state)
	
	
