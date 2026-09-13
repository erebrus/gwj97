class_name MetricsManager extends Node

const GAME_KEY := "_"

@export 
var metrics:Array[Metric]
var data:Dictionary[String, LevelMetrics]

@export
var persisted_event_names:Array[String]
#@export
#var sampling_period:float = 1.0

var metadata:Dictionary = {}

#@onready var timer: Timer = $Timer TODO CLEANUP
var start_time:int


func _ready() -> void:
	start_time = Time.get_ticks_msec()
	for metric:Metric in metrics:
		metric.setup(self)
	MetricsEvents.register_events(self)
	#TODO connect to event that triggers periodic metric collection
	#Events.turn_ended.connect(_on_timer_timeout) 

	
func _on_timer_timeout() -> void:
	if is_instance_valid(Globals.game):
		for metric:Metric in metrics:
			metric.update_value(Globals.game)
		#print_metrics()

func add_metric_metadata(key:String, value:String):
	metadata[key] = value

func clear():
	metadata.clear()

func update_metadata(key:String, value):
	metadata[key] = value

func reset():
	start_time = Time.get_ticks_msec()
	metadata.clear()
	
	var ld := LevelMetrics.new()
	ld.name = GAME_KEY
	data[GAME_KEY] = ld
	metadata["uuid"] = Globals.uuid
	metadata["session_id"] = Globals.session_id
	metadata["session_start_time"] = Globals.session_start_time
	metadata["username"] = Globals.config.username
	metadata["run_id"] = Globals.run_id
	metadata["sector"] = "Tutorial" if Globals.do_tutorial else Globals.start_state.run.get_current_sector().name
	metadata["version"] = ProjectSettings.get_setting("application/config/version")
	metadata["start_time"] = Time.get_datetime_string_from_system()
	metadata["window_size"] = str(DisplayServer.window_get_size())
	metadata["screen_size"] = str(DisplayServer.screen_get_size())
	metadata["fullscreen"] = str(Globals.config.fullscreen)
	metadata["OS"] = OS.get_name()
	data.clear()
	
func stop():
	metadata["end_time"] = Time.get_datetime_string_from_system()

func get_metric_last_value(_name:String, default=null)->String:
	for metric:Metric in metrics:
		if metric.name == _name:
			if metric.values.is_empty():
				return default
			else:
				return "%s" % metric.values[-1]
	return default
	
#func print_metrics():
	#for metric:Metric in metrics:
		#var values:Array = metric.values
		#if values.size() > 5:
			#var first = values[0]
			#values = values.slice(values.size()-5, values.size())
			#GSLogger.trace("Metric:%s = %s .. %s" % [metric.name, first, values])
		#else:	
			#GSLogger.trace("Metric:%s = %s" % [metric.name, values])
			
func get_state()->Dictionary:
	var metric_dicts:Array
	for m:Metric in metrics:
		metric_dicts.append(m.get_state())
	var level_data:Array
	for level in data:
		level_data.append(data[level].get_state())
		
	return {"metadata":metadata,"metrics":metric_dicts, "data":level_data, }


func set_state(state:Dictionary):
	metadata = state.metadata	
	data.clear()
	metrics.clear()
	for level_data in state.data:
		data["level"] = LevelMetrics.create_from_dict(level_data)
	
func load_from_file(path:String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var content:String = file.get_as_text()
	if content.is_empty():
		Globals.error_and_push("Can't load metrics.")
		Globals.delete_metrics()
		return 
	var dict:Dictionary=JSON.parse_string(content)
	set_state(dict)

func save_to_file(path:String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(get_state(),"\t"))

func get_level_key()->String:
	var level=GAME_KEY
	if Globals.game and Globals.game.get_level():
		level = Globals.game.get_level().scene_file_path #TODO fix later when we have Planet in the level directly
		if level.is_empty() and Globals.game.game_state.run.get_current_sector() and Globals.game.game_state.run.get_current_sector().get_current_node():
			level = Globals.game.game_state.run.get_current_sector().get_current_node().planet.name
	return level
	
func ensure_level_metrics_exist():
	var level:String = get_level_key()
	if not level in data:
		var level_data = LevelMetrics.new()
		level_data.name = level
		data[level] = level_data

func get_values(metric:String) -> Array[MetricValue]:
	ensure_level_metrics_exist()
	return data[get_level_key()].get_values(metric)

func add_value(metric:String, value:MetricValue):
	ensure_level_metrics_exist()
	data[get_level_key()].add_value(metric, value)

func add_game_value(metric:String, value:MetricValue):
	data[GAME_KEY].add_value(metric, value)

func overwrite_last_game_value(metric:String, value:MetricValue):
	data[GAME_KEY].overwrite_last_value(metric, value)

#func _on_add_game_event(_name:String):
	#_on_add_game_event_with_payload(_name, {})
#func _on_add_game_event_with_payload(_name:String, payload:Dictionary):
	#data[GAME_KEY].add_event(MetricEvent.create_current(_name, payload))

func overwrite_last_value(metric:String, value:MetricValue):
	ensure_level_metrics_exist()
	data[get_level_key()].overwrite_last_value(metric, value)

func _on_add_event(_name:String):
	_on_add_event_with_payload({}, _name)

func _on_add_event_with_payload(payload:Dictionary,_name:String):
	ensure_level_metrics_exist()
	data[get_level_key()].add_event(MetricEvent.create_current(_name,payload))

#func register_game_event(_signal:Signal):
	#_signal.connect(_on_add_game_event.bind(_signal.get_name()))
#
#func register_game_event_with_payload(_signal:Signal):
	#_signal.connect(_on_add_game_event_with_payload.bind(_signal.get_name()))

func register_event(_signal:Signal):
	_signal.connect(_on_add_event.bind(_signal.get_name()))

func register_event_with_payload(_signal:Signal):
	_signal.connect(_on_add_event_with_payload.bind(_signal.get_name()))
