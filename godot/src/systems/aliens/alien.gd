class_name Alien extends CharacterBody2D

signal acquired_target
signal lost_target

@export var speed := 200
@export var max_hp := 40.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var fsm: FSM = $FSM
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var hp
var target:Player
#var target_pos:Vector2
func _ready() -> void:
	hp = max_hp
	await get_tree().physics_frame
	set_target_position(Globals.game.get_level().station.global_position)
	nav.max_speed = speed
func _physics_process(delta: float) -> void:
	fsm.do_update(delta)
	var desired_direction = (nav.get_next_path_position() - global_position).normalized()

	
	rotation=desired_direction.angle()
	var new_velocity = desired_direction * speed
	nav.velocity = new_velocity
	#var target_angle = velocity.angle()
	#if abs(angle_difference(rotation, target_angle)) < PI/60:
		#rotation = target_angle
	#else:
		#rotation=lerp_angle(rotation, target_angle, .05)
		#velocity = Vector2.RIGHT.rotated(rotation) * velocity.length()
	#move_and_slide()

func is_target_in_sight()->bool:
	return is_instance_valid(target)
	
func _on_area_2d_body_entered(body: Node2D) -> void:
	target = body as Player
	acquired_target.emit()


func _on_area_2d_body_exited(body: Node2D) -> void:
	target = null
	lost_target.emit()
	set_target_position(Globals.game.get_level().station.global_position)

func set_target_position(pos:Vector2i):
	#target_pos = pos
	nav.target_position = pos


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	
	var target_angle = safe_velocity.angle()
	if abs(angle_difference(rotation, target_angle)) < PI/30:
		rotation = target_angle
		#velocity = safe_velocity
	elif abs(angle_difference(rotation, target_angle)) < PI/6:
		rotation=lerp_angle(rotation, target_angle, .01)
		#velocity = safe_velocity.normalized()*speed*.5 #Vector2.RIGHT.rotated(rotation) * speed*.2
	else:
		rotation = lerp_angle(rotation, target_angle, .1)
		#velocity = safe_velocity.normalized()*speed*.5 #Vector2.RIGHT.rotated(rotation) * speed*.05
	velocity = safe_velocity

	move_and_slide()
	
func take_damage(damage:float):
	hp -= damage
	if hp <=0:
		queue_free()
	
