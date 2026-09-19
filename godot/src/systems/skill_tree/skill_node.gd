@tool
class_name SkillNode extends PanelContainer


signal transform_changed


@export var skill: SkillTreeSkill:
	set(value):
		if value == skill:
			return
		skill = value
		if is_node_ready():
			setup()


@warning_ignore("shadowed_variable")
static func create(skill: SkillTreeSkill) -> SkillNode:
	var scene := load("uid://2idmm87adajf").instantiate() as SkillNode
	scene.skill = skill
	return scene


func _ready() -> void:
	set_notify_transform(true)
	
	if get_tree().current_scene == self:
		skill = SkillTreeSkill.create_random("nice skill")
	
	assert(skill != null)
	setup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		transform_changed.emit()


func setup() -> void:
	%Icon.texture = skill.icon
	%Name.text = skill.name
	
	var container := %PriceContainer
	for child in container.get_children():
		child.queue_free()
	
	for resource in skill.price:
		var label := ResourceLabel.create(resource, skill.price[resource])
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
		container.add_child(label)
