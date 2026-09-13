class_name UiSfx extends Node

@export var button_press_auto_connect: bool = true
@export var button_hover_auto_connect: bool = true

@export var texture_button_press_auto_connect: bool = true
@export var texture_button_hover_auto_connect: bool = true

@onready var click_sfx = $click_sfx
@onready var hover_sfx = $hover_sfx


func _ready() -> void:
	if button_press_auto_connect \
	or button_hover_auto_connect \
	or texture_button_hover_auto_connect \
	or texture_button_press_auto_connect:
		_connect_all_buttons(get_tree().root)
		get_tree().node_added.connect(_on_node_added)
	

func _connect_all_buttons(node: Node) -> void:
	_connect_node(node)
	for child in node.get_children(true):
		_connect_all_buttons(child)
	

func _connect_node(node: Node) -> void:
	if node is Button:
		if button_press_auto_connect:
			node.pressed.connect(_on_button_pressed)
		if button_hover_auto_connect:
			node.mouse_entered.connect(_on_button_entered)
	if node is TextureButton:
		if texture_button_press_auto_connect:
			node.pressed.connect(_on_button_pressed)
		if texture_button_hover_auto_connect:
			node.mouse_entered.connect(_on_button_entered)
		

func _on_node_added(node: Node) -> void:
	_connect_node(node)
	

func _on_button_pressed() -> void:
	click_sfx.play()
	

func _on_button_entered() -> void:
	hover_sfx.play()
	
