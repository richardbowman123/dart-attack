extends Node
class_name DrinkVisionEffect

## Drunk vision overlay — spatial shader on a 3D quad + warning text.
## Created by DrinkManager autoload. Do not instantiate directly.
##
## The quad is sized to fill the camera's FOV and positioned just in front
## of it. depth_test_disabled draws over everything. render_priority 127
## ensures it renders last so the screen texture has the full 3D scene.
##
## When the scene changes (menu, match, test), the old quad is freed with
## the old camera and a new one is created automatically.
##
## Shader effects by drinks level:
##   0–3:  No effect (quad hidden)
##   4–6:  Mild blur + slight double vision + warm tint starting
##   7–8:  Stronger blur, noticeable double image, amber colour shift
##   9–10: Heavy blur, strong double vision, screen sway, vignette

var _material: ShaderMaterial
var _overlay: MeshInstance3D
var _tracked_camera: Camera3D

var _warning_layer: CanvasLayer
var _warning_label: Label
var _warning_tween: Tween

var _current_intensity: float = 0.0
var _target_intensity: float = 0.0

const TRANSITION_SPEED := 1.5  # Intensity change per second (smooth ramp)
const OVERLAY_DIST := 0.3      # How far in front of the camera (must be > near clip 0.05)


func _ready() -> void:
	_setup_material()
	_build_warning_ui()
	DrinkManager.drinks_changed.connect(_on_drinks_changed)
	DrinkManager.warning_triggered.connect(_show_warning)


func _setup_material() -> void:
	var shader := load("res://shaders/drunk_vision.gdshader") as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.render_priority = 127  # Render last in transparent pass
	_material.set_shader_parameter("intensity", 0.0)
	_material.set_shader_parameter("sway_time", 0.0)


func _build_warning_ui() -> void:
	_warning_layer = CanvasLayer.new()
	_warning_layer.layer = 25  # Above everything — always readable
	add_child(_warning_layer)

	_warning_label = Label.new()
	UIFont.apply(_warning_label, UIFont.BODY)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_warning_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_warning_label.add_theme_constant_override("shadow_offset_x", 2)
	_warning_label.add_theme_constant_override("shadow_offset_y", 2)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_label.position = Vector2(40, 520)
	_warning_label.size = Vector2(640, 240)
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_label.visible = false
	_warning_layer.add_child(_warning_label)


func _process(delta: float) -> void:
	# Smooth transition toward target intensity
	_current_intensity = move_toward(_current_intensity, _target_intensity, TRANSITION_SPEED * delta)

	# Find the active 3D camera (changes when scenes change)
	var cam := get_viewport().get_camera_3d()
	if cam != _tracked_camera:
		_tracked_camera = cam
		_overlay = null  # Old overlay freed with old camera's scene

	if cam == null:
		return

	var need_overlay := _current_intensity > 0.001 or _target_intensity > 0.001

	if need_overlay:
		if _overlay == null or not is_instance_valid(_overlay):
			_create_overlay(cam)
		_overlay.visible = true
		_material.set_shader_parameter("intensity", _current_intensity)
		_material.set_shader_parameter("sway_time", float(Time.get_ticks_msec()) / 1000.0)
	elif _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false


func _create_overlay(cam: Camera3D) -> void:
	# Size the quad to fill the camera's field of view, plus 20% margin
	# so edges are covered even during sway.
	var half_h := OVERLAY_DIST * tan(deg_to_rad(cam.fov * 0.5))
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / vp.y
	var half_w := half_h * aspect

	var quad := QuadMesh.new()
	quad.size = Vector2(half_w * 2.4, half_h * 2.4)

	_overlay = MeshInstance3D.new()
	_overlay.mesh = quad
	_overlay.material_override = _material
	_overlay.position = Vector3(0.0, 0.0, -OVERLAY_DIST)  # In front of camera
	_overlay.extra_cull_margin = 16384.0   # Never frustum-cull this
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	cam.add_child(_overlay)


func _on_drinks_changed(_level: int) -> void:
	_target_intensity = DrinkManager.get_effect_intensity()


func _show_warning(text: String) -> void:
	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()

	_warning_label.text = text
	_warning_label.modulate.a = 1.0
	_warning_label.visible = true

	_warning_tween = create_tween()
	# Show for 3 seconds, then fade out over 1 second
	_warning_tween.tween_interval(3.0)
	_warning_tween.tween_property(_warning_label, "modulate:a", 0.0, 1.0)
	_warning_tween.tween_callback(func() -> void: _warning_label.visible = false)
