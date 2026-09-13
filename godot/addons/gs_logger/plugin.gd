@tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("GSLogger", "res://addons/gs_logger/logger.gd")
	
	
func _exit_tree():
	remove_autoload_singleton("GSLogger")
