@tool
class_name StationSkillNode extends SJSkillNode


func setup() -> void:
	super.setup()
	if skill.is_dummy:
		return
	
	var station_skill := skill as StationSkill
	
	%Icon.texture = station_skill.icon
	%Name.text = station_skill.name
	
	var container := %PriceContainer
	for child in container.get_children():
		child.queue_free()
	
	for resource in station_skill.price:
		var label := ResourceLabel.create(resource, skill.price[resource])
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
		container.add_child(label)
