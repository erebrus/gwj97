class_name BaseLevel extends Node

@export var override_game_state: GameState


var game_state:GameState

var placeholder: Placeholder

@onready var grid: StationGrid = %StationGrid

func _ready() -> void:
	for child: Control in %RoomButtons.get_children():
		if child is RoomButton:
			child.pressed.connect(_on_room_button_pressed)
	

func set_state(_game_state:GameState):
	game_state = _game_state
	

func _on_room_button_pressed(room: StationRoom) -> void:
	if is_instance_valid(placeholder):
		placeholder.queue_free()
	placeholder = Placeholder.create(room)
	placeholder.placed.connect(_on_room_placed)
	grid.placeholder = placeholder
	add_child(placeholder)

func _on_room_placed(room: StationRoom) -> void:
	room.reparent(self)
	if is_instance_valid(placeholder):
		placeholder.queue_free()
