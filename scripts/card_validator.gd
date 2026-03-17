class_name CardValidator
extends RefCounted

## Card layout validator for Dart Attack.
## Estimates whether a VBoxContainer card's contents will overflow the viewport.
##
## USAGE: Both career_intro.gd and match_results.gd call this automatically
## via their _add_card() helper. Warnings appear in the Godot console.
##
## INSTRUCTIONS FOR CLAUDE:
## When building or editing ANY card, the _add_card() helper calls
## CardValidator.validate() automatically. If a warning prints in Godot's
## console output, fix the layout BEFORE telling Richard the files are ready.
##
## Common fixes for overflow:
##   - Reduce image custom_minimum_size.y (portraits can go as low as 80px)
##   - Reduce spacer heights (15-20px between elements is usually enough)
##   - Use CAPTION (28pt) instead of BODY (34pt) for long text blocks
##   - Reduce button wrapper heights from 100 to 80
##   - For cards with toggle visibility (yes/no paths), check BOTH states
##
## Height budget: 1280px total. Leave at least 15% spare (~190px) for
## Bungee text that wraps more than expected on different devices.

const VIEWPORT_HEIGHT := 1280
const CARD_WIDTH := 640.0

# Bungee font approximate metrics (all-caps display font).
# Each uppercase character is roughly 0.62x the font size wide.
# Line height is roughly 1.35x the font size.
const BUNGEE_CHAR_WIDTH_RATIO := 0.62
const BUNGEE_LINE_HEIGHT_RATIO := 1.35


static func validate(card: VBoxContainer, card_name: String) -> void:
	var total_min := 0.0
	var total_estimated := 0.0

	for child in card.get_children():
		var min_h: float = child.custom_minimum_size.y
		total_min += min_h

		# Estimate actual height for labels with word wrap
		var est_h := min_h
		if child is Label and child.autowrap_mode != TextServer.AUTOWRAP_OFF:
			est_h = _estimate_label_height(child)
		total_estimated += maxf(min_h, est_h)

	if total_min > VIEWPORT_HEIGHT:
		push_warning("CARD OVERFLOW [%s]: min heights = %dpx > %dpx viewport. MUST FIX." % [card_name, int(total_min), VIEWPORT_HEIGHT])
	elif total_estimated > VIEWPORT_HEIGHT:
		push_warning("CARD OVERFLOW (est) [%s]: ~%dpx > %dpx viewport. Likely overflows." % [card_name, int(total_estimated), VIEWPORT_HEIGHT])
	elif total_estimated > VIEWPORT_HEIGHT * 0.85:
		push_warning("CARD TIGHT [%s]: ~%dpx / %dpx (%dpx spare). May overflow." % [card_name, int(total_estimated), VIEWPORT_HEIGHT, int(VIEWPORT_HEIGHT - total_estimated)])


static func _estimate_label_height(label: Label) -> float:
	var font_size := 34  # Default to BODY size
	if label.has_theme_font_size_override("font_size"):
		font_size = label.get_theme_font_size("font_size")

	var char_width := font_size * BUNGEE_CHAR_WIDTH_RATIO
	var line_height := font_size * BUNGEE_LINE_HEIGHT_RATIO
	var available_width: float = label.custom_minimum_size.x if label.custom_minimum_size.x > 0 else CARD_WIDTH
	var chars_per_line := int(available_width / char_width)
	if chars_per_line <= 0:
		chars_per_line = 1

	var lines := 0
	for paragraph in label.text.split("\n"):
		if paragraph.strip_edges() == "":
			lines += 1
		else:
			lines += ceili(float(paragraph.length()) / chars_per_line)

	return lines * line_height
