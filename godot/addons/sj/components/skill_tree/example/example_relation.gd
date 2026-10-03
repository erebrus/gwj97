@tool
extends SJSkillRelation


func _on_descendant_selected_changed() -> void:
	default_color = Color.RED if descendant_is_selected else Color.WHITE
