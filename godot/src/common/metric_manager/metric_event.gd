class_name MetricEvent extends Resource
@export var timestamp:int
@export var turn:int
@export var name:String
@export var data:Dictionary

func _init(_timestamp:int, _turn:int, _name:String, _data:Dictionary) -> void:
	timestamp = _timestamp
	name = _name
	turn = _turn
	data = _data

static func _get_node_y()->int:
	if not (Globals.game and Globals.game.game_state and Globals.game.game_state.run.get_current_sector() and Globals.game.game_state.run.get_current_sector().get_current_node()):
		return -1
	return Globals.game.game_state.run.sectors[Globals.game.game_state.run.current_sector_idx].get_current_node().map_coords.y

static func create_current(_name:String, _data:Dictionary) -> MetricEvent:
	var delta_time = Time.get_ticks_msec() - Globals.metrics_manager.start_time
	
	var _turn := 0
	if Globals.game and Globals.game.get_level():
		_turn = Globals.game.game_state.turn if (Globals.game and Globals.game.game_state) else -1
	else:
		_turn = _get_node_y()
	return MetricEvent.new(delta_time, _turn, _name, _data) 

static func create_from_dict(state:Dictionary)-> MetricEvent:
	var _data = state.data if "data" in state else {}
	return MetricEvent.new(state.timestamp, state.turn, state.name, _data) 
	
func get_state()->Dictionary:
	var ret :={
		"timestamp" : timestamp,
		"turn" : turn,
		"name" : name,
	}
	if not data.is_empty():
		ret["data"] = data
	return ret
func _to_string() -> String:
	return "%s" % [get_state()]
