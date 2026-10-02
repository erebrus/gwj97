@tool
@abstract class_name SJSkillTreeLayoutGenerator extends RefCounted


var _skill_by_id: Dictionary[String, SJSkill]



@abstract func generate(tree: SJSkillTree) -> void


## Clears everything generation owns and rebuilds skill_by_id and the canonical
## skill_children/skill_requirements maps from tree.skills and each skill's own
## requirements. Those maps get mutated with dummy entries during generation, so every
## run has to start from the canonical requirements, not from a previous run's leftovers.
func _reset_topology(tree: SJSkillTree) -> void:
	tree.invalidate()
	tree.dummy_skills.clear()
	tree.skill_children.clear()
	tree.skill_requirements.clear()
	tree.tier_by_id.clear()
	tree.lane_by_id.clear()
	_skill_by_id.clear()
	
	for skill in tree.skills:
		_skill_by_id[skill.id] = skill
		tree.tier_by_id[skill.id] = 0
		_init_string_array_value(tree.skill_children, skill.id)
		_init_string_array_value(tree.skill_requirements, skill.id)
		for req_id in skill.requirements:
			_init_string_array_value(tree.skill_children, req_id)
			tree.skill_children[req_id].append(skill.id)
			tree.skill_requirements[skill.id].append(req_id)
	
	for skill in tree.skills:
		skill.setup(_skill_by_id)


static func _init_string_array_value(dictionary: Dictionary, key: Variant) -> void:
	var array: Array[String]
	if not dictionary.has(key):
		dictionary[key] = array
