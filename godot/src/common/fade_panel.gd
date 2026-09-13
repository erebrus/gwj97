class_name FadePanel extends ColorRect

signal fade_in_completed
signal fade_out_completed

@export var fade_out_duration := 1.0
@export var fade_in_duration := 1.0


func _ready():
	show()
	set_fade(true)
	

func set_fade(val:bool):
	modulate.a = float(val)
	

func is_faded()->bool:
	return modulate.a==1
	

func fade_in():
	set_fade(true)
	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0, fade_in_duration)
	await tween.finished
	fade_in_completed.emit()
	

func fade_out():
	set_fade(false)
	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1, fade_out_duration)
	await tween.finished
	fade_out_completed.emit()
	
