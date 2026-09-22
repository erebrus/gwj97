extends VBoxContainer

var skills: Array[SJSkill]

func _ready() -> void:
	_on_create_button_pressed()


func _create_skill(...args: Array) -> SJSkill:
	var skill = SJSkill.new()
	skill.id = char(65+skills.size())
	
	if not args.is_empty():
		var parents: Array[String]
		for parent in args:
			if parent is SJSkill:
				parents.append(parent.id)
			
		skill.requirements = parents
	
	skills.append(skill)
	return skill

func _create_subtree(skillA: SJSkill, skillB: SJSkill, skillC: SJSkill) -> Array[SJSkill]:
	var skillA1 = _create_skill(skillA)
	
	var skillAB1 = _create_skill(skillA, skillB)
	
	var skillB1 = _create_skill(skillB)
	var skillB2 = _create_skill(skillB)
	
	var skillC1 = _create_skill(skillC)
	var skillC2 = _create_skill(skillC)
	
	var skillB11 = _create_skill(skillB1)
	var skillB12 = _create_skill(skillB1)
	
	var skillC1B11 = _create_skill(skillC, skillB1)
	
	return [skillB12, skillB11, skillC1B11]


func _on_create_button_pressed() -> void:
	skills.clear()
	
	var skillA = _create_skill()
	var skillB = _create_skill()
	var skillC = _create_skill()
	
	var children = _create_subtree(skillA, skillB, skillC)
	_create_subtree(children[0], children[1], children[2])
	
	%SkillTree.skill_tree = SJSkillTree.create(skills)


func _on_shuffle_button_pressed() -> void:
	skills.shuffle()
	%SkillTree.skill_tree = SJSkillTree.create(skills)
