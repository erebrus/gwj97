class_name Player extends RigidBody2D

@export var impulse_force:float = 50000.0
@export var backup_impulse_force:float = 100
@export var fuel_consumption = 1
@export var max_fuel = 100
@export var laser_power:float = 1
@export var laser_range:float = 300
@export var laser_thrust: float = 5000
@export var attraction_range:float = 50
@export var attaction_power:float = 50.0
@export var max_cargo:=4
@export var boost_thrust = 200000

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
@onready var turbo_timer: Timer = $TurboTimer

@onready var collection_area: Area2D = $CollectionArea
@onready var backup_damp = linear_damp

var damp_null_enabled := false:
	set(_v):
		damp_null_enabled = _v
		if is_node_ready():
			if _v:
				linear_damp = 0
			else:
				_start_damp_recovery()
@onready
var damp_tween:Tween
	
var turbo_available := true
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
	await get_tree().physics_frame
	Events.ship_init_completed.emit(self)
func _on_out_of_fuel():
	sfx_out_of_fuel.play()
	
func _on_thrust_stopped():
	thrust_on = false

func _on_thrust_requested():
	thrust_on = true
	
func unload_cargo(station:Station):
	if not cargo.is_empty():
		station.add_resources(cargo)
		cargo = {
			Types.Resources.ORE: 0,
			Types.Resources.ETHERIUM : 0
		}
		GSLogger.info("Unloaded cargo")
	Events.cargo_updated.emit(cargo)
	collection_area.set_deferred("monitoring", true)


func _physics_process(_delta):
	if Globals.game.control != Game.MouseControl.Ship:
		return
	_set_target_angle()
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
			_do_laser()

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
	
func do_turbo():
	
	var impulse = Vector2.RIGHT.rotated(rotation)*-(boost_thrust)
	apply_central_impulse(impulse)
	#if not damp_null_enabled:
	linear_damp = 0
		#_start_damp_recovery()
	
	turbo_available = false
	turbo_timer.start()

func _start_damp_recovery():
	#if damp_tween:
		#await damp_tween.finished
		#damp_tween = null
	#damp_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	#damp_tween.tween_property(self, "linear_damp", backup_damp, .5)
	linear_damp = backup_damp
	
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
	if Input.is_action_just_pressed("turbo"):
		do_turbo()
	var should_stop_damp := Input.is_action_pressed("damp_null")
	if not damp_null_enabled and should_stop_damp or (damp_null_enabled and not should_stop_damp):
		damp_null_enabled = should_stop_damp
		
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

func _do_laser():
	var vec := (get_global_mouse_position() - global_position). normalized()*(laser_range)
	Events.laser_position_updated.emit(global_position, global_position + vec)
	laser.visible = true
	var impulse = Vector2.RIGHT.rotated(rotation)*(laser_thrust)
	apply_force(impulse)
func _shoot_laser():
	if not laser:
		laser = Laser.create(laser_power, laser_range)
		laser.global_position = muzzle.global_position
		get_parent().add_child(laser)
	_do_laser()


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
	Events.cargo_updated.emit(cargo)
	GSLogger.debug("Cargo collected")
		

func is_cargo_full()->bool:
	var sum = 0
	for key in cargo.keys():
		sum += cargo[key]
	return sum >= max_cargo


	

func get_speed()->float:
	return linear_velocity.length()

func _on_attraction_area_body_entered(body: Node2D) -> void:
	if body is Cargo and not body in target_cargo:
		target_cargo.append(body as Cargo)

func _on_attraction_area_body_exited(body: Node2D) -> void:
	if body is Cargo:
		var _cargo:Cargo = body as Cargo
		while _cargo in target_cargo:
			target_cargo.erase(_cargo)


func _on_turbo_timer_timeout() -> void:
	turbo_available = true
	if not damp_null_enabled:
		_start_damp_recovery()
