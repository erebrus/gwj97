class_name ResourceLabel extends HBoxContainer

@export var icons: Dictionary[Types.Resources, Texture2D]

@export var amount: int:
	set(value):
		if value == amount:
			return
		amount = value
		if is_node_ready():
			setup()

@export var type: Types.Resources:
	set(value):
		if value == type:
			return
		type = value
		if is_node_ready():
			setup()


@warning_ignore("shadowed_variable")
static func create(type: Types.Resources, amount: int) -> ResourceLabel:
	var scene := load("uid://dnxvr1hmngl6l").instantiate() as ResourceLabel
	scene.type = type
	scene.amount = amount
	return scene


func _ready() -> void:
	setup()


func setup() -> void:
	%Amount.text = "%s" % amount
	%Icon.texture = icons[type]
