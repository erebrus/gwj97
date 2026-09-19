class_name SJSkillTreeSkill extends Resource

@export var id: String
@export var requirements: Array[String]

@export var is_dummy: bool = false


func create_dummy_requirement(parent: SJSkillTreeSkill) -> SJSkillTreeSkill:
	var dummy = SJSkillTreeSkill.new()
	if parent.is_dummy:
		var i = parent.id.rfind("_")
		var parent_name = parent.id.substr(0, i)
		var suffix = parent.id.substr(i)
		var count = int(suffix) + 1
		dummy.id = parent_name + "_%s" % count
	else:
		dummy.id = parent.id + "_dummy_1"
	
	dummy.is_dummy = true
	dummy.requirements.append(parent.id)
	
	return dummy


func _to_string() -> String:
	return id
