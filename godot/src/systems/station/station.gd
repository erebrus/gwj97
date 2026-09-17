class_name Station extends Node2D

@onready var rooms: Node2D = $Rooms


var resources:Dictionary[Types.Resources, int] = {
	Types.Resources.ORE:5, #TODO const
	Types.Resources.ETHERIUM:1,	
	Types.Resources.POWER:0
}


func _ready() -> void:
	Events.unsuccessful_production.connect(func(r:StationRoom): GSLogger.info("%s can't produce. Missing requirements." % [r.name]))
	for child in get_children():
		if child is StationRoom:
			add_room(child as StationRoom)
		
		
func add_room(room: StationRoom):
	room.reparent(rooms)
	room.station = self
func do_power_production():
	for room:StationRoom in rooms.get_children():
		if room.can_produce_power() and room.activated:
			room.do_production()

func do_other_production():
	for room:StationRoom in rooms.get_children():
		if not room.can_produce_power() and room.activated:
			room.do_production()
						
func _on_timer_timeout() -> void:
	resources[Types.Resources.POWER] = 0
	do_power_production()
	do_other_production()
	Events.request_hud_update.emit()

func has_resources(_resources:Dictionary[Types.Resources, int]) -> bool:
	if _resources.is_empty():
		return true
	for type:Types.Resources in _resources.keys():
		if _resources[type] > resources[type]:
			return false
	return true

func consume_resources(_resources:Dictionary[Types.Resources, int]) -> bool:
	if _resources.is_empty():
		return true
	if not has_resources(_resources):
		return false
	for type:Types.Resources in _resources.keys():
		resources[type] -= _resources[type]

	return true

func add_resources(_resources:Dictionary[Types.Resources, int]):
	for type:Types.Resources in _resources.keys():
		resources[type] += _resources[type]
	
func get_total_power_production()->int:
	var sum := 0
	for room:StationRoom in rooms.get_children():
		if room.can_produce_power() and room.activated:
			sum += room.production_output[Types.Resources.POWER]
	return sum

func get_total_power_consumption() -> int:
	var sum := 0
	for room:StationRoom in rooms.get_children():
		if  Types.Resources.POWER in room.requirements and room.activated:
			sum += room.requirements[Types.Resources.POWER]
			
	return sum
