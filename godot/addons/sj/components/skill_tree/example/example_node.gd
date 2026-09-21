extends SJSkillNode


func setup() -> void:
	super.setup()
	%Name.text = "%s [%s]" % [skill.id, ",".join(skill.requirements)]
