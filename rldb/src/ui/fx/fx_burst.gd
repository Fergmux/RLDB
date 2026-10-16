class_name FxBurst
extends Control
## Particle burst drawn around the node position as `t` runs 0 -> 1: a dust ring, rising embers or
## spark streaks. Presentation-only and click-through; FxPlayer creates, tweens and frees it.

enum Kind { DUST, EMBER, SPARK }

## Number of random seeds drawn once per burst (particle `i` uses seed `i % SEED_COUNT`).
const SEED_COUNT := 12

## Which particle style is drawn.
var kind: Kind = Kind.DUST
## Particle colour (alpha is driven by `t`).
var col: Color = Color.WHITE
## Number of particles.
var count: int = 6
## Reach of the burst in pixels.
var radius: float = 40.0
## Animation progress 0 -> 1; redraws on every change.
var t: float = 0.0: set = _set_t
## Per-particle random offsets.
var seeds: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in SEED_COUNT:
		seeds.append(randf())


func _set_t(v: float) -> void:
	t = v
	queue_redraw()


func _draw() -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + seeds[i % SEED_COUNT] * 0.6
		var d := Vector2(cos(a), sin(a))
		match kind:
			Kind.DUST:
				var e := 1.0 - pow(1.0 - t, 2.0)
				draw_circle(d * radius * e * Vector2(1.0, 0.45), 3.2 * (1.0 - t) + 0.5, Color(col, 0.6 * (1.0 - t)), true, -1.0, true)
			Kind.EMBER:
				var e2 := 1.0 - pow(1.0 - t, 2.0)
				var p := d * radius * 0.5 * e2 * (0.5 + seeds[i % SEED_COUNT]) + Vector2(0, -t * radius * (0.6 + seeds[(i + 3) % SEED_COUNT]))
				draw_circle(p, 2.6 * (1.0 - t) + 0.4, Color(col, 1.0 - t), true, -1.0, true)
			Kind.SPARK:
				var e3 := 1.0 - pow(1.0 - t, 3.0)
				draw_line(d * radius * (0.25 + e3 * 0.5), d * radius * (0.35 + e3 * 0.75), Color(col, 1.0 - t), 2.5 * (1.0 - t) + 0.5, true)
