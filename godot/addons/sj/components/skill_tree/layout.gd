class_name SJSkillTreeLayout extends Resource

@export var tiers: Array[Array]

var skill_by_id: Dictionary[String, SJSkillTreeSkill]
var skill_children: Dictionary[String, Array]
var skill_requirements: Dictionary[String, Array]

var tier_by_id: Dictionary[String, int]
var lane_by_id: Dictionary[String, int]


static func create(skills: Array[SJSkillTreeSkill]) -> SJSkillTreeLayout:
	var layout := SJSkillTreeLayout.new()
	layout._setup(skills)
	return layout


func _setup(skills: Array[SJSkillTreeSkill]) -> void:
	for skill in skills:
		skill_by_id[skill.id] = skill
		tier_by_id[skill.id] = 0
		_init_string_array_value(skill_children, skill.id)
		_init_string_array_value(skill_requirements, skill.id)
		for req_id in skill.requirements:
			_init_string_array_value(skill_children, req_id)
			skill_children[req_id].append(skill.id)
			skill_requirements[skill.id].append(req_id)
	
	_calculate_base_tier_by_id()
	_add_dummy_skills()
	_calculate_base_lane_by_id()
	_group_by_tier()


func _calculate_base_tier_by_id() -> void:
	for skill: SJSkillTreeSkill in skill_by_id.values():
		tier_by_id[skill.id] = 0
	
	var tier_changed:= true
	while tier_changed:
		tier_changed = false
		for skill: SJSkillTreeSkill in skill_by_id.values():
			for req_id in skill.requirements:
				var new_tier := tier_by_id[req_id] + 1
				if new_tier > tier_by_id[skill.id]:
					tier_by_id[skill.id] = new_tier
					tier_changed = true


func _calculate_base_lane_by_id() -> void:
	# walk from parent to child, grouping
	var current_lane := 0
	for skill: SJSkillTreeSkill in skill_by_id.values():
		if skill_requirements[skill.id].is_empty():
			current_lane = _calculate_base_lane_for_children(skill.id, current_lane)
	
	# walk from child to parent(s), rearranging for 
	
	# repeat N times, or until nothing changes
	pass
	

func _calculate_base_lane_for_children(parent_id: String, current_lane: int) -> int:
	if lane_by_id.has(parent_id):
		print("%s already has lane %s" % [parent_id, lane_by_id[parent_id]])
		return current_lane + 1 # TODO: when 1 is added is wrong in this whole method, but it's late
	
	print("%s lane %s" % [parent_id, current_lane])
	lane_by_id[parent_id] = current_lane
	
	for child_id in skill_children[parent_id]:
		current_lane = _calculate_base_lane_for_children(child_id, current_lane) 
	
	return current_lane + 1 if skill_children[parent_id].is_empty() else current_lane


func _group_by_tier() -> void:
	var max_tier:int = tier_by_id.values().max()
	var max_lane:int = lane_by_id.values().max()
	
	var empty: Array[SJSkillTreeSkill]
	empty.resize(max_lane+1)
	
	tiers.resize(max_tier+1)
	for i in tiers.size():
		tiers[i] = empty.duplicate()
	
	for skill_id in skill_by_id:
		var tier := tier_by_id[skill_id]
		var lane := lane_by_id[skill_id]
		
		assert(tiers[tier][lane] == null)
		tiers[tier][lane] = skill_by_id[skill_id]


func _add_dummy_skills() -> void:
	for skill: SJSkillTreeSkill in skill_by_id.values():
		var requirements: Array[String] = skill.requirements.duplicate()
		var skill_tier:= tier_by_id[skill.id]
		for req in requirements:
			var parent := skill_by_id[req]
			var parent_tier:= tier_by_id[req] 
			
			if skill_tier - parent_tier > 1:
				var child := skill
				for i in range(skill_tier - 1, parent_tier, -1):
					var dummy := child.create_dummy_requirement(parent)
					assert(not dummy.id in skill_by_id)
					skill_by_id[dummy.id] = dummy
					tier_by_id[dummy.id] = i
					
					_init_string_array_value(skill_children, dummy.id)
					skill_children[dummy.id].append(child.id)
					skill_children[parent.id].erase(child.id)
					skill_children[parent.id].append(dummy.id)
					
					_init_string_array_value(skill_requirements, dummy.id)
					skill_requirements[dummy.id].append(parent.id)
					skill_requirements[child.id].erase(parent.id)
					skill_requirements[child.id].append(dummy.id)
					
					child = dummy


func _to_string() -> String:
	return "%s" % [tiers]


static func _init_string_array_value(dictionary: Dictionary, key: Variant) -> void:
	var array: Array[String]
	if not dictionary.has(key):
		dictionary[key] = array
