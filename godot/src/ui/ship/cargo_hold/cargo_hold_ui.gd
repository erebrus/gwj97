class_name CargoHoldUi extends GridContainer

const NO_CARGO_TEX:Texture = preload("res://assets/gfx/map/ore/empty.png")

var max_cargo:int = 4
func _ready():
	Events.ship_init_completed.connect(_on_ship_init_completed)
	Events.cargo_updated.connect(_on_cargo_updated)

func _on_ship_init_completed(ship:Player):
	max_cargo = ship.max_cargo
	_on_cargo_updated([])
	
func _on_cargo_updated(cargo:Array[Types.Resources]):
	GameUtils.clear_node(self)
	var count:=0
	for t:Types.Resources in cargo:
		var img:= TextureRect.new()
		img.texture = Cargo.MINERAL_TEXS[t]
		img.scale = Vector2.ONE * .25
		add_child(img)
		count += 1
	for i in range(count, max_cargo):
		var img:= TextureRect.new()
		img.texture = NO_CARGO_TEX
		img.scale = Vector2.ONE * .25
		add_child(img)
