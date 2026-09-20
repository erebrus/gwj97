@tool
class_name StationSkillNode extends SJSkillNode

@export var available_stylebox: StyleBox
@export var unavailable_stylebox: StyleBox
@export var selected_stylebox: StyleBox
@export var bought_stylebox: StyleBox


@onready var panel: PanelContainer = %NodePanel


func _ready() -> void:
	if skill == null and get_tree().current_scene == self:
		skill = StationSkill.create_random("a")
	
	super._ready()
	
	available_changed.connect(_update_style)
	selected_changed.connect(_update_style)


func setup() -> void:
	super.setup()
	if skill == null:
		return
	
	if skill.is_dummy:
		return
	
	var station_skill := skill as StationSkill
	
	_update_style()
	%Icon.texture = station_skill.icon
	
	var container := %PriceContainer
	for child in container.get_children():
		child.queue_free()
	
	for resource in station_skill.price:
		var label := ResourceLabel.create(resource, skill.price[resource])
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
		container.add_child(label)
	
	skill.bought.connect(_update_style)


func _update_style() -> void:
	if panel.has_theme_stylebox_override("panel"):
		panel.remove_theme_stylebox_override("panel")
	
	var style: StyleBox
	if is_selected:
		style = selected_stylebox
	elif skill.is_bought:
		style = bought_stylebox
	elif is_available:
		style = available_stylebox
	else:
		style = unavailable_stylebox
	
	panel.add_theme_stylebox_override("panel", style)
		
