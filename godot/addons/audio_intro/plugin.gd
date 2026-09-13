# res://addons/audio_intro/plugin.gd
@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type(
		"IntroAudioStreamPlayer",           # Node name in editor
		"AudioStreamPlayer",                # Parent class
		preload("res://addons/audio_intro/intro_audio_stream_player.gd"),
		preload("res://addons/audio_intro/icon.svg")  # Optional icon
	)

func _exit_tree():
	remove_custom_type("IntroAudioStreamPlayer")
