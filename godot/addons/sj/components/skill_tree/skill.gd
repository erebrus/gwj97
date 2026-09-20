class_name SJSkill extends Resource


signal bought


@export var id: String
@export var requirements: Array[String]

@export var is_dummy: bool = false
@export var is_bought: bool


func buy() -> void:
	assert(not is_bought)
	is_bought = true
	bought.emit()


func create_dummy_requirement(parent: SJSkill) -> SJSkill:
	var dummy = SJSkill.new()
	if parent.is_dummy:
		var i = parent.id.rfind("_")
		var parent_name = parent.id.substr(0, i)
		var suffix = parent.id.substr(i)
		var count = int(suffix) + 1
		dummy.id = parent_name + "_%s" % count
	else:
		dummy.id = parent.id + "_dummy_1"
	
	dummy.is_dummy = true
	dummy.requirements.append(parent.id)
	
	return dummy


func _to_string() -> String:
	return id
