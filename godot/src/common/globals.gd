extends Node

const START_SCENE_PATH = "res://src/start_screen/start_screen.tscn"
const GAME_SCENE_PATH = "res://src/game.tscn"

const GameDataPath = "user://conf.cfg"
var config:Settings = Settings.load_or_create(GameDataPath, false)

var in_game:=false
var in_dialogue:=false
var game:Game
var run_id :int = round(Time.get_unix_time_from_system())
var uuid:String:
	get:
		return config.uuid

var game_version: String:
	get():
		return ProjectSettings.get_setting("application/config/version")
	

@onready var music_manager: MusicManager = $MusicManager
@onready var ui_sfx: UiSfx = $UiSfx


func _ready():
	_init_logger()
	
	GSLogger.info("Game version: %s" % game_version)
	
	if get_tree().current_scene.scene_file_path == GAME_SCENE_PATH:
		start_game()
	

func go_to_main_menu():
	get_tree().change_scene_to_file(START_SCENE_PATH)
	

func start_game():
	GSLogger.info("Starting Game")
	in_game=true
	
	music_manager.fade_menu_music()
	await get_tree().create_timer(1).timeout
	
	if get_tree().current_scene.scene_file_path != GAME_SCENE_PATH:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
		
	music_manager.fade_in_game_music()
	

func _init_logger():
	GSLogger.set_logger_level(GSLogger.LOG_LEVEL_INFO)
	GSLogger.set_logger_format(GSLogger.LOG_FORMAT_MORE)
	var console_appender:Appender = GSLogger.add_appender(ConsoleAppender.new())
	console_appender.logger_format=GSLogger.LOG_FORMAT_FULL
	console_appender.logger_level = GSLogger.LOG_LEVEL_INFO
	var file_appender:Appender = GSLogger.add_appender(FileAppender.new("res://debug.log"))
	file_appender.logger_format=GSLogger.LOG_FORMAT_FULL
	file_appender.logger_level = GSLogger.LOG_LEVEL_DEBUG
	GSLogger.info("GSLogger initialized.")


func do_lose():
	get_tree().quit()

func do_win():
	get_tree().quit()
