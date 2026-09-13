class_name LevelMetrics extends Resource

@export
var name:String
@export
var values:Dictionary[String, Array]
@export
var events:Array[MetricEvent]

static func create_from_dict(state:Dictionary)->LevelMetrics:
	var ret := LevelMetrics.new()
	ret.name = state.level
	ret.events.assign (state.events.map(func(x:Dictionary): return MetricEvent.create_from_dict(x)))
	ret._set_values_state(state.values)
	return ret

func get_state()->Dictionary:
	return {
		"level": name,
		"values": _get_values_state(),
		"events": events.map(func(x:MetricEvent):return x.get_state())
	}

func _set_values_state(values_state:Dictionary):
	values = {}
	for metric in values_state:
		if not metric in values:
			values[metric] = []
		for state_value:Dictionary in values_state[metric]:
			values[metric].append(MetricValue.create_from_dict(state_value))

func _get_values_state()->Dictionary:
	var ret:={}
	for metric in values:
		ret[metric]=values[metric].map(func(x:MetricValue):return x.get_state())
	return ret

func get_values(metric:String)->Array[MetricValue]:
	var result:Array[MetricValue]
	if metric in values:
		result.assign(values[metric])
	return result


func add_event(event:MetricEvent):
	events.append(event)

func ensure_values(metric:String):
	if not metric in values:
		values[metric] = []
		
func add_value(metric:String, value:MetricValue):
	ensure_values(metric)
	values[metric].append(value)
func overwrite_last_value(metric:String, value:MetricValue):
	ensure_values(metric)
	if values[metric].is_empty():
		add_value(metric, value)
	else:
		values[metric][-1] = value
