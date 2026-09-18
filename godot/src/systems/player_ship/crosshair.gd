class_name Crosshair extends Node2D

@export var ship:Player



func _ready():
	assert(ship)
	
func _physics_process(delta: float) -> void:
	var start:=ship.global_position
	var len = min((get_global_mouse_position() - start).length(), ship.laser_range)
	global_position = ship.global_position + Vector2.LEFT.rotated(ship.rotation) * len
	
