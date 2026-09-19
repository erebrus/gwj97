@tool
class_name SkillRelation extends Line2D

@export var curve_factor: float = 0.5:
	set(value):
		if value == curve_factor:
			return
		curve_factor = value
		if is_node_ready():
			setup()


var parent: SkillNode:
	set(value):
		if value == parent:
			return
		if parent != null:
			parent.transform_changed.disconnect(update_points)
		parent = value
		parent.transform_changed.connect(update_points)
		if is_node_ready():
			setup()


var child: SkillNode:
	set(value):
		if value == child:
			return
		if child != null:
			child.transform_changed.disconnect(update_points)
		child = value
		child.transform_changed.connect(update_points)
		if is_node_ready():
			setup()


var direction: SkillTree.Direction:
	set(value):
		if value == direction:
			return
		direction = value
		if is_node_ready():
			setup()


@warning_ignore("shadowed_variable")
static func create(parent: SkillNode, child: SkillNode, direction: SkillTree.Direction) -> SkillRelation:
	var scene := load("uid://wyblvfvyq55c").instantiate() as SkillRelation
	scene.parent = parent
	scene.child = child
	scene.direction = direction
	return scene


func _ready() -> void:
	setup()


func setup() -> void:
	update_points()


func update_points() -> void:
	var curve := Curve2D.new()
	
	var parent_size := parent.get_rect().size
	var child_size := child.get_rect().size
	
	var parent_position := parent.global_position + parent_size / 2 - global_position
	var child_position := child.global_position + child.get_rect().size / 2 - global_position
	var parent_out: Vector2
	var child_out: Vector2
	
	match direction:
		SkillTree.Direction.LeftRight:
			parent_position += Vector2(parent_size.x * 0.4, 0)
			child_position -= Vector2(child_size.x * 0.4, 0)
			parent_out = Vector2(parent_size.x * curve_factor, 0)
			child_out = - Vector2(child_size.x * curve_factor, 0)
		SkillTree.Direction.RightLeft:
			parent_position -= Vector2(parent_size.x * 0.4, 0)
			child_position += Vector2(child_size.x * 0.4, 0)
			parent_out = - Vector2(parent_size.x * curve_factor, 0)
			child_out = Vector2(child_size.x * curve_factor, 0)
		SkillTree.Direction.TopDown:
			parent_position += Vector2(0, parent_size.y * 0.4)
			child_position -= Vector2(0, child_size.y * 0.4)
			parent_out = Vector2(0, parent_size.y * curve_factor)
			child_out = - Vector2(0, child_size.y * curve_factor)
		SkillTree.Direction.DownTop:
			parent_position -= Vector2(0, parent_size.y * 0.4)
			child_position += Vector2(0, child_size.y * 0.4)
			parent_out = - Vector2(0, parent_size.y * curve_factor)
			child_out = Vector2(0, child_size.y * curve_factor)
	
	curve.add_point(parent_position, Vector2.ZERO, parent_out)
	curve.add_point(child_position, child_out)
	
	points = curve.get_baked_points()
	
