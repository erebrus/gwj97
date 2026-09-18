@tool
extends State


func _on_enter():
	(fsm.agent as Alien).lost_target.connect(_on_lost_target)

func _on_exit():
	(fsm.agent as Alien).lost_target.disconnect(_on_lost_target)

	
func _on_update(_delta:float):
	var agent := (fsm.agent as Alien)
	if agent.is_target_in_sight():
		agent.set_target_position(agent.target.global_position)

func _on_lost_target():
	fsm.change_state("cruise")
