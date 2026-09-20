@tool
class_name SJSkillNode extends MarginContainer


signal transform_changed


@export var skill: SJSkill:
	set(value):
		if value == skill:
			return
		skill = value
		if is_node_ready():
			setup()


func _ready() -> void:
	set_notify_transform(true)
	setup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		transform_changed.emit()


func setup() -> void:
	modulate.a = 0 if skill.is_dummy else 1
	
