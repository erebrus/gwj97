class_name StationSkills extends MarginContainer


signal buy_skill_requested(skill: StationSkill)


@onready var tree: SJSkillTreeControl = %SkillTree
@onready var skill_details: Container = %SelectedSkillDetails

@onready var skill_name: Label = %SkillName


var selected_skill: StationSkill


func _ready() -> void:
	_close()
	
	tree.skill_tree = Globals.skills
	
	Events.ship_docked.connect(show)
	Events.ship_undocked.connect(_close)
	
	tree.skill_selected.connect(_on_skill_selected)
	tree.skill_pressed.connect(_on_skill_pressed)
	

func _close() -> void:
	hide()
	skill_details.hide()
	selected_skill = null


func _on_skill_selected(skill: SJSkill) -> void:
	selected_skill = skill as StationSkill
	if selected_skill == null:
		return
	
	skill_details.show()
	
	skill_name.text = selected_skill.name
	
	# TODO: show skill details


func _on_skill_pressed(skill: SJSkill) -> void:
	if skill != selected_skill:
		return
		
	if not skill.is_available():
		return
	
	buy_skill_requested.emit(selected_skill) 
