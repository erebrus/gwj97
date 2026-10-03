@tool 
extends SJSkillRelation

@export var wave_speed: float = 1.0
@export var unselected_color: Color
@export var selected_color: Color


func _ready() -> void:
	descendant_selected_changed.connect(_on_descendant_selected_changed)
	_on_descendant_selected_changed()
	material = material.duplicate()


func _on_descendant_selected_changed() -> void:
	var mat := material as ShaderMaterial
	
	if descendant_is_selected:
		default_color = selected_color
		if parent_node.skill.is_bought:
			mat.set_shader_parameter("speed", 0.0)
		else:
			mat.set_shader_parameter("speed", wave_speed)
	else:
		default_color = unselected_color
		mat.set_shader_parameter("speed", 0.0)
		
