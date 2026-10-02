@tool
extends EditorPlugin


var _toolbar: HBoxContainer
var _tree: SJSkillTree



func _enter_tree() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.hide()

	var shuffle_button := Button.new()
	shuffle_button.text = "Shuffle"
	shuffle_button.tooltip_text = "Regenerate the layout of the selected skill tree"
	shuffle_button.icon = EditorInterface.get_editor_theme().get_icon("RandomNumberGenerator", "EditorIcons")
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	_toolbar.add_child(shuffle_button)

	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.queue_free()
	_toolbar = null
	_tree = null


func _handles(object: Object) -> bool:
	return object is SJSkillTree


func _edit(object: Object) -> void:
	_tree = object as SJSkillTree


func _make_visible(visible: bool) -> void:
	_toolbar.visible = visible


func _on_shuffle_pressed() -> void:
	if _tree == null:
		return
	
	SJSkillTreeSugiyamaLayoutGenerator.new().generate(_tree)
	EditorInterface.mark_scene_as_unsaved()
