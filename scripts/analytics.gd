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
var _session_start_ms: int = 0
var _is_web: bool = false
var _connected: bool = false
var _retry_count: int = 0
const MAX_RETRIES: int = 60


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return
	_try_connect()


func _try_connect() -> void:
	if _connected:
		return
	_read_bridge()
	if not _connected:
		_retry_count += 1
		if _retry_count < MAX_RETRIES:
			get_tree().create_timer(0.5).timeout.connect(_try_connect)
		else:
			print("[Analytics] Gave up waiting for auth token after 30s")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end_session()


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
		print("[Analytics] Connected (attempt %d)" % (_retry_count + 1))


# ── SESSION ──

func _start_session() -> void:
	_session_start_ms = Time.get_ticks_msec()
	# Check if the login page already created a session (index.html does this now)
	var existing_id = JavaScriptBridge.eval("window.dartAttackSession ? window.dartAttackSession.id : ''")
	if existing_id and str(existing_id) != "":
		_session_id = str(existing_id)
		print("[Analytics] Reusing session from login page: %s" % _session_id)
	else:
		# Generate UUID client-side — available immediately for all events
		_session_id = str(JavaScriptBridge.eval("crypto.randomUUID()"))
		_post("sessions", {"id": _session_id, "player_id": _player_id})
		JavaScriptBridge.eval(
			"window.dartAttackSession = {id: '%s', startedAt: Date.now()};" % _session_id
		)


func _end_session() -> void:
	if _session_id.is_empty() or not _connected:
		return
	var duration := int((Time.get_ticks_msec() - _session_start_ms) / 1000)
	# Use JavaScript fetch with keepalive for reliable delivery during page close
	var js := "fetch('%s/rest/v1/sessions?id=eq.%s', {method: 'PATCH', headers: {'apikey': '%s', 'Authorization': 'Bearer ' + (window.dartAttackSupabase ? window.dartAttackSupabase.accessToken : ''), 'Content-Type': 'application/json'}, body: JSON.stringify({ended_at: new Date().toISOString(), duration_seconds: %d}), keepalive: true});" % [_supabase_url, _session_id, _supabase_key, duration]
	JavaScriptBridge.eval(js)


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


func _post(table: String, data: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var url := _supabase_url + "/rest/v1/" + table
	var token := _get_fresh_token()
	var headers: PackedStringArray = [
		"apikey: " + _supabase_key,
		"Authorization: Bearer " + token,
		"Content-Type: application/json",
	]

	var body := JSON.stringify(data)
	var _t := table

	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _response_body: PackedByteArray) -> void:
		if response_code < 200 or response_code >= 300:
			print("[Analytics] POST to %s failed (HTTP %d)" % [_t, response_code])
		http.queue_free()
	)

	http.request(url, headers, HTTPClient.METHOD_POST, body)
