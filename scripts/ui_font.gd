extends Node

## UIFont — autoload that provides Bungee font at standardised size tiers.
## Usage: UIFont.apply(my_label, UIFont.HEADING)
##        UIFont.apply_button(my_button, UIFont.SUBHEADING)

# Size tiers — designed for 720x1280 mobile viewport, must be bold and readable
const DISPLAY := 120
const SCREEN_TITLE := 64
const HEADING := 52
const SUBHEADING := 42
const BODY := 34
const CAPTION := 28

# Portrait image height tiers — use these for all character/opponent images
const PORTRAIT_XS := 80    # Thumbnail — text-heavy cards where image is secondary
const PORTRAIT_S := 120    # Small — companion panels, text & buttons dominate
const PORTRAIT_M := 180    # Medium — first introduction of a character
const PORTRAIT_ML := 220   # Fairly large — prominent character, busy card
const PORTRAIT_L := 260    # Large — full focus, player star snapshots, big wins
const PORTRAIT_XL := 320   # Very large — hero moment, max impact

var _font: Font

func _ready() -> void:
	_font = load("res://fonts/Bungee-Regular.ttf")
	# Bungee doesn't include symbol characters (★☆ etc).
	# Use Godot's built-in font as fallback so stars render on all platforms.
	_font.fallbacks = [ThemeDB.fallback_font]

## Apply Bungee font and size to a Label
func apply(label: Label, size: int) -> void:
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)

## Apply Bungee font and size to a RichTextLabel
func apply_rich(rtl: RichTextLabel, size: int) -> void:
	rtl.add_theme_font_override("normal_font", _font)
	rtl.add_theme_font_size_override("normal_font_size", size)

## Apply Bungee font and size to a Button
func apply_button(button: Button, size: int) -> void:
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", size)

## Apply Bungee font and size to a LabelSettings (for splash screen styled text)
func make_label_settings(size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = size
	settings.font_color = color
	return settings
