extends Camera2D

@export var speed_interval:Vector2 = Vector2(200.0,500.0)
@export var zoom_interval:Vector2 = Vector2(1, .5)

func _physics_process(_delta: float) -> void:
	var speed := (get_parent() as Player).linear_velocity.length()
	if speed < speed_interval.x:
		zoom = Vector2.ONE * zoom_interval.x
	elif speed > speed_interval.y:
		zoom = Vector2.ONE * zoom_interval.y
	else:
		zoom = Vector2.ONE * remap(speed,speed_interval.x,speed_interval.y, zoom_interval.x, zoom_interval.y)
		
