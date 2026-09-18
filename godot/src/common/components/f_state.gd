@tool

class_name State extends Node

var fsm:FSM

func _ready():
	var node:Node = self
	while node:
		if node is FSM:
			fsm = node
			break
		node = node.get_parent()
	if not fsm:
		GSLogger.error("state %s with FSM" % [name])

func do_enter():
	if fsm.debug:
		GSLogger.trace("enter %s" % [name])

	_on_enter()
	
func do_exit():
	if fsm.debug:
		GSLogger.trace("exit %s" % [name])
	_on_exit()
	
func do_update(_delta:float):
	_on_update(_delta)
	
func _on_enter():
	pass

func _on_exit():
	pass
	
func _on_update(_delta:float):
	pass
