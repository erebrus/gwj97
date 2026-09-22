@tool
class_name SJSkillTreeControl extends MarginContainer


signal skill_selected(skill: SJSkill)
signal skill_pressed(skill: SJSkill)


enum Direction {
	LeftRight,
	RightLeft,
	TopDown,
	DownTop
}


@export var node_scene: PackedScene
@export var relation_scene: PackedScene

@export var direction: Direction:
	set(value):
		if value == direction:
			return
		direction = value
		if is_node_ready():
			setup()

var skill_tree: SJSkillTree:
	set(value):
		if value == skill_tree:
			return
		skill_tree = value
		if is_node_ready():
			setup()

var lines_container: Node2D
var tier_container: Container
var nodes_by_id: Dictionary[String, SJSkillNode]


func _ready() -> void:
	setup()


func setup() -> void:
	if is_instance_valid(tier_container):
		remove_child(tier_container)
		tier_container.queue_free()
	if is_instance_valid(lines_container):
		remove_child(lines_container)
		lines_container.queue_free()
	nodes_by_id.clear()
	
	if skill_tree == null:
		return
	
	lines_container = Node2D.new()
	add_child(lines_container)
	
	if direction == Direction.LeftRight or direction == Direction.RightLeft:
		tier_container = HBoxContainer.new()
		tier_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		tier_container = VBoxContainer.new()
		tier_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tier_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	add_child(tier_container)
	
	var tiers: Array[Array] = skill_tree.get_tiers()
	if direction == Direction.RightLeft or direction == Direction.DownTop:
		tiers.reverse()
	
	for n in tiers.size():
		_create_tier(tiers[n])
		if n < tiers.size() - 1:
			_create_tier_spacer()
	
	for node: SJSkillNode in nodes_by_id.values():
		if node.skill.is_dummy:
			continue
		
		var chains:= skill_tree.get_children_chains(node.skill.id)
		
		if chains.is_empty():
			continue
		
		for chain: Array[SJSkill] in chains:
			var nodes: Array[SJSkillNode]
			
			for skill in chain:
				if not nodes_by_id.has(skill.id):
					assert(false, "Tree does not have chain node")
					break
				
				nodes.append(nodes_by_id[skill.id])
			
			if chain.size() < 2:
				continue
			
			var line:= _create_relation(nodes)
			lines_container.add_child(line)


func _create_tier(tier: Array[SJSkill]) -> void:
	var skill_container: Container
	
	if direction == Direction.TopDown or direction == Direction.DownTop:
		skill_container = HBoxContainer.new()
		skill_container.size_flags_horizontal = Control.SIZE_FILL
	else:
		skill_container = VBoxContainer.new()
		skill_container.size_flags_vertical = Control.SIZE_FILL
	
	tier_container.add_child(skill_container)
	
	for skill: SJSkill in tier:
		var child: Control
		if skill == null:
			var dummy:= SJSkill.new()
			dummy.is_dummy = true
			child = _create_node(dummy)
		else:
			child = _create_node(skill)
			child.selected.connect(_on_skill_node_selected)
			child.pressed.connect(_on_skill_node_pressed)
			
			nodes_by_id[skill.id] = child
		
		child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		skill_container.add_child(child)


func _create_tier_spacer() -> void:
	var spacer = Control.new()
	if direction == Direction.TopDown or direction == Direction.DownTop:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_container.add_child(spacer)


## Used by the tree to instantiate a skill node. Override or set [member node_scene]
## for a custom skill node scenee
func _create_node(skill: SJSkill) -> SJSkillNode:
	var node = node_scene.instantiate() as SJSkillNode
	node.skill = skill
	return node

## Used by the tree to instantiate a skill relation. Override or set [member relation_scene]
## for a custom skill relation scene. [br]
## [param nodes]: list of nodes contained by this relation, ordered by tier.
## [code]nodes.front()[/code] is the canonical parent. [code]nodes.back()[/code] is 
## the canonical child. Internal nodes are dummy nodes (one per tier jump).
func _create_relation(nodes: Array[SJSkillNode]) -> SJSkillRelation:
	var relation := relation_scene.instantiate() as SJSkillRelation
	relation.nodes = nodes
	relation.direction = direction
	return relation


func _on_skill_node_selected(skill: SJSkill) -> void:
	for skill_id in nodes_by_id:
		if skill_id != skill.id:
			nodes_by_id[skill_id].is_selected = false
	
	skill_selected.emit(skill)


func _on_skill_node_pressed(skill: SJSkill) -> void:
	skill_pressed.emit(skill)
