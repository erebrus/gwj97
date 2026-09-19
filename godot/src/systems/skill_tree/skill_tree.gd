@tool 
class_name StationSkillTree extends SJSkillTree

@export_tool_button("Random debug tree") var create_debug_tree = _create_debug_tree


func _ready() -> void:
	if get_tree().current_scene == self:
		_create_debug_tree()
	
	super._ready()


func _create_debug_tree() -> void:
	var skillA = StationSkill.create_random("a")
	var skillB = StationSkill.create_random("b")
	var skillC = StationSkill.create_random("c")
	
	var skillA1 = StationSkill.create_random("1", skillA)
	var skillAB1 = StationSkill.create_random("1", skillA, skillB)
	var skillB1 = StationSkill.create_random("1", skillB)
	var skillB2 = StationSkill.create_random("2", skillB)
	var skillC1 = StationSkill.create_random("1", skillC)
	var skillC2 = StationSkill.create_random("2", skillC)
	
	var skillB11 = StationSkill.create_random("1", skillB1)
	var skillB12 = StationSkill.create_random("2", skillB1)
	
	var skillC1B11 = StationSkill.create_random("1", skillC, skillB1)
	
	
	var all_skills: Array[SJSkillTreeSkill] = [
		skillA, skillB, skillC, 
		skillA1, skillAB1, skillB1, skillB2, skillC1, skillC2, 
		skillB11, skillB12, skillC1B11
	]
	all_skills.shuffle()
	
	skills =  SJSkillTreeLayout.create(all_skills)
	print(skills)
