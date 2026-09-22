class_name SJSkill extends Resource


signal bought


@export var id: String
@export var requirements: Array[String]

@export var is_dummy: bool = false
@export var is_bought: bool

var _initialized: bool
var parents: Array[SJSkill]


func setup(skill_by_id: Dictionary[String, SJSkill]) -> void:
	parents.clear()
	for req_id in requirements:
		assert(skill_by_id.has(req_id))
		parents.append(skill_by_id[req_id])
		
	_initialized = true


func is_available() -> bool:
	if is_dummy:
		return false
	
	if not _check_initialized():
		return false
	
	for parent in parents:
		if not parent.is_bought:
			return false
	return true


func buy() -> void:
	if not is_available():
		assert(false, "Cannot buy unavailable skill")
		return
	
	if is_bought:
		assert(false, "Cannot buy already-bought skill")
		return
	
	is_bought = true
	bought.emit()


func _check_initialized() -> bool:
	assert(_initialized, "Trying to interact with uninitizalized skill. Ensure you are calling setup for each skill")
	
	return _initialized


func _to_string() -> String:
	return id
