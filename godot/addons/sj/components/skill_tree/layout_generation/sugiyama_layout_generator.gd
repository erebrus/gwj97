@tool
class_name SJSkillTreeSugiyamaLayoutGenerator extends SJSkillTreeLayoutGenerator


var reduce_crossings_iterations: int = 10
var initial_temperature: float = 1.5

var _tiers: Array[Array]



func generate(tree: SJSkillTree) -> void:
	_reset_topology(tree)
	
	_calculate_base_tier_by_id(tree)
	_add_dummy_skills(tree)
	_group_by_tier(tree)
	
	var best_crossings := _count_all_crossings(tree)
	
	if best_crossings > 0:
		var best_lanes: Dictionary[String, int] = tree.lane_by_id.duplicate()
		var best_tiers: Array[Array] = _tiers.duplicate(true)
		
		for i in reduce_crossings_iterations:
			var crossings = _reduce_crossings(tree, reduce_crossings_iterations, initial_temperature)
			
			if crossings < best_crossings:
				best_crossings = crossings
				best_lanes = tree.lane_by_id.duplicate()
				best_tiers = _tiers.duplicate(true)
				
				if crossings == 0:
					break
			
			_group_by_tier(tree)
		
		tree.lane_by_id = best_lanes
		_tiers = best_tiers
	
	_balance_lanes_per_tier(tree)
	tree.emit_changed()


func _calculate_base_tier_by_id(tree: SJSkillTree) -> void:
	for skill: SJSkill in _skill_by_id.values():
		tree.tier_by_id[skill.id] = 0
	
	var tier_changed:= true
	while tier_changed:
		tier_changed = false
		for skill: SJSkill in _skill_by_id.values():
			for req_id in skill.requirements:
				var new_tier := tree.tier_by_id[req_id] + 1
				if new_tier > tree.tier_by_id[skill.id]:
					tree.tier_by_id[skill.id] = new_tier
					tier_changed = true


func _add_dummy_skills(tree: SJSkillTree) -> void:
	for skill: SJSkill in _skill_by_id.values():
		for req in skill.requirements:
			var parent := _skill_by_id[req]
			_create_dummies_between(tree, parent, skill)


func _group_by_tier(tree: SJSkillTree) -> void:
	var max_tier: int = tree.tier_by_id.values().max()
	var empty: Array[SJSkill]
	_tiers.resize(max_tier + 1)
	
	for i in _tiers.size():
		_tiers[i] = empty.duplicate()
	
	var visited: Dictionary[String, bool]
	var queue: Array[String]
	
	var roots: Array[String]
	roots.assign(_skill_by_id.keys().filter(func(x): return tree.tier_by_id[x] == 0))
	roots.shuffle()
	
	for root_id in roots:
		if not visited.has(root_id):
			visited[root_id] = true
			queue.append(root_id)
	
	while not queue.is_empty():
		var skill_id: String = queue.pop_front()
		var tier_index: int = tree.tier_by_id[skill_id]
		
		tree.lane_by_id[skill_id] = _tiers[tier_index].size()
		_tiers[tier_index].append(_skill_by_id[skill_id])
		
		var children: Array[String] = tree.skill_children[skill_id].duplicate()
		children.shuffle()
		
		for child_id in children:
			if not visited.has(child_id):
				visited[child_id] = true
				queue.append(child_id)


func _reduce_crossings(tree: SJSkillTree, reduce_crossings_iterations: int, initial_temperature: float) -> int:
	var best_crossings := _count_all_crossings(tree)
	var best_lanes: Dictionary[String, int] = tree.lane_by_id.duplicate()
	var best_tiers: Array[Array] = _tiers.duplicate(true)
	
	for i in reduce_crossings_iterations:
		var temperature := initial_temperature * (1.0 - float(i) / reduce_crossings_iterations)
		
		for t in range(1, _tiers.size()):
			_sort_tier_by_weight(tree, t, true)
		
		for t in range(_tiers.size() -2, -1, -1):
			_sort_tier_by_weight(tree, t, false)
		
		_transpose(tree, temperature)
		
		var crossings := _count_all_crossings(tree)
		if crossings < best_crossings:
			best_crossings = crossings
			best_lanes = tree.lane_by_id.duplicate()
			best_tiers = _tiers.duplicate(true)
			
			if crossings == 0:
				break
	
	tree.lane_by_id = best_lanes
	_tiers = best_tiers
	return best_crossings


## Brandes-Köpf lane assignment. Assumes tier order is already fixed by crossing minimization;
## only assigns positions, never reorders.
func _balance_lanes_per_tier(tree: SJSkillTree) -> void:
	var lanes := SJSkillTreeLaneAssigner.new(tree, _tiers, _skill_by_id).balanced_lanes()
	var min_desired_lane: float = lanes.values().min()
	
	for tier in _tiers:
		var previous_lane := -1
		
		for skill: SJSkill in tier:
			var desired := roundi(lanes[skill.id] - min_desired_lane)
			var lane: int = max(desired, previous_lane + 1)
			tree.lane_by_id[skill.id] = lane
			previous_lane = lane
	
	var max_lane: int = tree.lane_by_id.values().max()
	for tier in _tiers:
		var skills: Array[SJSkill] = tier.duplicate()
		
		tier.resize(max_lane + 1)
		tier.fill(null)
		
		for skill in skills:
			var lane = tree.lane_by_id[skill.id]
			tier[lane] = skill


func _create_dummies_between(tree: SJSkillTree, parent: SJSkill, child: SJSkill) -> void:
	var parent_tier:= tree.tier_by_id[parent.id]
	var child_tier:= tree.tier_by_id[child.id]
	
	assert(child_tier - parent_tier > 0)
	if child_tier - parent_tier == 1:
		return
	
	var current: SJSkill = parent
	
	for i in range(parent_tier + 1, child_tier):
		var dummy = SJSkill.new()
		dummy.id = "%s_%s_dummy_%s" % [parent.id, child.id, i]
		dummy.is_dummy = true
		
		assert(not dummy.id in _skill_by_id)
		tree.dummy_skills.append(dummy)
		_skill_by_id[dummy.id] = dummy
		tree.tier_by_id[dummy.id] = i
		
		_init_string_array_value(tree.skill_children, dummy.id)
		tree.skill_children[dummy.id].append(child.id)
		tree.skill_children[current.id].erase(child.id)
		tree.skill_children[current.id].append(dummy.id)
		
		_init_string_array_value(tree.skill_requirements, dummy.id)
		tree.skill_requirements[dummy.id].append(current.id)
		tree.skill_requirements[child.id].erase(current.id)
		tree.skill_requirements[child.id].append(dummy.id)
		
		current = dummy


func _transpose(tree: SJSkillTree, temperature: float, passes: int = 2) -> void:
	for _pass in passes:
		var tier_order := range(_tiers.size())
		tier_order.shuffle()
		
		for t in tier_order:
			var tier: Array[SJSkill] = _tiers[t]
			var index_order := range(tier.size() - 1)
			index_order.shuffle()
			
			for i in index_order:
				var before := _count_crossings_around_tier(tree, t)
				
				_swap_lanes(tree, tier, i, i+1)
				
				var after := _count_crossings_around_tier(tree, t)
				var delta := after - before
				
				var accept := delta <= 0
				if not accept and temperature > 0.0:
					accept = randf() < exp(-delta / temperature)
				
				if not accept:
					_swap_lanes(tree, tier, i, i+1)


func _swap_lanes(tree: SJSkillTree, tier: Array[SJSkill], index_a: int, index_b: int) -> void:
	var tmp := tier[index_a]
	tier[index_a] = tier[index_b]
	tier[index_b] = tmp
	
	tree.lane_by_id[tier[index_a].id] = index_a
	tree.lane_by_id[tier[index_b].id] = index_b


func _sort_tier_by_weight(tree: SJSkillTree, tier_index: int, look_upward: bool) -> void:
	var tier: Array[SJSkill] = _tiers[tier_index]
	var neighbors: Array[String]
	var barycenters: Dictionary[String, float]
	var medians: Dictionary[String, float]
	var max_parent: Dictionary[String, int]
	
	for skill in tier:
		if look_upward:
			neighbors = tree.skill_requirements[skill.id]
		else:
			neighbors = tree.skill_children[skill.id]
		
		barycenters[skill.id] = _get_barycenter(tree, skill.id, neighbors)
		medians[skill.id] = _get_median(tree, skill.id, neighbors, look_upward)
		max_parent[skill.id] = 0
		for n in neighbors:
			if tree.lane_by_id[n] > max_parent[skill.id]:
				max_parent[skill.id] = tree.lane_by_id[n]
	
	tier.sort_custom(func(a: SJSkill, b: SJSkill) -> bool:
		if not is_equal_approx(medians[a.id], medians[b.id]):
			return medians[a.id] < medians[b.id]
		
		if not is_equal_approx(barycenters[a.id], barycenters[b.id]):
			return barycenters[a.id] < barycenters[b.id]
		
		return max_parent[a.id] < max_parent[b.id]
	)
	
	for lane in tier.size():
		tree.lane_by_id[tier[lane].id] = lane


func _count_all_crossings(tree: SJSkillTree) -> int:
	var result := 0
	
	for t in range(_tiers.size() - 1):
		result += _count_crossings_between_tiers(tree, t)
	
	return result


func _count_crossings_around_tier(tree: SJSkillTree, t: int) -> int:
	var result := 0
	if t > 0:
		result += _count_crossings_between_tiers(tree, t - 1)
	if t < _tiers.size() - 1:
		result += _count_crossings_between_tiers(tree, t)
	return result


func _count_crossings_between_tiers(tree: SJSkillTree, upper_index: int) -> int:
	var crossings := 0
	
	var upper := _tiers[upper_index]
	var lower_index := upper_index + 1
	
	for i in upper.size():
		var a: SJSkill = upper[i]
		
		for child_a_id in tree.skill_children[a.id]:
			if tree.tier_by_id[child_a_id] != lower_index:
				continue
			
			var child_a_lane := tree.lane_by_id[child_a_id]
			
			for j in range(i + 1, upper.size()):
				var b: SJSkill = upper[j]
				
				for child_b_id in tree.skill_children[b.id]:
					if tree.tier_by_id[child_b_id] != lower_index:
						continue
					
					var child_b_lane := tree.lane_by_id[child_b_id]
					
					if child_a_lane > child_b_lane:
						crossings += 1
	
	return crossings


func _get_barycenter(tree: SJSkillTree, skill_id: String, neighbors: Array[String]) -> float:
	if neighbors.is_empty():
		return tree.lane_by_id[skill_id]
	
	var sum_lanes: float = 0.0
	for neighbor_id in neighbors:
		sum_lanes += tree.lane_by_id[neighbor_id]
	return sum_lanes / neighbors.size()


func _get_median(tree: SJSkillTree, skill_id: String, neighbors: Array[String], look_upward: bool) -> float:
	if neighbors.is_empty():
		return tree.lane_by_id[skill_id]
	
	var positions: Array[float]
	for neighbor_id in neighbors:
		positions.append(tree.lane_by_id[neighbor_id])
	
	positions.sort()
	
	var middle:= positions.size() / 2
	
	if positions.size() % 2 == 1:
		return positions[middle]
	
	var bias = 0.45 if look_upward else 0.55
	return lerp(positions[middle - 1], positions[middle], bias)
