extends Node

## Supabase analytics autoload.
## Reads auth credentials from the login page via JavaScriptBridge.
## Call Analytics.track("event_type", {data}) from anywhere in the game.
## Does nothing when running in the Godot editor — web only.

# Connection state
var _supabase_url: String = ""
var _supabase_key: String = ""
var _access_token: String = ""
var _player_id: String = ""
var _session_id: String = ""
var _session_start: float = 0.0
var _is_web: bool = false
var _connected: bool = false


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return
	_read_bridge()


func _read_bridge() -> void:
	var user_id = JavaScriptBridge.eval("window.dartAttackUser ? window.dartAttackUser.id : ''")
	var sb_url = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.url : ''")
	var sb_key = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.key : ''")
	var token = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.accessToken : ''")

	if user_id and sb_url and sb_key and token:
		_player_id = str(user_id)
		_supabase_url = str(sb_url)
		_supabase_key = str(sb_key)
		_access_token = str(token)
		_connected = true
		_start_session()
	else:
		print("[Analytics] No auth credentials found — tracking disabled")


# ── SESSION ──

func _start_session() -> void:
	_session_start = Time.get_unix_time_from_system()
	_post("sessions", {"player_id": _player_id}, true)


# ── PUBLIC API ──

func track(event_type: String, event_data: Dictionary = {}) -> void:
	if not _connected:
		return
	var payload := {
		"player_id": _player_id,
		"event_type": event_type,
		"event_data": event_data,
	}
	if _session_id != "":
		payload["session_id"] = _session_id
	_post("events", payload)


# ── HTTP ──

func _get_fresh_token() -> String:
	if _is_web:
		var token = JavaScriptBridge.eval("window.dartAttackSupabase ? window.dartAttackSupabase.accessToken : ''")
		if token:
			_access_token = str(token)
	return _access_token


func _post(table: String, data: Dictionary, capture_session_id: bool = false) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var url := _supabase_url + "/rest/v1/" + table
	var token := _get_fresh_token()
	var headers: PackedStringArray = [
		"apikey: " + _supabase_key,
		"Authorization: Bearer " + token,
		"Content-Type: application/json",
	]
	if capture_session_id:
		headers.append("Prefer: return=representation")

	var body := JSON.stringify(data)

	if capture_session_id:
		http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
			if response_code >= 200 and response_code < 300:
				var json := JSON.new()
				if json.parse(response_body.get_string_from_utf8()) == OK:
					var parsed = json.data
					if parsed is Array and parsed.size() > 0:
						_session_id = str(parsed[0].get("id", ""))
			http.queue_free()
		)
	else:
		http.request_completed.connect(func(_result: int, _response_code: int, _headers: PackedStringArray, _response_body: PackedByteArray) -> void:
			http.queue_free()
		)

	http.request(url, headers, HTTPClient.METHOD_POST, body)
