class_name Settings extends ConfigFile

signal changed

const SECTION = "settings"
const VOLUME = "volume"
const FULLSCREEN = "fullscreen"
const UUID = "uuid"
const USERNAME = "username"

var path: String


var uuid: String:
	set(value):
		if value == uuid:
			return
		uuid = value
		set_and_save(UUID, value)
		changed.emit()
	get:
		return get_value(SECTION, UUID, "")

var username: String:
	set(value):
		if value == username:
			return
		username = value
		set_and_save(USERNAME, value)
		changed.emit()
		Globals.metrics_manager.update_metadata("username", value)

	get:
		return get_value(SECTION, USERNAME, "")


var fullscreen: bool:
	set(value):
		if fullscreen == value:
			return
		fullscreen = value
		
		set_and_save(FULLSCREEN, value)
		_set_fullscreen()
		changed.emit()

	get:
		return get_value(SECTION, FULLSCREEN)
	
	

func _init() -> void:
	for i in AudioServer.bus_count:
		set_value(SECTION, "%s_%s" % [VOLUME, AudioServer.get_bus_name(i)], db_to_linear(AudioServer.get_bus_volume_db(i)))
	
	set_value(SECTION, FULLSCREEN, false)
	

func set_volume(bus: String, linear_volume: float) -> void:
	_set_volume(AudioServer.get_bus_index(bus), linear_volume)
	set_and_save("%s_%s" % [VOLUME, bus], linear_volume)
	

func get_volume(bus: String) -> float:
	return get_value(SECTION, "%s_%s" % [VOLUME, bus])
	

func set_and_save(property: String, value: Variant) -> void:
	set_value(SECTION, property, value)
	save(path)
	

func _set_volume(bus_index: int, linear_volume: float) -> void:
	if linear_volume < 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))
		AudioServer.set_bus_mute(bus_index, false)
	

func _set_volumes() -> void:
	for i in AudioServer.bus_count:
		var linear_volume = get_value(SECTION, "%s_%s" % [VOLUME, AudioServer.get_bus_name(i)])
		_set_volume(i, linear_volume)
	

func _set_fullscreen() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	

static func load_or_create(_path: String, force_create: bool = false) -> Settings:
	var settings = Settings.new()
	settings.path = _path
	
	if not force_create:
		settings.load(_path)
	
	settings._set_volumes()
	settings._set_fullscreen()
	
	return settings
