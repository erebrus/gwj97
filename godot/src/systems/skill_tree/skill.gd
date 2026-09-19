class_name SkillTreeSkill extends Resource


@export var id: String
@export var name: String
@export var description: String

@export var icon: Texture2D
@export var requirements: Array[String]
@export var price: Dictionary[Types.Resources, int]


@warning_ignore("shadowed_variable")
static func create_random(id: String, ...requirements: Array) -> SkillTreeSkill:
	var skill = SkillTreeSkill.new()
	skill.id = id
	skill.name = id
	
	for r in requirements:
		if r is SkillTreeSkill:
			skill.requirements.append(r.id)
	
	var resources = Types.Resources.values()
	resources.shuffle()
	for i in 2:
		var resource: Types.Resources = resources.pop_front()
		var quantity = randi_range(1,20)
		skill.price[resource] = quantity
	
	return skill

func _to_string() -> String:
	return id
