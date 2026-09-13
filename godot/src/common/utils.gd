extends Node

func clear_node(node:Node, free_nodes:=true):

	while node.get_child_count() > 0 :
		var child = node.get_child(0)
		node.remove_child(child)
		if free_nodes:
			child.queue_free()

func _array_interect(source: Array, other: Array) -> void:
	var result: Array
	for i in source:
		if other.has(i):
			result.append(i)
	
	source.assign(result)
	

func read_csv_file(path: String, skip_headers: bool = false) -> Array[Array]:
	var data: Array[Array]
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		GSLogger.error("Failed to open file: ", path)
		return data

	while not file.eof_reached():
		var line: Array[String]
		
		for cell in file.get_csv_line(","):
			line.append(cell.strip_edges())
		data.append(line)
	
	file.close()
	
	if skip_headers:
		return data.slice(1)
	else:
		return data
	

func parse_list(string: String) -> Array[String]:
	var list: Array[String]
	for item in string.split(";"):
		list.append(item.strip_edges())
	return list

func load_resources(path: String) -> Array:
	var result: Array[Resource]
	GSLogger.info("Loading resources in %s" % path)
	
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir():
				var child_results = load_resources(path.path_join(file_name))
				result.append_array(child_results)
			else:
				var trimed = file_name.trim_suffix(".remap")
				if trimed.get_extension() not in ["res", "tres", "tscn"]:
					GSLogger.debug("Skipping non-resource %s/%s" % [path, file_name])
				else:
					GSLogger.debug("Loading resource %s/%s" % [path, file_name])
					
					var res = load(path.path_join(trimed))
					result.append(res)
			file_name = dir.get_next()
	else:
		GSLogger.error("An error occurred when trying to access the path.")
	
	return result

func generate_uuid_v4() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var b = PackedByteArray()
	for i in 16:
		b.append(rng.randi() % 256)
	
	# Set version 4
	b[6] = (b[6] & 0x0f) | 0x40
	# Set variant bits
	b[8] = (b[8] & 0x3f) | 0x80
	
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
		b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
	]


static func get_seconds_as_time(seconds:float)->String:
	return "%02d:%02d" % [floor(seconds/60), int(seconds) % 60]
