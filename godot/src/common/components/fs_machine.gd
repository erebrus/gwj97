@tool
class_name FSM extends Node

@export 
var agent:Node2D
@export 
var animation_player:AnimationPlayer
@export
var start_state:State
@export
var debug := false
var current_state:State
func _ready():
	
	
	if start_state:
		change_state(start_state.name)

func change_state(state_name:String):
	GSLogger.trace("Changing state to %s" % [state_name])
	var next_state:State = find_state(state_name)
	if next_state == null:
		GSLogger.error("Can't find state %s. Aborting change." % [state_name])
		return
	var next_states := get_state_hierarchy(next_state)
	var prev_states:Array[State]
	if current_state:
		prev_states = get_state_hierarchy(current_state)
		for state in prev_states:
			if not state in next_states:
				state.do_exit()
	current_state = next_state
	next_states.reverse()
	for state in next_states:
		if not state in prev_states:
			state.do_enter()
	GSLogger.debug("Changed state to %s" % [state_name])

func find_state(state_name:String)->State:
	for child in get_children():
		var state := _find_state_in_state(child, state_name)
		if state:
			return state
	return null

func _find_state_in_state(node, state_name:String)->State:
	if not node:
		return null 
	if node.name == state_name and node is State:
		return node
	for child in node.get_children():
		var state:State = _find_state_in_state(child, state_name)
		if state:
			return state
	return null
	
func do_update(delta: float) -> void:
	if current_state:
		#TODO allow state interruption on changing 
		var states := get_state_hierarchy(current_state)
		states.reverse()
		for state in states:
			state.do_update(delta)

func get_state_hierarchy(_state:State)->Array[State]:
	var ret:Array[State]
	var state = _state
	while state and not (state is FSM):
		if state is State:
			ret.append(state)
		if not state.get_parent():
			break
		else:
			state = state.get_parent()
	return ret
	
func is_state_active(state_name:String)->bool:
	var states := get_state_hierarchy(current_state)
	for s in states:
		if s.name == state_name:
			return true
	return false
