class_name BaseLevel extends Node2D

@export var override_game_state: GameState


var game_state:GameState

var placeholder: Placeholder
@onready var station: Station = $Station

@onready var grid: StationGrid = %StationGrid
@onready var player_camera: Camera2D = $Player/Camera2D
@onready var overview_camera: Camera2D = $Camera2D

func _ready() -> void:
	for child: Control in %RoomButtons.get_children():
		if child is RoomButton:
			child.pressed.connect(_on_room_button_pressed)
	Events.on_camera_mode_changed.connect(_on_on_camera_mode_changed)

func _on_on_camera_mode_changed(overview:bool):
	player_camera.enabled = not overview
	overview_camera.enabled = overview

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
	station.add_room(room)
	if is_instance_valid(placeholder):
		placeholder.queue_free()
