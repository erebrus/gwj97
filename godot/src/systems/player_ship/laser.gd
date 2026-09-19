class_name Laser extends Line2D
const _SCENE:PackedScene = preload("laser.tscn")

var rng:float = 500
var power:float = 1
var last_actual_length := 1.0
var length := 1.0
var len_tween:Tween
var last_collided := false
@onready var contact_point: Polygon2D = $ContactPoint

var progress:=0.01:
	set(_v):
		progress = _v
		(material as ShaderMaterial).set_shader_parameter("progress",_v)

var cancelling := false

func _ready():
	Events.laser_position_updated.connect(_on_laser_position_updated)
	Events.laser_cancelled.connect(_on_laser_cancelled)
	visible = false
	progress = .01
	len_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	len_tween.tween_property(self,"length",rng,.3)
func _physics_process(delta: float) -> void:
	if not cancelling:
		progress = min(1,progress + delta * 2 )
	else:
		progress = max(0,progress - delta * 4)
		if progress == 0:
			queue_free()

func get_collision(start:Vector2, end:Vector2):
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(start,end)
	query.collision_mask = LayerNames.PHYSICS_2D.WORLD + LayerNames.PHYSICS_2D.ENEMIES
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	#GSLogger.info("Collision laser %s -> %s = %s" % [start,end,hit])
	return hit

func _on_laser_position_updated(start:Vector2, end:Vector2):
	var vec:=(end-start).limit_length(length)
	GSLogger.trace("Laser length:%2f" % vec.length())
	end = start + vec 
	
	var collision:Dictionary = get_collision(start, end)
	if collision.is_empty() and last_collided:
		# we need to restart the tween
		len_tween.stop()
		length = last_actual_length
		end = start + vec.limit_length(last_actual_length)
		#GSLogger.info("restarting laser tween from %2f to %2f" % [last_actual_length])
		len_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
		len_tween.tween_property(self,"length",rng,remap(rng - length,0, rng,0,.3))
		
	var collision_point:Vector2 = collision.position if collision else (end + vec.normalized()*randf_range(-5,5))
	set_point_position(0, start - global_position)
	set_point_position(1, collision_point - global_position)
	if collision:
		if collision.collider.has_method("take_damage"):
			collision.collider.take_damage(power)
		last_collided = not collision.is_empty()
		last_actual_length = (collision_point - start).length()
	else:
		last_collided = false
		last_actual_length = length
	contact_point.global_position = collision_point
	visible = true
	
	
func _on_laser_cancelled():
	cancelling = true


static func create(_power:float, _rng:float)->Laser:
	var ret:Laser = _SCENE.instantiate()
	ret.power = _power
	ret.rng = _rng
	return ret
