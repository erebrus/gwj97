class_name Dock extends StationRoom
@onready var dock_point: Node2D = $DockPoint

var ship:Player
func _setup_collision() -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass
	#if ship and 
		#
		#else:
			#GSLogger.info("Ship moving too fast, can't dock")

func _input(_event: InputEvent) -> void:
	if ship and Input.is_action_just_pressed("dock"):
		if not ship.autopilot:
			if has_ship_control() :
				ship.autopilot = true
				dock_ship()
		else:
			undock_ship()

			
func _on_dock_area_body_entered(body: Node2D) -> void:
	ship = body as Player

func dock_ship():
	var tween := create_tween()
	tween.tween_property(ship,"global_position",dock_point.global_position, .5)
	tween.parallel().tween_property(ship,"global_rotation",-PI/2,.5)
	await tween.finished
	GSLogger.info("Ship Docked")
	Events.ship_docked.emit()
	ship.unload_cargo(station)
	
func _on_dock_area_body_exited(_body: Node2D) -> void:
	ship = null

func undock_ship():
	ship.autopilot = false
	ship.apply_impulse(4000*Vector2.DOWN)
	Events.ship_undocked.emit()
	
func has_ship_control() -> bool:
	return ship and ship.get_speed() < 50
