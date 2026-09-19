class_name SkillTreeLayout extends Resource

@export var tiers: Array[Array]

var skill_by_id: Dictionary[String, SkillTreeSkill]
var skill_children: Dictionary[String, Array]
var tier_by_id: Dictionary[String, int]
var lane_by_id: Dictionary[String, int]


static func create(skills: Array[SkillTreeSkill]) -> SkillTreeLayout:
	var layout := SkillTreeLayout.new()
	layout._setup(skills)
	return layout


func _setup(skills: Array[SkillTreeSkill]) -> void:
	for skill in skills:
		skill_by_id[skill.id] = skill
		tier_by_id[skill.id] = 0
		_init_string_array_value(skill_children, skill.id)
		for req_id in skill.requirements:
			_init_string_array_value(skill_children, req_id)
			skill_children[req_id].append(skill.id)
	
	_calculate_base_tier_by_id()
	_calculate_base_lane_by_id()
	
	var max_tier:int = tier_by_id.values().max()
	var max_lane:int = lane_by_id.values().max()
	
	var empty: Array[SkillTreeSkill]
	empty.resize(max_lane+1)
	
	tiers.resize(max_tier+1)
	for i in tiers.size():
		tiers[i] = empty.duplicate()
	
	for skill_id in skill_by_id:
		var tier := tier_by_id[skill_id]
		var lane := lane_by_id[skill_id]
		
		assert(tiers[tier][lane] == null)
		tiers[tier][lane] = skill_by_id[skill_id]


func _calculate_base_tier_by_id() -> void:
	for skill: SkillTreeSkill in skill_by_id.values():
		tier_by_id[skill.id] = 0
	
	var tier_changed:= true
	while tier_changed:
		tier_changed = false
		for skill: SkillTreeSkill in skill_by_id.values():
			for req_id in skill.requirements:
				var new_tier := tier_by_id[req_id] + 1
				if new_tier > tier_by_id[skill.id]:
					tier_by_id[skill.id] = new_tier
					tier_changed = true


func _calculate_base_lane_by_id() -> void:
	# walk from parent to child, grouping
	var current_lane := 0
	for skill: SkillTreeSkill in skill_by_id.values():
		if skill.requirements.is_empty():
			current_lane = _calculate_base_lane_for_children(skill.id, current_lane)
	
	# walk from child to parent(s), rearranging for 
	
	# repeat N times, or until nothing changes
	pass
	

func _calculate_base_lane_for_children(parent_id: String, current_lane: int) -> int:
	if lane_by_id.has(parent_id):
		print("%s already has lane %s" % [parent_id, lane_by_id[parent_id]])
		return current_lane
	
	print("%s lane %s" % [parent_id, current_lane])
	lane_by_id[parent_id] = current_lane
	
	for child_id in skill_children[parent_id]:
		current_lane = _calculate_base_lane_for_children(child_id, current_lane) 
	
	return current_lane + 1 if skill_children[parent_id].is_empty() else current_lane


func _to_string() -> String:
	return "%s" % [tiers]


static func _init_string_array_value(dictionary: Dictionary, key: Variant) -> void:
	var array: Array[String]
	if not dictionary.has(key):
		dictionary[key] = array
