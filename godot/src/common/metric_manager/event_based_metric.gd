class_name EventBasedMetric extends Metric

@export var event_name:String
@export var keep_all:bool
func setup(_manager:MetricsManager) -> void:
	super.setup(_manager)
	MetricsEvents.connect(event_name, _on_event)
	if not MetricsEvents.is_connected(event_name, _on_event):
		GSLogger.warn("Failed to connect metrics signal:%s" % [event_name])

func _on_event():
	var values = manager.get_values(name)
	var new_val:MetricValue = MetricValue.create_current( (0 if values.is_empty() else values[-1].value) + 1)
	if keep_all or values.is_empty():
		manager.add_value(name, new_val)
	else:
		manager.overwrite_last_value(name, new_val)
