class_name FeedbackManager extends Node

const DISCORD_AUTO_FEEDBACK_URL:=""# paste your Discord webhook URL here
const DISCORD_MANUAL_FEEDBACK_URL := "" # paste your Discord webhook URL here


@export
var enabled:=true

var limited := false
var requests:Array[int]
func _ready():
	#TODO connect to events you want to trigger auto feedback
	pass
func get_new_http_request() -> HTTPRequest:
	var ret:= HTTPRequest.new()
	add_child(ret)
	ret.request_completed.connect(_on_request_completed.bind(ret))
	return ret

func read_metrics_file() -> PackedByteArray :
	return  FileAccess.get_file_as_bytes(Globals.FEEDBACK_METRICS_FILE_PATH)

func read_last_metrics_file() -> PackedByteArray :
	return  FileAccess.get_file_as_bytes(Globals.METRICS_FILE_PATH)

func get_feedback_filename() -> String:
	return "%s_%s_%s.json" % [Globals.uuid, Globals.config.username, Globals.run_id]

func send_feedback_form_no_attachments(type:String, title:String, username:String, description:String) -> void:
	var level_name :String= Globals.game.get_level().scene_file_path if Globals.game.get_level() else "N/A"
	var content := "**%s**\nTitle: %s\nReporter: %s\nLevel: %s\nDescription: %s" % [type, title, username, level_name, description]
	var payload_json := JSON.stringify({"content": content})
	var headers := ["Content-Type: application/json"]
	var err := get_new_http_request().request(DISCORD_MANUAL_FEEDBACK_URL, headers, HTTPClient.METHOD_POST, payload_json)
	if err != OK:
		GSLogger.error("Failed to start Discord webhook request: %s" % [err])

func send_feedback_form(type:String, title:String, username:String, description:String, _screenshot_bytes:PackedByteArray) -> void:
	Globals.config.username = username
	var file_bytes := read_metrics_file()
	if file_bytes.is_empty():
		GSLogger.warn("Failed to read feedback metrics file for webhook upload. Sending just form.")
		send_feedback_form_no_attachments(type, title, username, description)
		return
	var file_name :String= get_feedback_filename()
	if username.is_empty():
		username = "N/A"
	var level_name :String= Globals.game.get_level().scene_file_path if Globals.game.get_level() else "N/A"
	var content := "**%s**\nTitle: %s\nReporter: %s\nLevel: %s\nDescription: %s" % [type, title, username, level_name, description]
	var payload_json := JSON.stringify({"content": content})

	var boundary := "GodotFeedback%d" % Time.get_ticks_msec()
	var body := PackedByteArray()
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"payload_json\"\r\n".to_utf8_buffer())
	body.append_array("Content-Type: application/json\r\n\r\n".to_utf8_buffer())
	body.append_array(payload_json.to_utf8_buffer())
	body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"files[0]\"; filename=\"%s\"\r\n" % file_name).to_utf8_buffer())
	body.append_array("Content-Type: application/json\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())
	if not _screenshot_bytes.is_empty():
		body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
		body.append_array("Content-Disposition: form-data; name=\"files[1]\"; filename=\"screenshot.png\"\r\n".to_utf8_buffer())
		body.append_array("Content-Type: image/png\r\n\r\n".to_utf8_buffer())
		body.append_array(_screenshot_bytes)
		body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--%s--\r\n" % boundary).to_utf8_buffer())

	var headers := ["Content-Type: multipart/form-data; boundary=%s" % boundary]
	var err := get_new_http_request().request_raw(DISCORD_MANUAL_FEEDBACK_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		GSLogger.error("Failed to start Discord webhook request: %s" % [err])

func is_throttled()->bool:
	if limited:
		return true
	var now = Time.get_ticks_msec()
	while not requests.is_empty() and (now - requests[0] > 60000):
		requests.remove_at(0)
	return requests.size() > 20

func send_auto_feedback(type:String):
	Globals.metrics_manager.save_to_file(Globals.METRICS_FILE_PATH)
	if is_throttled() or not enabled or (Globals.game and Globals.game.get_level() and Globals.game.get_level().skipped):
		return
	await get_tree().process_frame
	var file_bytes := read_last_metrics_file()
	if file_bytes.is_empty():
		GSLogger.warn("Failed to read feedback metrics file for webhook upload. Aborting auto feedback.")
		return
	var file_name :String= get_feedback_filename()
	var username:String = Globals.config.username
	if username.is_empty():
		username = "N/A"
	var level_name :String= Globals.game.get_level().scene_file_path if (Globals.game and Globals.game.get_level()) else "N/A"
	var stats = ""
	#var level_stats = Globals.game.history_manager.get_history()[-1] if (Globals.game and not Globals.game.history_manager.get_history().is_empty()) else null
	#var stats= "N/A" if not level_stats else " Cards:%d, Coins:%d, Time:%s " % [level_stats.cards_played, level_stats.coins_collected, GameUtils.get_seconds_as_time(level_stats.get_level_time())]
	var content := "**Auto-Feeback**\nUUID: %s\nReporter: %s\nLevel: %s\nRun: %s\nType: %s\nStats: %s" % [Globals.uuid, username, level_name, Globals.run_id, type, stats]
	var payload_json := JSON.stringify({"content": content})

	var boundary := "GodotFeedback%d" % Time.get_ticks_msec()
	var body := PackedByteArray()
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array("Content-Disposition: form-data; name=\"payload_json\"\r\n".to_utf8_buffer())
	body.append_array("Content-Type: application/json\r\n\r\n".to_utf8_buffer())
	body.append_array(payload_json.to_utf8_buffer())
	body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"files[0]\"; filename=\"%s\"\r\n" % file_name).to_utf8_buffer())
	body.append_array("Content-Type: application/json\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())

	body.append_array(("--%s--\r\n" % boundary).to_utf8_buffer())

	var headers := ["Content-Type: multipart/form-data; boundary=%s" % boundary]
	var err := get_new_http_request().request_raw(DISCORD_AUTO_FEEDBACK_URL, headers, HTTPClient.METHOD_POST, body)
	requests.append(Time.get_ticks_msec())

	if err != OK:
		GSLogger.error("Failed to start Discord webhook request: %s" % [err])
		
		
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, _body: PackedByteArray,  req:HTTPRequest) -> void:
	var rate_limit_remaining := ""
	var rate_limit_reset_after := ""
	for h in headers:
		var lower := h.to_lower()
		if lower.begins_with("x-ratelimit-remaining:"):
			rate_limit_remaining = h.substr(h.find(":") + 1).strip_edges()
		elif lower.begins_with("x-ratelimit-reset-after:"):
			rate_limit_reset_after = h.substr(h.find(":") + 1).strip_edges()
	GSLogger.info("Discord rate limit: remaining=%s, reset_after=%s" % [rate_limit_remaining, rate_limit_reset_after])

	if result != HTTPRequest.RESULT_SUCCESS:
		GSLogger.error("Discord webhook request failed: result=%s" % [result])
		if result == 429:
			limited = true
			GSLogger.warn("Disabling feedback manager for 2 minutes." )
			await get_tree().create_timer(120).timeout
			limited = false
			
	elif response_code < 200 or response_code >= 300:
		GSLogger.error("Discord webhook responded with code %d" % response_code)
	else:
		GSLogger.info("Feedback sent to Discord (code %d)." % response_code)
	req.queue_free()
