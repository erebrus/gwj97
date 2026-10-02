## Assigns a float lane to every skill using the Brandes-Köpf algorithm. Assumes tier order is
## already fixed by crossing minimization; only assigns lanes, never reorders.
class_name SJSkillTreeLaneAssigner extends RefCounted


var _tree: SJSkillTree
var _tiers: Array[Array]
var _skill_by_id: Dictionary[String, SJSkill]
var _conflicting_edges: Dictionary[String, bool]


func _init(tree: SJSkillTree, tiers: Array[Array], skill_by_id: Dictionary[String, SJSkill]) -> void:
	_tree = tree
	_tiers = tiers
	_skill_by_id = skill_by_id
	_conflicting_edges = _find_long_edge_conflicts()


## Float lane per skill id, balanced across the four sweep/bias candidates.
func balanced_lanes() -> Dictionary[String, float]:
	var candidates := _build_candidates()
	var narrowest := _find_narrowest(candidates)
	
	for candidate in candidates:
		if candidate != narrowest:
			candidate.align_to(narrowest)
	
	return _average_middle_two(candidates)


func _build_candidates() -> Array[_Candidate]:
	var candidates: Array[_Candidate]
	
	for look_upward in [true, false]:
		for mirror in [false, true]:
			var candidate := _Candidate.new(self, look_upward, mirror)
			candidate.build_chains()
			candidate.assign_lanes()
			candidates.append(candidate)
	
	return candidates


func _find_narrowest(candidates: Array[_Candidate]) -> _Candidate:
	var narrowest := candidates[0]
	for i in range(1, candidates.size()):
		if candidates[i].width() < narrowest.width():
			narrowest = candidates[i]
	return narrowest


func _average_middle_two(candidates: Array[_Candidate]) -> Dictionary[String, float]:
	var balanced: Dictionary[String, float]
	
	for skill: SJSkill in _skill_by_id.values():
		var values: Array[float]
		for candidate in candidates:
			values.append(candidate.lane_by_id[skill.id])
		values.sort()
		balanced[skill.id] = (values[1] + values[2]) / 2.0
	
	return balanced


## Marks edges that cross a long edge (a run of edges between dummy skills) so chains skip
## them and long edges stay straight.
func _find_long_edge_conflicts() -> Dictionary[String, bool]:
	var conflicts: Dictionary[String, bool]
	
	for t in range(_tiers.size() - 1):
		var upper: Array[SJSkill] = _tiers[t]
		var lower: Array[SJSkill] = _tiers[t + 1]
		
		var upper_start := 0
		var lower_start := 0
		
		for lower_end in lower.size():
			var skill := lower[lower_end]
			var upper_end := -1
			
			if skill.is_dummy:
				# Dummies can only have a parent
				var parent_id: String = _tree.skill_requirements[skill.id][0]
				if _skill_by_id[parent_id].is_dummy:
					upper_end = _tree.lane_by_id[parent_id]
			
			if upper_end < 0 and lower_end == lower.size() - 1:
				upper_end = upper.size() -1
			
			if upper_end >= 0:
				for l in range(lower_start, lower_end + 1):
					var lower_id := lower[l].id
					for upper_id in _tree.skill_requirements[lower_id]:
						var k:= _tree.lane_by_id[upper_id]
						# Parent is not in the same window
						if k < upper_start or k > upper_end:
							conflicts[_edge_key(upper_id, lower_id)] = true
				
				upper_start = upper_end
				lower_start = lower_end + 1
	
	return conflicts


static func _edge_key(parent_id: String, child_id: String) -> String:
	return "%s|%s" % [parent_id, child_id]


## One candidate layout: a (look_upward, mirror) combination. Skills are first linked into
## chains that should share a lane (build_chains), then each chain gets a lane (assign_lanes);
## the result is lane_by_id. Mirroring lets the same left-biased logic produce the
## right-biased variant.
class _Candidate:
	var look_upward: bool
	var mirror: bool
	
	var lane_by_id: Dictionary[String, float]
	var min_lane: float
	var max_lane: float
	
	var _owner: SJSkillTreeLaneAssigner
	
	var _chain_head_of: Dictionary[String, String]
	var _next_in_chain: Dictionary[String, String]
	
	var _chain_lane: Dictionary[String, float]
	
	## Chains packed directly against each other form a cluster, identified by the head of its
	## first chain.
	var _cluster_of: Dictionary[String, String]
	
	## How far each cluster (keyed by id) may slide toward higher lanes without colliding with
	## another cluster. INF while unconstrained.
	var _cluster_slide: Dictionary[String, float]
	
	
	func _init(owner: SJSkillTreeLaneAssigner, is_looking_upward: bool, is_mirrored: bool) -> void:
		_owner = owner
		look_upward = is_looking_upward
		mirror = is_mirrored
	
		for skill: SJSkill in _owner._skill_by_id.values():
			_chain_head_of[skill.id] = skill.id
			_next_in_chain[skill.id] = skill.id
	
	
	func width() -> float:
		return max_lane - min_lane
	
	
	## Shifts the candidate so its left/right edge matches the reference's.
	func align_to(reference: _Candidate) -> void:
		var delta := (reference.max_lane - max_lane) if mirror else (reference.min_lane - min_lane)
		if delta == 0.0:
			return
		
		for skill_id in lane_by_id:
			lane_by_id[skill_id] += delta
		min_lane += delta
		max_lane += delta
	
	
	## Links each skill onto the chain of its median neighbor (requirements if look_upward, else
	## children), filling _chain_head_of and _next_in_chain.
	##
	## Within a tier, last_aligned_lane only ever increases: a skill may only join a neighbor
	## positioned after the previous one that joined in that tier, so chains never cross.
	func build_chains() -> void:
		for tier_index in _sweep_order():
			var last_aligned_lane := -1
			
			for skill in _visit_order(_owner._tiers[tier_index]):
				for neighbor_id in _median_neighbors(skill):
					if _already_joined(skill.id):
						break
					if _is_conflict(neighbor_id, skill.id):
						continue
					
					var neighbor_lane := _visit_lane(neighbor_id)
					if neighbor_lane > last_aligned_lane:
						_join_chain(neighbor_id, skill.id)
						last_aligned_lane = neighbor_lane
	
	
	## Gives every chain a lane, then writes each skill's lane (its chain's lane, negated when
	## mirrored to convert back to normal left-to-right orientation).
	func assign_lanes() -> void:
		var heads := _chain_heads()
		
		for head_id in heads:
			_cluster_of[head_id] = head_id
			_cluster_slide[head_id] = INF
		
		for head_id in heads:
			_place_chain(head_id)
		
		for head_id in heads:
			var slide: float = _cluster_slide[_cluster_of[head_id]]
			if slide < INF:
				_chain_lane[head_id] += slide
		
		for skill: SJSkill in _owner._skill_by_id.values():
			var lane: float = _chain_lane[_chain_head_of[skill.id]]
			lane_by_id[skill.id] = -lane if mirror else lane
		
		var lanes: Array = lane_by_id.values()
		min_lane = lanes.min()
		max_lane = lanes.max()
	
	
	func _sweep_order() -> Array:
		var order := range(_owner._tiers.size())
		if not look_upward:
			order.reverse()
		return order
	
	
	func _visit_order(tier: Array[SJSkill]) -> Array[SJSkill]:
		var ordered: Array[SJSkill] = tier.duplicate()
		if mirror:
			ordered.reverse()
		return ordered
	
	
	## The one or two median neighbors of a skill in its reference tier, in lane order.
	func _median_neighbors(skill: SJSkill) -> Array[String]:
		var tree := _owner._tree
		var neighbors: Array[String] = tree.skill_requirements[skill.id] if look_upward else tree.skill_children[skill.id]
		var medians: Array[String]
		
		if neighbors.is_empty():
			return medians
		
		var sorted_neighbors: Array[String] = neighbors.duplicate()
		sorted_neighbors.sort_custom(func(a: String, b: String) -> bool:
			return _visit_lane(a) < _visit_lane(b)
		)
		
		var count := sorted_neighbors.size()
		medians.assign(sorted_neighbors.slice((count - 1) / 2, count / 2 + 1))
		return medians
	
	
	func _already_joined(skill_id: String) -> bool:
		return _next_in_chain[skill_id] != skill_id
	
	
	func _is_conflict(neighbor_id: String, skill_id: String) -> bool:
		var edge_key := _owner._edge_key(neighbor_id, skill_id) if look_upward else _owner._edge_key(skill_id, neighbor_id)
		return _owner._conflicting_edges.get(edge_key, false)
	
	
	func _join_chain(neighbor_id: String, skill_id: String) -> void:
		_next_in_chain[neighbor_id] = skill_id
		_chain_head_of[skill_id] = _chain_head_of[neighbor_id]
		_next_in_chain[skill_id] = _chain_head_of[skill_id]
	
	
	func _chain_heads() -> Array[String]:
		var heads: Array[String]
		for skill: SJSkill in _owner._skill_by_id.values():
			if _chain_head_of[skill.id] == skill.id:
				heads.append(skill.id)
		return heads
	
	
	func _chain_skills(head_id: String) -> Array[String]:
		var skills: Array[String] = [head_id]
		var skill_id := _next_in_chain[head_id]
		
		while skill_id != head_id:
			skills.append(skill_id)
			skill_id = _next_in_chain[skill_id]
		
		return skills
	
	
	## Recursively places a chain just past the chains that sit before its skills in their
	## tiers, so a chain is only ever placed once. Chains in the same cluster are pushed apart;
	## for a chain in another cluster, the gap left is recorded so that cluster can slide
	## closer later.
	func _place_chain(head_id: String) -> void:
		if _chain_lane.has(head_id):
			return
		
		_chain_lane[head_id] = 0.0
		
		for skill_id in _chain_skills(head_id):
			var previous_id := _previous_in_tier(skill_id)
			if previous_id == "":
				continue
			
			var previous_head: String = _chain_head_of[previous_id]
			_place_chain(previous_head)
			
			if _cluster_of[head_id] == head_id:
				_cluster_of[head_id] = _cluster_of[previous_head]
			
			if _cluster_of[head_id] == _cluster_of[previous_head]:
				_chain_lane[head_id] = max(_chain_lane[head_id], _chain_lane[previous_head] + 1.0)
			else:
				var gap: float = _chain_lane[head_id] - _chain_lane[previous_head] - 1.0
				var previous_cluster: String = _cluster_of[previous_head]
				_cluster_slide[previous_cluster] = min(_cluster_slide[previous_cluster], gap)
	
	
	func _previous_in_tier(skill_id: String) -> String:
		var tier: Array[SJSkill] = _owner._tiers[_owner._tree.tier_by_id[skill_id]]
		var lane: int = _owner._tree.lane_by_id[skill_id]
		var previous_lane := lane - 1 if not mirror else lane + 1
		
		if previous_lane < 0 or previous_lane >= tier.size():
			return ""
		return tier[previous_lane].id
	
	
	func _visit_lane(skill_id: String) -> int:
		var lane: int = _owner._tree.lane_by_id[skill_id]
		if not mirror:
			return lane
		return _owner._tiers[_owner._tree.tier_by_id[skill_id]].size() - 1 - lane
