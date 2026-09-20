@tool
class_name SJSkillNode extends MarginContainer


signal selected(skill: SJSkill)
signal pressed(skill: SJSkill)

signal selected_changed
signal available_changed

signal transform_changed

@export var root_input_node: Control

@export var skill: SJSkill:
	set(value):
		if value == skill:
			return
		skill = value
		if is_node_ready():
			setup()


var is_selected: bool:
	set(value):
		if value == is_selected:
			return
		is_selected = value
		selected_changed.emit()
		_update_selected()

var is_available: bool:
	set(value):
		if value == is_available:
			return
		is_available = value
		available_changed.emit()


func _ready() -> void:
	assert(root_input_node != null)
	root_input_node.gui_input.connect(_on_gui_input)
	set_notify_transform(true)
	setup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		transform_changed.emit()


func setup() -> void:
	if skill == null:
		return
	
	modulate.a = 0 if skill.is_dummy else 1


func _update_selected() -> void:
	if is_selected:
		selected.emit(skill)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.is_pressed() and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			pressed.emit(skill)
			is_selected = true
