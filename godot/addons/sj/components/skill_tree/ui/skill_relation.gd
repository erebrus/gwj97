@tool
class_name SJSkillRelation extends Line2D


signal descendant_selected_changed


const DIRECTION_AXIS := {
	SJSkillTreeControl.Direction.LeftRight: Vector2.RIGHT,
	SJSkillTreeControl.Direction.RightLeft: Vector2.LEFT,
	SJSkillTreeControl.Direction.TopDown:   Vector2.DOWN,
	SJSkillTreeControl.Direction.DownTop:   Vector2.UP,
}


@export var curve_factor: float = 0.5:
	set(value):
		if value == curve_factor:
			return
		curve_factor = value
		if is_node_ready():
			setup()


var nodes: Array[SJSkillNode]:
	set(value):
		if value == nodes:
			return
		if not nodes.is_empty():
			if nodes.back().descendant_selected_changed.is_connected(_on_child_descendant_selected_changed):
				nodes.back().descendant_selected_changed.disconnect(_on_child_descendant_selected_changed)
			for node in nodes:
				if node.transform_changed.is_connected(update_points):
					node.transform_changed.disconnect(update_points)
		nodes = value
		nodes.back().descendant_selected_changed.connect(_on_child_descendant_selected_changed)
		for node in nodes:
			node.transform_changed.connect(update_points)
		
		if is_node_ready():
			setup()


var direction: SJSkillTreeControl.Direction:
	set(value):
		if value == direction:
			return
		direction = value
		if is_node_ready():
			setup()


var descendant_is_selected: bool:
	set(value):
		if value == descendant_is_selected:
			return
		descendant_is_selected = value
		descendant_selected_changed.emit()


var parent_node: SJSkillNode:
	get:
		return nodes.front()


var child_node: SJSkillNode:
	get:
		return nodes.back()


func _ready() -> void:
	setup()


func setup() -> void:
	update_points()


func update_points() -> void:
	var curve := Curve2D.new()
	
	var axis: Vector2 = DIRECTION_AXIS[direction]
	var extent := axis.abs()
	
	for i in nodes.size():
		var node := nodes[i]
		var node_size := node.get_rect().size
		var node_extent := node_size.dot(extent)
		var node_position := node.global_position + node_size / 2 - global_position
		
		if i > 0:
			var node_in_position := node_position - axis * node_extent * 0.4
			var in_control := -axis * node_extent * curve_factor
			
			curve.add_point(node_in_position, in_control, Vector2.ZERO)
			
		if i < nodes.size() - 1:
			var node_out_position := node_position + axis * node_extent * 0.4
			var out_control := axis * node_extent * curve_factor
			
			curve.add_point(node_out_position, Vector2.ZERO, out_control)
	
	points = curve.get_baked_points()


func _on_child_descendant_selected_changed() -> void:
	descendant_is_selected = child_node.descendant_is_selected
	parent_node.descendant_is_selected = child_node.descendant_is_selected
