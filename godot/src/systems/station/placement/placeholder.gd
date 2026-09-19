class_name Placeholder extends Node2D

signal placed(room: StationRoom)


var room: StationRoom
var valid_position: bool

static func create(_room: StationRoom) -> Placeholder:
	var placeholder = Placeholder.new()
	placeholder.room = _room
	placeholder.top_level = true
	placeholder.add_child(_room)
	
	return placeholder

func _ready() -> void:
	assert(room != null)
	room.position = -room.center

func _physics_process(_delta: float) -> void:
	var mouse_position = get_global_mouse_position()
	var offset = room.tile_size * Vector2i(room.rect.size.x % 2, room.rect.size.y % 2) / 2
	var snapped = Vector2i(mouse_position) / room.tile_size * room.tile_size + offset
	
	global_position = snapped
	
	valid_position = room.get_overlapping_areas().is_empty()
	if valid_position:
		modulate = Color.GREEN
	else:
		modulate = Color.RED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			queue_free()
		if event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			placed.emit(room)
