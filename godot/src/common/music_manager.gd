class_name MusicManager extends Node


@onready var menu_music: AudioStreamPlayer = $menu_music
@onready var game_music_stream_player: AudioStreamPlayer = $game_music
@onready var game_music_node: Node = $game_music


@onready var game_music_stream:AudioStreamSynchronized = game_music_stream_player.stream if game_music_stream_player else null

var current_game_music_id = 0#Types.GameMusic.EASY
var default_music_volume:float = 0.0 

func _ready():
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		default_music_volume = AudioServer.get_bus_volume_db(music_bus)
	else:
		GSLogger.warn("Cannot set default music volume. Can't find Music bus.")

func play_menu_music():
	fade_in_menu_music(0)

func play_game_music():
	fade_in_game_music(0)
	
func fade_in_menu_music(time:float=1.0):
	fade_in_stream(menu_music,time)

func fade_menu_music(time:float=1.0):
	fade_stream(menu_music, time)
	
func fade_in_game_music(time:float=1.0):
	if game_music_stream_player:
			fade_in_stream(game_music_stream_player, time)
	else:
		for stream in get_children():
			if stream is AudioStreamPlayer:
				fade_in_stream(stream, time)
				

func fade_game_music(time:float=1.0):
	if game_music_stream_player:
		fade_stream(game_music_stream_player, time)
	else:
		for stream in get_children():
			if stream is AudioStreamPlayer:
				fade_stream(stream, time)
		
func play_music(node:AudioStreamPlayer):
	if not node.playing:
		node.play()
	
func reset_game_music():
	current_game_music_id = 0
	if not game_music_stream:
		return
	for i in range(game_music_stream.stream_count):
		if i == current_game_music_id:
			game_music_stream.set_sync_stream_volume(i,0)
		else:
			game_music_stream.set_sync_stream_volume(i,-60)

func fade_in_stream(node:AudioStreamPlayer, duration := 1.0):
	if duration > 0:
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		node.volume_db=-20
		node.play()
		tween.tween_property(node,"volume_db",default_music_volume , duration)
		await tween.finished
	else:
		node.volume_db=default_music_volume
		node.play()
	GSLogger.info("%s playing %s volume:%f" % [node.name, node.playing, node.volume_db])
	

func fade_stream(node:AudioStreamPlayer, duration := 1.0):
	if duration >0:
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node,"volume_db",-20 , duration)
		await tween.finished
	node.stop()
	

func _helper_set_volume(volume_db:float, id:int):
	game_music_stream.set_sync_stream_volume(id, volume_db)
	

func change_game_music_to(new_id:Types.GameMusic, time:=1.0):
	change_game_music_to_with_transition(new_id, null, time)

func change_music_in_sync_stream(current_id:Types.GameMusic, new_id:Types.GameMusic, transition:AudioStreamPlayer, time:=1.0):
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(_helper_set_volume.bind(current_id),0,-60, time)
	tween.parallel().tween_method(_helper_set_volume.bind(new_id),-60,0, time).set_ease(Tween.EASE_OUT)
	if transition:
		transition.play()
	await tween.finished
		
func change_game_music_to_with_transition(new_id:Types.GameMusic, transition:AudioStreamPlayer, time:=1.0):
	if new_id == current_game_music_id:
		return
	if game_music_stream:		
		await change_music_in_sync_stream(current_game_music_id, new_id, transition, time)
		current_game_music_id = new_id
		GSLogger.info("Music changed to: %s" % new_id)
	else:
		if new_id >= game_music_node.get_child_count():
			GSLogger.warn("Tried to change to invalid music: %d" % new_id)
			return
		var current = game_music_node.get_child(current_game_music_id)
		var next = game_music_node.get_child(new_id)
		await crossfade_streams_with_transition(current,next, transition, time)
		current_game_music_id = new_id

func crossfade_streams(current:AudioStreamPlayer, next:AudioStreamPlayer, time:=1.0):
	crossfade_streams_with_transition(current, next, null, time)
	
func crossfade_streams_with_transition(current:AudioStreamPlayer, next:AudioStreamPlayer, transition:AudioStreamPlayer, time:=1.0):
	if transition:
		transition.play()
	fade_in_stream(next, time)
	await fade_stream(current, time)
		
			
