extends VBoxContainer

var skills: Array[SJSkillTreeSkill]

func _ready() -> void:
	_on_create_button_pressed()


func _create_skill(id: String, ...args: Array) -> SJSkillTreeSkill:
	var skill = SJSkillTreeSkill.new()
	if args.is_empty():
		skill.id = id
	else:
		var parents: Array[String]
		for parent in args:
			if parent is SJSkillTreeSkill:
				parents.append(parent.id)
			
		skill.requirements = parents
		
		skill.id = "%s_%s" % [".".join(parents), id]
		
	
	return skill

func _on_create_button_pressed() -> void:
	var skillA = _create_skill("a")
	var skillB = _create_skill("b")
	var skillC = _create_skill("c")
	
	var skillA1 = _create_skill("1", skillA)
	
	var skillAB1 = _create_skill("1", skillA, skillB)
	
	var skillB1 = _create_skill("1", skillB)
	var skillB2 = _create_skill("2", skillB)
	
	var skillC1 = _create_skill("1", skillC)
	var skillC2 = _create_skill("2", skillC)
	
	var skillB11 = _create_skill("1", skillB1)
	var skillB12 = _create_skill("2", skillB1)
	
	var skillC1B11 = _create_skill("1", skillC, skillB1)
	
	skills = [
		skillA, skillB, skillC, 
		skillA1, skillAB1, skillB1, skillB2, skillC1, skillC2, 
		skillB11, skillB12, skillC1B11
	]
	skills.shuffle()
	%SkillTree.skills = SJSkillTreeLayout.create(skills)

func _on_shuffle_button_pressed() -> void:
	skills.shuffle()
	%SkillTree.skills = SJSkillTreeLayout.create(skills)
