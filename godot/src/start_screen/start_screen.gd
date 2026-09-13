extends TextureRect


@onready var settings_menu: SettingsMenu = %SettingsMenu


func _ready() -> void:
	Globals.in_game=false
	Globals.music_manager.fade_in_menu_music()
	

func _exit_tree() -> void:
	Globals.music_manager.fade_menu_music()
	

func _on_start_button_pressed() -> void:
	Globals.start_game()
	

func _on_settings_button_pressed() -> void:
	settings_menu.open()
	
