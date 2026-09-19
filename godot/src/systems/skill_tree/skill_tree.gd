@tool
class_name SkillTree extends MarginContainer

enum Direction {
	LeftRight,
	RightLeft,
	TopDown,
	DownTop
}

@export_tool_button("Random debug tree") var create_debug_tree = _create_debug_tree

@export var direction: Direction:
	set(value):
		if value == direction:
			return
		direction = value
		if is_node_ready():
			setup()

var skills: SkillTreeLayout:
	set(value):
		if value == skills:
			return
		skills = value
		if is_node_ready():
			setup()

var lines_container: Node2D
var tier_container: Container
var nodes_by_id: Dictionary[String, SkillNode]
var lines: Dictionary[String, Dictionary] # Dictionary[parent_skill_id, Dictionary[child_skill_id, Line2D]]


@warning_ignore("shadowed_variable")
static func create(skills: SkillTreeLayout) -> SkillTree:
	var scene := load("uid://cdxfehvpi46yk").instantiate() as SkillTree
	scene.skills = skills
	return scene


func _ready() -> void:
	if get_tree().current_scene == self:
		_create_debug_tree()
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
				child = SkillNode.create(SkillTreeSkill.new())
				child.modulate.a = 0
			else:
				child = SkillNode.create(skill)
				nodes_by_id[skill.id] = child
			
			child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			skill_container.add_child(child)
	
	for child_node: SkillNode in nodes_by_id.values():
		for req_id in child_node.skill.requirements:
			if not nodes_by_id.has(req_id):
				continue
			
			var parent_node:= nodes_by_id[req_id]
			var line:= SkillRelation.create(parent_node, child_node, direction)
			lines_container.add_child(line)
 

func _create_debug_tree() -> void:
	var skillA = SkillTreeSkill.create_random("a")
	var skillB = SkillTreeSkill.create_random("b")
	var skillC = SkillTreeSkill.create_random("c")
	
	var skillA1 = SkillTreeSkill.create_random("a1", skillA)
	var skillAB1 = SkillTreeSkill.create_random("ab1", skillA, skillB)
	var skillB1 = SkillTreeSkill.create_random("b1", skillB)
	var skillB2 = SkillTreeSkill.create_random("b2", skillB)
	var skillC1 = SkillTreeSkill.create_random("c1", skillC)
	var skillC2 = SkillTreeSkill.create_random("c2", skillC)
	
	var skillB11 = SkillTreeSkill.create_random("b11", skillB1)
	var skillB12 = SkillTreeSkill.create_random("b12", skillB1)
	
	
	var all_skills: Array[SkillTreeSkill] = [
		skillA, skillB, skillC, 
		skillA1, skillAB1, skillB1, skillB2, skillC1, skillC2, 
		skillB11, skillB12, 
	]
	all_skills.shuffle()
	
	skills =  SkillTreeLayout.create(all_skills)
	print(skills)
