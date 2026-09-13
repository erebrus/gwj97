class_name MetricValue extends Resource
@export var timestamp:int
@export var turn:int
@export var value:float

func _init(_timestamp:int, _turn:int, _value:float) -> void:
	timestamp = _timestamp
	value = _value
	turn = _turn

static func _get_node_y()->int:
	if not (Globals.game and Globals.game.game_state and Globals.game.game_state.run.get_current_sector() and Globals.game.game_state.run.get_current_sector().get_current_node()):
		return -1
	return Globals.game.game_state.run.get_current_sector().get_current_node().map_coords.y

static func create_current(_value:float) -> MetricValue:
	var delta_time = Time.get_ticks_msec() - Globals.game.metrics_manager.start_time
	
	var _turn := 0
	if Globals.game.get_level():
		_turn = Globals.game.game_state.turn if (Globals.game and Globals.game.game_state) else -1
	else:
		_turn = _get_node_y()
	
	return MetricValue.new(delta_time, _turn, _value) 

static func create_from_dict(state:Dictionary)-> MetricValue:
	return MetricValue.new(state.timestamp, state.turn, state.value) 

func get_state()->Dictionary:
	return {
		"timestamp":timestamp,"turn":turn, "value":value
	}
func _to_string() -> String:
	return "%s" % [value]
