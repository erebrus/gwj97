@tool
class_name SJSkillRelation extends Line2D


const DIRECTION_AXIS := {
	SJSkillTree.Direction.LeftRight: Vector2.RIGHT,
	SJSkillTree.Direction.RightLeft: Vector2.LEFT,
	SJSkillTree.Direction.TopDown:   Vector2.DOWN,
	SJSkillTree.Direction.DownTop:   Vector2.UP,
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
		if nodes != null:
			for node in nodes:
				if node.transform_changed.is_connected(update_points):
					node.transform_changed.disconnect(update_points)
		nodes = value
		for node in nodes:
			node.transform_changed.connect(update_points)
		
		if is_node_ready():
			setup()


var direction: SJSkillTree.Direction:
	set(value):
		if value == direction:
			return
		direction = value
		if is_node_ready():
			setup()


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
