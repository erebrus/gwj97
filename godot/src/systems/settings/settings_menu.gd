class_name SettingsMenu extends PanelContainer


func _ready():
	%SoundSlider.value_changed.connect(_on_volume_changed.bind(%SoundSlider.bus_name))
	%MusicSlider.value_changed.connect(_on_volume_changed.bind(%MusicSlider.bus_name))
	hide()
	

func open():
	%FullScreenCheckBox.button_pressed = Globals.config.fullscreen
	show()
	

func close():
	hide()
	

func _on_volume_changed(value: float, bus_name: String):
	if not is_node_ready():
		return
	
	%RangeSfx.play()
	Globals.config.set_volume(bus_name, value)
	

func _on_fullscreen_check_box_toggled(toggled_on: bool):
	Globals.config.fullscreen = toggled_on
	

func _on_close_button_pressed():
	close()
