extends Node

## UIFont — autoload that provides Bungee font at standardised size tiers.
## Usage: UIFont.apply(my_label, UIFont.HEADING)
##        UIFont.apply_button(my_button, UIFont.SUBHEADING)

# Size tiers — designed for 720x1280 mobile viewport, must be bold and readable
const DISPLAY := 120
const SCREEN_TITLE := 64
const HEADING := 48
const SUBHEADING := 38
const BODY := 30
const CAPTION := 24

var _font: Font

func _ready() -> void:
	_font = load("res://fonts/Bungee-Regular.ttf")

## Apply Bungee font and size to a Label
func apply(label: Label, size: int) -> void:
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)

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
