extends PanelContainer

@onready var level_selection: OptionButton = %LevelSelection

func _ready() -> void:
	hide()
	%Invulnerable.button_pressed = Debug.invulnerable
	 

func set_levels(levels:Array[PackedScene]):
	while level_selection.item_count>0:
		level_selection.remove_item(0)
		
	for i in levels.size():
		var level = levels[i]
		var level_name = level.resource_path.get_file().replace(".tscn", "")
		level_selection.add_item(level_name, i)
	

func _input(event: InputEvent) -> void:
	if Debug.debug_build and event.is_action_pressed("debug"):
		if visible:
			hide()
		else:
			open()
	

func open() -> void:
	if not is_instance_valid(Globals.game):
		return
	# TODO: before show logic
	show()
	

func _on_music_tension_toggle_pressed() -> void:
	if Globals.music_manager.current_game_music_id==Types.GameMusic.HARD:
		Globals.music_manager.change_game_music_to(Types.GameMusic.EASY)
	else:
		Globals.music_manager.change_game_music_to(Globals.music_manager.current_game_music_id+1)
	

func _on_invulnerable_toggled(toggled_on: bool) -> void:
	Debug.invulnerable = toggled_on
	

func _on_game_over_pressed():
	Globals.do_lose()
	

func _on_win_game_pressed():
	Globals.do_win()
	

func _on_load_level_button_pressed() -> void:
	if !Globals.in_game:
		await Globals.start_game()
		await get_tree().create_timer(0.1).timeout
	
	var level_idx = level_selection.selected
	Globals.game.level_manager.load_level(level_idx)
	
