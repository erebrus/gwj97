@tool
class_name SJSkillTree extends MarginContainer

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

var skills: SJSkillTreeLayout:
	set(value):
		if value == skills:
			return
		skills = value
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
	
	if skills == null:
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
	
	var tiers: Array[Array] = skills.tiers.duplicate()
	
	if direction == Direction.RightLeft or direction == Direction.DownTop:
		tiers.reverse()
	
	for n in tiers.size():
		var tier:= tiers[n]
		var skill_container: Container
		
		if direction == Direction.TopDown or direction == Direction.DownTop:
			skill_container = HBoxContainer.new()
			skill_container.size_flags_horizontal = Control.SIZE_FILL
		else:
			skill_container = VBoxContainer.new()
			skill_container.size_flags_vertical = Control.SIZE_FILL
		
		tier_container.add_child(skill_container)
		
		if n < tiers.size() - 1:
			var spacer = Control.new()
			if direction == Direction.TopDown or direction == Direction.DownTop:
				spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			else:
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tier_container.add_child(spacer)
		
		for skill in tier:
			var child: Control
			if skill == null:
				var dummy:= SJSkillTreeSkill.new()
				dummy.is_dummy = true
				child = _create_node(dummy)
			else:
				child = _create_node(skill)
				nodes_by_id[skill.id] = child
			
			child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			skill_container.add_child(child)
	
	for parent_node: SJSkillNode in nodes_by_id.values():
		for child_id in skills.skill_children[parent_node.skill.id]:
			assert(nodes_by_id.has(child_id))
			if not nodes_by_id.has(child_id):
				continue
			
			var child_node:= nodes_by_id[child_id]
			var line:= _create_relation(parent_node, child_node)
			lines_container.add_child(line)
 
## Used by the tree to instantiate a skill node. Override or set [member node_scene]
## for a custom skill node scenee
func _create_node(skill: SJSkillTreeSkill) -> SJSkillNode:
	var node = node_scene.instantiate() as SJSkillNode
	node.skill = skill
	return node

## Used by the tree to instantiate a skill relation. Override or set [member relation_scene]
## for a custom skill relation scenee
func _create_relation(parent_node: SJSkillNode, child_node: SJSkillNode) -> SJSkillRelation:
	var relation := relation_scene.instantiate() as SJSkillRelation
	relation.parent = parent_node
	relation.child = child_node
	relation.direction = direction
	return relation
