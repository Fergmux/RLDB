class_name WaitingDots
extends Label
## A line of text whose trailing three dots fill in one by one ("Waiting for your opponent",
## "…opponent.", "…opponent..", "…opponent..."), the quiet waiting cue of the rewards stage (owner
## feedback 2026-10-18: no loading plate). Static "…" under reduced motion.

## Seconds per dot step.
const STEP := 0.45

var base := ""
var _t := 0.0
var _n := -1


func _init(text_base: String = "", font_size: int = 18, color: Color = UIStyle.MUTED) -> void:
	base = text_base
	add_theme_font_size_override("font_size", font_size)
	add_theme_font_override("font", UIStyle.font_display(400))
	add_theme_color_override("font_color", color)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh(3)


func _process(delta: float) -> void:
	if UIStyle.reduce_motion:
		_refresh(-1)
		return
	_t += delta
	_refresh(int(_t / STEP) % 4)


## Shows `n` dots (0..3); -1 shows a static ellipsis.
func _refresh(n: int) -> void:
	if n == _n:
		return
	_n = n
	# The dots take their full width at every step, so the centred text never shifts.
	text = base + ("…" if n < 0 else ".".repeat(n) + " ".repeat(3 - n))
