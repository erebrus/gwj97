class_name StationRoom extends StaticBody2D

@export var requirements:Dictionary[Types.Resources, int]
@export var production_requirements:Dictionary[Types.Resources, int]
@export var production_output:Dictionary[Types.Resources, int]
@export var activated:=true

var texture: Texture2D:
	get:
		return %Sprite2D.texture

var station:Station
var tile_size: Vector2i
var rect: Rect2i
var center: Vector2i:
	get:
		@warning_ignore("integer_division")
		return rect.position * tile_size + rect.size * tile_size / 2
@onready var area_collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var area_2d: Area2D = $Area2D

func _ready() -> void:
	_setup_collision()

func _setup_collision() -> void:
	var tiles: TileMapLayer = %Tiles
	tile_size= tiles.tile_set.tile_size
	var collision_rect:= RectangleShape2D.new()
	collision_rect.size = tile_size - Vector2i.ONE
	area_collision_shape_2d.shape = collision_rect

	for cell in tiles.get_used_cells():
		var shape := CollisionShape2D.new()
		shape.shape = collision_rect
		@warning_ignore("integer_division")
		shape.position = cell * tile_size + tile_size / 2
		add_child(shape)
		
		rect.position.x = mini(rect.position.x, cell.x)
		rect.position.y = mini(rect.position.y, cell.y)
		rect.end.x = maxi(rect.end.x, cell.x+1)
		rect.end.y = maxi(rect.end.y, cell.y+1)

func get_overlapping_areas() -> Array[Area2D]:
	return area_2d.get_overlapping_areas()

func can_produce_power()->bool:
	return Types.Resources.POWER in production_output and station.has_resources(production_requirements)

func do_production():
	if station.has_resources(production_requirements):
		station.add_resources(production_output)
		station.consume_resources(production_requirements)
		Events.successful_production.emit(self)
	else:
		Events.unsuccessful_production.emit(self)
		
	
