class_name SJSkillTreeLayout extends Resource

@export var tiers: Array[Array]

var skill_by_id: Dictionary[String, SJSkill]
var skill_children: Dictionary[String, Array]
var skill_requirements: Dictionary[String, Array]

var tier_by_id: Dictionary[String, int]
var lane_by_id: Dictionary[String, int]

var initialized: bool


static func create(skills: Array[SJSkill], reduce_crossings_iterations: int = 10, initial_temperature: float = 1.5) -> SJSkillTreeLayout:
	var layout := SJSkillTreeLayout.new()
	layout._create_square_grid(skills, reduce_crossings_iterations, initial_temperature)
	return layout


func is_available(skill_id: String) -> bool:
	for requirement_id in skill_requirements[skill_id]:
		if not skill_by_id[requirement_id].is_bought:
			return false
	return true


func _create_square_grid(skills: Array[SJSkill], reduce_crossings_iterations: int, initial_temperature: float) -> void:
	print("Creating square grid layout")
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
	_group_by_tier()
	
	var best_crossings := _count_all_crossings()
	
	if best_crossings > 0:
		var best_lanes: Dictionary[String, int] = lane_by_id.duplicate()
		var best_tiers: Array[Array] = tiers.duplicate(true)
		
		for i in reduce_crossings_iterations:
			var crossings = _reduce_crossings(reduce_crossings_iterations, initial_temperature)
			
			if crossings < best_crossings:
				best_crossings = crossings
				best_lanes = lane_by_id.duplicate()
				best_tiers = tiers.duplicate(true)
				
				if crossings == 0:
					break
			
			_group_by_tier()
		
		lane_by_id = best_lanes
		tiers = best_tiers
	
	_make_sparse_tier_lists() # TODO: Brandes-Köpf

	print(tiers)

	initialized = true


func _calculate_base_tier_by_id() -> void:
	for skill: SJSkill in skill_by_id.values():
		tier_by_id[skill.id] = 0
	
	var tier_changed:= true
	while tier_changed:
		tier_changed = false
		for skill: SJSkill in skill_by_id.values():
			for req_id in skill.requirements:
				var new_tier := tier_by_id[req_id] + 1
				if new_tier > tier_by_id[skill.id]:
					tier_by_id[skill.id] = new_tier
					tier_changed = true


func _add_dummy_skills() -> void:
	for skill: SJSkill in skill_by_id.values():
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


func _group_by_tier() -> void:
	var max_tier: int = tier_by_id.values().max()
	var empty: Array[SJSkill]
	tiers.resize(max_tier + 1)
	
	for i in tiers.size():
		tiers[i] = empty.duplicate()

	var visited: Dictionary[String, bool]
	var queue: Array[String]

	var roots: Array[String]
	roots.assign(skill_by_id.keys().filter(func(x): return tier_by_id[x] == 0))
	roots.shuffle()
	
	for root_id in roots:
		if not visited.has(root_id):
			visited[root_id] = true
			queue.append(root_id)
	
	while not queue.is_empty():
		var skill_id: String = queue.pop_front()
		var tier_index: int = tier_by_id[skill_id]
		
		lane_by_id[skill_id] = tiers[tier_index].size()
		tiers[tier_index].append(skill_by_id[skill_id])
		
		var children: Array[String] = skill_children[skill_id].duplicate()
		children.shuffle()
		
		for child_id in children:
			if not visited.has(child_id):
				visited[child_id] = true
				queue.append(child_id)


func _reduce_crossings(reduce_crossings_iterations: int, initial_temperature: float) -> int:
	var best_crossings := _count_all_crossings()
	var best_lanes: Dictionary[String, int] = lane_by_id.duplicate()
	var best_tiers: Array[Array] = tiers.duplicate(true)

	for i in reduce_crossings_iterations:
		var temperature := initial_temperature * (1.0 - float(i) / reduce_crossings_iterations)

		for t in range(1, tiers.size()):
			_sort_tier_by_weight(t, true)

		for t in range(tiers.size() -2, -1, -1):
			_sort_tier_by_weight(t, false)

		_transpose(temperature)

		var crossings := _count_all_crossings()
		if crossings < best_crossings:
			best_crossings = crossings
			best_lanes = lane_by_id.duplicate()
			best_tiers = tiers.duplicate(true)

			if crossings == 0:
				break

	lane_by_id = best_lanes
	tiers = best_tiers
	return best_crossings


func _transpose(temperature: float, passes: int = 2) -> void:
	for _pass in passes:
		var tier_order := range(tiers.size())
		tier_order.shuffle()

		for t in tier_order:
			var tier: Array[SJSkill] = tiers[t]
			var index_order := range(tier.size() - 1)
			index_order.shuffle()

			for i in index_order:
				var before := _count_crossings_around_tier(t)

				# Swap adjacent nodes.
				var tmp := tier[i]
				tier[i] = tier[i + 1]
				tier[i + 1] = tmp

				lane_by_id[tier[i].id] = i
				lane_by_id[tier[i + 1].id] = i + 1

				var after := _count_crossings_around_tier(t)
				var delta := after - before

				var accept := delta <= 0
				if not accept and temperature > 0.0:
					accept = randf() < exp(-delta / temperature)

				if not accept:
					# Undo.
					tmp = tier[i]
					tier[i] = tier[i + 1]
					tier[i + 1] = tmp

					lane_by_id[tier[i].id] = i
					lane_by_id[tier[i + 1].id] = i + 1


func _make_sparse_tier_lists() -> void:
	var desired_lane: Dictionary[String, float] 
	for t in range(tiers.size() -2, -1, -1):
		var tier: Array[SJSkill] = tiers[t]
		
		for i in tier.size():
			var skill:= tier[i]
			var desired:= roundi(_get_barycenter(skill.id, skill_children[skill.id]))
			
			if i > 0:
				var previous:= lane_by_id[tier[i-1].id]
				lane_by_id[skill.id] = max(desired, previous + 1)
			else:
				lane_by_id[skill.id] = desired
	
	var max_lane: int = lane_by_id.values().max()
	for tier in tiers:
		var skills: Array[SJSkill] = tier.duplicate()
		
		tier.resize(max_lane + 1)
		tier.fill(null)
		
		for skill in skills:
			var lane = lane_by_id[skill.id]
			tier[lane] = skill


func _sort_tier_by_weight(tier_index: int, look_upward: bool) -> void:
	var tier: Array[SJSkill] = tiers[tier_index]
	var neighbors: Array[String]
	var barycenters: Dictionary[String, float] 
	var medians: Dictionary[String, float] 
	var max_parent: Dictionary[String, int]
	
	for skill in tier:
		if look_upward:
			neighbors = skill_requirements[skill.id]
		else:
			neighbors = skill_children[skill.id]
		
		barycenters[skill.id] = _get_barycenter(skill.id, neighbors)
		medians[skill.id] = _get_median(skill.id, neighbors, look_upward)
		max_parent[skill.id] = 0
		for n in neighbors:
			if lane_by_id[n] > max_parent[skill.id]:
				max_parent[skill.id] = lane_by_id[n]
	
	tier.sort_custom(func(a: SJSkill, b: SJSkill) -> bool:
		if not is_equal_approx(medians[a.id], medians[b.id]):
			return medians[a.id] < medians[b.id]
		
		if not is_equal_approx(barycenters[a.id], barycenters[b.id]):
			return barycenters[a.id] < barycenters[b.id]
		
		return max_parent[a.id] < max_parent[b.id]
	)
	
	for lane in tier.size():
		lane_by_id[tier[lane].id] = lane


func _count_all_crossings() -> int:
	var result := 0

	for t in range(tiers.size() - 1):
		result += _count_crossings_between_tiers(t)

	return result


func _count_crossings_around_tier(t: int) -> int:
	var result := 0
	if t > 0:
		result += _count_crossings_between_tiers(t - 1)
	if t < tiers.size() - 1:
		result += _count_crossings_between_tiers(t)
	return result


func _count_crossings_between_tiers(upper_index: int) -> int:
	var crossings := 0

	var upper := tiers[upper_index]
	var lower_index := upper_index + 1

	for i in upper.size():
		var a: SJSkill = upper[i]

		for child_a_id in skill_children[a.id]:
			if tier_by_id[child_a_id] != lower_index:
				continue

			var child_a_lane := lane_by_id[child_a_id]

			for j in range(i + 1, upper.size()):
				var b: SJSkill = upper[j]

				for child_b_id in skill_children[b.id]:
					if tier_by_id[child_b_id] != lower_index:
						continue

					var child_b_lane := lane_by_id[child_b_id]

					if child_a_lane > child_b_lane:
						crossings += 1

	return crossings


func _get_barycenter(skill_id: String, neighbors: Array[String]) -> float:
	if neighbors.is_empty():
		return lane_by_id[skill_id]
	
	var sum_lanes: float = 0.0
	for neighbor_id in neighbors:
		sum_lanes += lane_by_id[neighbor_id]
	return sum_lanes / neighbors.size()
	

func _get_median(skill_id: String, neighbors: Array[String], look_upward: bool) -> float:
	if neighbors.is_empty():
		return lane_by_id[skill_id]
	
	var positions: Array[float]
	for neighbor_id in neighbors:
		positions.append(lane_by_id[neighbor_id])
	
	positions.sort()
	
	var middle:= positions.size() / 2
	
	if positions.size() % 2 == 1:
		return positions[middle]
	
	var bias = 0.45 if look_upward else 0.55
	return lerp(positions[middle - 1], positions[middle], bias)


func _to_string() -> String:
	return "%s" % [tiers]


static func _init_string_array_value(dictionary: Dictionary, key: Variant) -> void:
	var array: Array[String]
	if not dictionary.has(key):
		dictionary[key] = array
