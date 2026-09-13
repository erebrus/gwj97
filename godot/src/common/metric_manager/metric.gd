class_name Metric extends Resource

enum Type {
	DISCRETE,
	CONTINUOUS
}

enum Scope {
	GAME,
	RUN,
	LEVEL_PERSIST,
	LEVEL,
}

@export var name:String
@export var listed:bool = true
@export var type := Type.DISCRETE
@export var scope := Scope.LEVEL

var manager:MetricsManager
func setup(_manager:MetricsManager) -> void:
	manager = _manager
	
func get_state()->Dictionary:
	return {
		"name":name,
		"type":type,
		"scope":scope,
	}

func update_value(game:Game):
	pass
	
func set_state(state:Dictionary):
	name = state.name
	type = state.type
	scope = state.scope

func _to_string() -> String:
	return "Metric: %s" % name
