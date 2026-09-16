class_name Asteroid extends RigidBody2D
@export
var angular_speed_interval:Vector2 = Vector2(0.1,.5)

@export 
var structure:float = 100
@export 
var type := Types.Mineral.ORE
@export
var mineral_count := 5

func _ready():
	angular_velocity = randf_range(angular_speed_interval.x, angular_speed_interval.y)
	GSLogger.debug("%s angular velocity = %2f" % [name, angular_velocity])

func take_damage(damage:float):
	structure -= damage
	GSLogger.debug("%s takes damage. Structure = %2f" % [name, structure])
	if structure < 0:
		destroy()
		
func destroy():
	for i in range(mineral_count):
		var c:Cargo = Cargo.create(type)
		c.global_position = Vector2(global_position.x + randf_range(-15,15), global_position.y + randf_range(-15,15))
		c.linear_velocity = Vector2(randf_range(-2,2),randf_range(-2,2) )
		get_parent().add_child(c)
	queue_free()
