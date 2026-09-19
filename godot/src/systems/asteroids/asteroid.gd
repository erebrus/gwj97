class_name Asteroid extends RigidBody2D
@export
var angular_speed_interval:Vector2 = Vector2(0.1,.5)
const MINERAL_CLUSTER_TEXS = [
	[preload("res://assets/gfx/map/ore/ore_cluster1.png"), preload("res://assets/gfx/map/ore/ore_cluster2.png"), preload("res://assets/gfx/map/ore/ore_cluster3.png"), preload("res://assets/gfx/map/ore/ore_cluster4.png")],
	[preload("res://assets/gfx/map/ore/etherium_cluster1.png"), preload("res://assets/gfx/map/ore/etherium_cluster2.png"), preload("res://assets/gfx/map/ore/etherium_cluster3.png"), preload("res://assets/gfx/map/ore/etherium_cluster4.png")]
]
const MINERAL_TEXS = [
		preload("res://assets/gfx/map/ore/ore_asteroid.png"),
		preload("res://assets/gfx/map/ore/etherium_asteroid.png"),
		
	]
const RICHNESS_WEIGHTS := [.3,.4,.2,.1]
const RICHNESS_MINERALS := [2,4,5,7]

@export 
var max_structure:float = 250
@export 
var type := Types.Resources.ORE
@export
var mineral_count := 5
@export 
var structure:float = 100

var flash_time:float=0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var broken_sprite: AnimatedSprite2D = $BrokenSprite
@onready var patches: Node2D = $Patches
@onready var decor: Node2D = $Decor

func _ready():
	structure = max_structure
	angular_velocity = randf_range(angular_speed_interval.x, angular_speed_interval.y)
	GSLogger.debug("%s angular velocity = %2f" % [name, angular_velocity])
	_update_minerals()
	if mineral_count > 0:
		if type == Types.Resources.ETHERIUM:
			GSLogger.info ("generated ETH with count %d" % [mineral_count])
		else:
			GSLogger.info ("generated ORE with count %d" % [mineral_count])
		
func _update_minerals():
	var available_patches:Array[int]
	
	for i in patches.get_child_count():
		GameUtils.clear_node(patches.get_child(i))
		available_patches.append(i)
		
	
	for i in range(mineral_count):
		var mineral_sprite := Sprite2D.new()
		
		mineral_sprite.texture = MINERAL_TEXS[type]
		var patch = available_patches.pick_random()
		available_patches.erase(patch)
		patches.get_child(patch).add_child(mineral_sprite)
		mineral_sprite.rotation = 2*PI * randf()
		
	available_patches.clear()
	if mineral_count:
		for i in decor.get_child_count():
			GameUtils.clear_node(decor.get_child(i))
			available_patches.append(i)
		
		for i in range(randi_range(2,4)):
			var mineral_sprite := Sprite2D.new()
			
			mineral_sprite.texture = MINERAL_CLUSTER_TEXS[type][randi() % MINERAL_CLUSTER_TEXS[type].size()]
			var cluster = available_patches.pick_random()
			available_patches.erase(cluster)
			decor.get_child(cluster).add_child(mineral_sprite)
			mineral_sprite.rotation = 2*PI * randf()
		
func _physics_process(delta: float) -> void:
	if flash_time > 0:
		flash_time -= delta
		if flash_time < 0:
			flash_time = 0
	if flash_time:
		if not animation_player.is_animation_active():
			animation_player.play("flash")
		broken_sprite.visible = true
	else:
		if animation_player.is_animation_active():
			animation_player.play("RESET")
		broken_sprite.visible = (structure / max_structure) < .8
	broken_sprite.frame = get_broken_sprite_id()
	
		
func take_damage(damage:float):
	structure -= damage
	GSLogger.debug("%s takes damage. Structure = %2f" % [name, structure])
	flash_time = .5
	if structure < 0:
		collision_layer = 0
		destroy()

func get_broken_sprite_id()->int:
	var pct:float = structure / max_structure
	if flash_time:
		if pct > .8:
			return 0
		elif pct > .5:
			return 1
		else:
			return 2
	else:
		if pct > .5:
			return 0
		elif pct > .25:
			return 1
		else:
			return 2
		
func set_richness(richness:float):
	var acc := 0.0
	mineral_count = RICHNESS_MINERALS[RICHNESS_WEIGHTS.size() -1] + randi_range(-1,1)	

	for i in RICHNESS_WEIGHTS.size():
		acc += RICHNESS_WEIGHTS[i]
		if richness < acc:
			mineral_count = RICHNESS_MINERALS[i] + randi_range(-1,1)
			break
	#print ("mineral: ", mineral_count)
func destroy():
	animation_player.play("explode")
	for patch:Node2D in patches.get_children():
		if patch.get_child_count():
			var c:Cargo = Cargo.create(type)
			c.global_position = patch.global_position
			c.global_rotation = patch.get_child(0).global_rotation
			c.linear_velocity = (Vector2.RIGHT * randf_range(50,150)).rotated(randf()*2*PI) 
			get_parent().add_child(c)
	await animation_player.animation_finished
	queue_free()
