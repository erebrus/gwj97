@tool
class_name SJSkillTree extends Resource

@export var skills: Array[SJSkill]
@export var dummy_skills: Array[SJSkill]

@export var skill_children: Dictionary[String, Array]
@export var skill_requirements: Dictionary[String, Array]

@export var tier_by_id: Dictionary[String, int]
@export var lane_by_id: Dictionary[String, int]


var _skill_by_id: Dictionary[String, SJSkill]
var _tiers: Array[Array]
var _initialized: bool



func invalidate() -> void:
	_initialized = false
	_skill_by_id.clear()
	_tiers.clear()


## Call after loading from saved layout. Initializes helper properties from exported fields
func setup() -> void:
	if _initialized:
		return
	
	for skill in skills:
		if not tier_by_id.has(skill.id):
			assert(false, "Trying to load SJSkillTree with invalid skills")
			return
	
	for skill in skills:
		_skill_by_id[skill.id] = skill
	
	for dummy in dummy_skills:
		_skill_by_id[dummy.id] = dummy
	
	for skill: SJSkill in _skill_by_id.values():
		skill.setup(_skill_by_id)
	
	var max_tier: int = tier_by_id.values().max()
	var max_lane: int = lane_by_id.values().max()
	var empty: Array[SJSkill]
	empty.resize(max_lane + 1)
	_tiers.resize(max_tier + 1)
	
	for i in _tiers.size():
		_tiers[i] = empty.duplicate()
	
	for skill_id in _skill_by_id:
		var tier := tier_by_id[skill_id]
		var lane := lane_by_id[skill_id]
		
		_tiers[tier][lane] = _skill_by_id[skill_id]
	
	_initialized = true


func get_tiers() -> Array[Array]:
	if not _initialized:
		setup()
	
	return _tiers.duplicate(true)


func get_children_chains(parent_id: String) -> Array[Array]:
	if not _initialized:
		setup()
	
	var chains: Array[Array]
	for child_id in skill_children[parent_id]:
		var chain: Array[SJSkill]
		chains.append(chain)
		
		chain.append(_skill_by_id[parent_id])
		chain.append(_skill_by_id[child_id])
		
		while _skill_by_id[child_id].is_dummy:
			assert(skill_children[child_id].size() == 1, "Multiple children per dummy not implemented")
			child_id = skill_children[child_id].front()
			chain.append(_skill_by_id[child_id])
	
	return chains


func _to_string() -> String:
	return "%s" % [_tiers]
