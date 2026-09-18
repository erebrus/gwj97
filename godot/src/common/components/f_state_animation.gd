@tool
class_name AnimationState extends State

@export
var anim:String
@export
var optional_next_state:String

func do_enter():
	if anim:
		if optional_next_state:
			fsm.animation_player.animation_finished.connect(_next_state)
		else:
			fsm.animation_player.animation_finished.connect(_on_animation_finished_internal)
		
		fsm.animation_player.play(anim, 0)
		fsm.animation_player.advance(0)
		
	_on_enter()
func do_exit():
	if anim:
		if optional_next_state:
			fsm.animation_player.animation_finished.disconnect(_next_state)
		else:
			fsm.animation_player.animation_finished.disconnect(_on_animation_finished_internal)
	_on_exit()

func _on_animation_finished_internal(anim_name:String):
	if anim_name == anim:
		_on_animation_finished()
		
func _on_animation_finished():
	pass

func _next_state(_anim:String):
	if optional_next_state:
		fsm.change_state(optional_next_state)
