class_name Cargo extends RigidBody2D

const _SCENE = preload("cargo.tscn")

@export 
var type := Types.Resources.ORE

func attract_to(target:Vector2, strength:float):
	var impulse:Vector2 = (target - global_position).normalized()*(strength)
	apply_force(impulse)
	
static func create(type:Types.Resources)->Cargo:
	var ret:Cargo = _SCENE.instantiate()
	ret.type = type
	return ret
