class_name RoomButton extends PanelContainer

signal drag_started(offset: Vector2)
signal drag_ended(at: Vector2)
signal pressed(room: StationRoom)

@export var room_scene: PackedScene

var room: StationRoom

var _drag_armed: bool
var _is_dragging: bool
var _drag_offset: Vector2

func _ready() -> void:
	assert(room_scene != null)
	room = room_scene.instantiate()
	%TextureRect.texture = room.texture

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event:= event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_drag_armed = true
			_drag_offset = get_local_mouse_position()
		if not _is_dragging and not mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			pressed.emit(room_scene.instantiate())
	
	if _drag_armed and not _is_dragging and event is InputEventMouseMotion:
		if get_local_mouse_position().distance_squared_to(_drag_offset) > 10:
			_is_dragging = true
			drag_started.emit(_drag_offset)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.is_pressed():
		if _is_dragging:
			drag_ended.emit(get_global_mouse_position())
		_is_dragging = false
		_drag_armed = false
