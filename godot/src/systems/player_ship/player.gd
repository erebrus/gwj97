class_name Player extends RigidBody2D

@export var impulse_force:float = 1000.0
@export var backup_impulse_force:float = 100
@export var fuel_consumption = 1
@export var max_fuel = 100
@export var laser_power:float = 1
@export var laser_range:float = 100
@export var attraction_range:float = 50
@export var attaction_power:float = 50.0
@export var max_cargo:=4

var thrust_on:bool = false

var target_angle:float
var target_point:Vector2

@onready var sfx_out_of_fuel: AudioStreamPlayer2D = $sfx/sfx_out_of_fuel
@onready var sprite: Sprite2D = $Sprite2D

@onready
var fuel = max_fuel
@onready var rotation_guide: Node2D = $RotationGuide
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle: Node2D = $Muzzle
@onready var attraction_collision_shape_2d: CollisionShape2D = $AttractionArea/CollisionShape2D

@onready var collection_area: Area2D = $CollectionArea

var autopilot:bool :
	set(_v):
		autopilot = _v
		if autopilot:
			if thrust_on:
				_stop_thrust()
			linear_velocity = Vector2.ZERO
			angular_velocity = 0
			freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
			freeze = true
			Events.control_state_changed.emit(Game.MouseControl.Station)

		else:
			freeze = false
			Events.control_state_changed.emit(Game.MouseControl.Ship)
			
var laser:Laser

var target_cargo:Array[Cargo]
var cargo:Dictionary[Types.Resources, int] = {
	Types.Resources.ORE: 0,
	Types.Resources.ETHERIUM : 0
}
# Called when the node enters the scene tree for the first time.
func _ready():
	Events.thrust_requested.connect(_on_thrust_requested)
	Events.thrust_stopped.connect(_on_thrust_stopped)
	#Events.shoot_requested.connect(_on_shoot_requested)
	_on_timer_timeout()
	Events.out_of_fuel.connect(_on_out_of_fuel)
	attraction_collision_shape_2d.shape.radius =  attraction_range
	
func _on_out_of_fuel():
	sfx_out_of_fuel.play()
	
func _on_thrust_stopped():
	thrust_on = false

func _on_thrust_requested():
	thrust_on = true
	
func unload_cargo(station:Station):
	if not cargo.is_empty():
		station.add_resources(cargo)
		cargo.clear()
		GSLogger.info("Unloaded cargo")
		
func _physics_process(_delta):
	if Globals.game.control != Game.MouseControl.Ship:
		return
	if abs(angle_difference(rotation, target_angle)) < PI/60:
		rotation = target_angle
	else:
		rotation=lerp_angle(rotation, target_angle, .05)
	if thrust_on:
		var impulse = Vector2.RIGHT.rotated(rotation)*-(impulse_force if has_fuel() else backup_impulse_force)
		apply_force(impulse)
		if has_fuel():
			Events.fuel_consumed.emit(fuel_consumption)
		else:
			GSLogger.trace("Out of fuel.")
	if is_instance_valid(laser):
			var laser_len = min((get_global_mouse_position() - global_position).length(), laser_range)			
			Events.laser_position_updated.emit(global_position, 
				global_position + Vector2.LEFT.rotated(rotation) * laser_len)

	_rotate_sprite()
	collect_cargo()

func collect_cargo():
	if not is_cargo_full():
		for c:Cargo in target_cargo:
			if is_instance_valid(c):
				c.attract_to(global_position, attaction_power)
			
func has_fuel()->bool:
	return true
	#return fuel > 0
	
func _rotate_sprite() -> void:
	pass
	#var discrete_rotation = GameUtils.force_angle_precision(rotation - PI / 4 - PI / 8, PI/2)
	#var discrete_rotation_half = GameUtils.force_angle_precision(rotation - PI / 2, PI/4)
	#
	#var frame_num = posmod(discrete_rotation_half / (PI / 4), 2)
	#sprite.frame = frame_num * 2
	#
	#sprite.rotation = -rotation + discrete_rotation
##	crush_sprite.rotation = sprite.rotation + deg_to_rad(135) TODO restore crush animation
	#rotation_guide.rotation = -rotation
	

func _set_target_angle():
	var pos = get_global_mouse_position()
	target_angle = pos.angle_to_point(global_position)

func _start_thrust():
	GSLogger.info("thrust start")
	thrust_on = true
	_set_target_angle()
	animation_player.play("thrust_start")
	await animation_player.animation_finished
	if thrust_on:
		animation_player.play("thrust")

func _stop_thrust():
	GSLogger.info("thrust stop")
	thrust_on = false
	animation_player.play("thrust_stop") 
	
func _input(event):
	if Globals.game.control != Game.MouseControl.Ship:
		return
		
	if event is InputEventMouseMotion:
		_set_target_angle()
		return
	if event is InputEventMouseButton:
		var m_event:InputEventMouseButton = event as InputEventMouseButton
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not thrust_on and m_event.pressed:
				_start_thrust()				
			elif thrust_on and not m_event.pressed:
				_stop_thrust()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if m_event.pressed:
				_shoot_laser()
			else:
				_stop_laser()


func _shoot_laser():
	if not laser:
		laser = Laser.create(laser_power)
		laser.global_position = muzzle.global_position
		get_parent().add_child(laser)

	var vec := (get_global_mouse_position() - global_position).limit_length(laser_range)
	Events.laser_position_updated.emit(global_position, global_position + vec)
	laser.visible = true

func _stop_laser():
	Events.laser_cancelled.emit()
func _on_timer_timeout():
	Events.player_position_updated.emit(global_position)


func crush():
	GSLogger.info("player crushed.")
	sprite.visible = false
	# TODO restore crush animation
	# crush_sprite.visible = true
	# animation_player.play("crush") 
	sleeping=true
	#crushed_sound.play()
	#await animation_player.animation_finished	
	Events.game_over.emit()
	


func _on_collection_area_body_entered(body: Node2D) -> void:
	cargo[body.type] += 1
	body.queue_free()
	if is_cargo_full():
		collection_area.set_deferred("monitoring", false)
	
	GSLogger.debug("Cargo collected")
		

func is_cargo_full()->bool:
	var sum = 0
	for key in cargo.keys():
		sum += cargo[key]
	return sum >= max_cargo

func unload():
	#TODO unload
	cargo = {
		Types.Resources.ORE: 0,
		Types.Resources.ETHERIUM : 0
	}
	collection_area.monitoring = true
	

func get_speed()->float:
	return linear_velocity.length()

func _on_attraction_area_body_entered(body: Node2D) -> void:
	if body is Cargo and not body in target_cargo:
		target_cargo.append(body as Cargo)

func _on_attraction_area_body_exited(body: Node2D) -> void:
	if body is Cargo:
		var cargo:Cargo = body as Cargo
		while cargo in target_cargo:
			target_cargo.erase(cargo)
