class_name StationSkill extends SJSkill


@export var name: String

@export_multiline() var description: String

@export var icon: Texture2D
@export var price: Dictionary[Types.Resources, int]


@warning_ignore("shadowed_variable")
static func create_random(id: String, ...args: Array) -> StationSkill:
	var skill = StationSkill.new()
	
	if args.is_empty():
		skill.id = id
	else:
		var parents: Array[String]
		for parent in args:
			if parent is SJSkill:
				parents.append(parent.id)
			
		skill.requirements = parents
		
		skill.id = "%s_%s" % [".".join(parents), id]
	
	skill.name = skill.id
	
	var resources = Types.Resources.values()
	resources.shuffle()
	for i in 2:
		var resource: Types.Resources = resources.pop_front()
		var quantity = randi_range(1,20)
		skill.price[resource] = quantity
	
	return skill
