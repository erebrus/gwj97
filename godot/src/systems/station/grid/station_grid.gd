class_name StationGrid extends Sprite2D

var placeholder: Placeholder = null:
	set(value):
		if value == null:
			return
		placeholder = value
		placeholder.tree_exited.connect(_on_placeholder_freed)
		material.set_shader_parameter("alpha_value", 1)

func _process(_delta: float) -> void:
	if not is_instance_valid(placeholder):
		return
	
	# TODO: camera position

func _input(event):
	if event is InputEventMouseMotion and is_instance_valid(placeholder):
		var mouse_pos: Vector2 = get_global_mouse_position()
		var mouse_offset = mouse_pos - global_position
		var viewport_rect: Vector2 = get_viewport_rect().size
		var circle_pos: Vector2 = Vector2(.5, .5) + Vector2((mouse_offset.x) / viewport_rect.x, (mouse_offset.y) / viewport_rect.y)
		material.set_shader_parameter("circle_position", circle_pos)
		material.set_shader_parameter("valid_placement", placeholder.valid_position)
		

func _on_placeholder_freed() -> void:
	material.set_shader_parameter("alpha_value", 0)
