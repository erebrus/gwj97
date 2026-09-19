class_name Cargo extends RigidBody2D

const _SCENE = preload("cargo.tscn")
const MINERAL_TEXS = [
		preload("res://assets/gfx/map/ore/ore.png"),
		preload("res://assets/gfx/map/ore/etherium.png")
	]
@export 
var type := Types.Resources.ORE:
	set(_v):
		type = _v
		if is_node_ready():
			update_sprite()
@onready var sprite: Sprite2D = $Sprite2D

		
func _ready():
	update_sprite()

func update_sprite():
	sprite.texture = MINERAL_TEXS[type]
	
func attract_to(target:Vector2, strength:float):
	var impulse:Vector2 = (target - global_position).normalized()*(strength)
	apply_force(impulse)
	
static func create(_type:Types.Resources)->Cargo:
	var ret:Cargo = _SCENE.instantiate()
	ret.type = _type
	return ret
