class_name Laser extends Line2D
const _SCENE:PackedScene = preload("laser.tscn")

var power:float = 1

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
	var collision:Dictionary = get_collision(start, end)
	var collision_point:Vector2 = collision.position if collision else end
	set_point_position(0, start - global_position)
	set_point_position(1, collision_point - global_position)
	if collision and collision.collider.has_method("take_damage"):
		collision.collider.take_damage(power)
		
	visible = true


func _on_laser_cancelled():
	cancelling = true


static func create(power:float)->Laser:
	var ret:Laser = _SCENE.instantiate()
	ret.power = power
	return ret
