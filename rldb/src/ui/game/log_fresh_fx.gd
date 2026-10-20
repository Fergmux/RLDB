class_name LogFreshFx
extends RichTextEffect
## Game-log arrival (design review #46): text wrapped in [fresh t=<msec>] rises 8 px and fades in over
## RISE_S from its start time `t` (Time.get_ticks_msec(); later lines of one batch start STAGGER_MS
## apart), with a gold glow that fades out over GLOW_S. After that it is plain text. The log only
## writes the tag when motion is allowed.

## The bbcode tag ("fresh").
var bbcode := "fresh"

## Rise / fade-in time and the gold glow's fade (s), the rise (px), the glow's strength.
const RISE_S := 0.3
const GLOW_S := 0.6
const RISE_PX := 8.0
const GLOW_K := 0.3
## Delay between the lines of one batch (ms): the `stagger` motion token.
const STAGGER_MS := 40


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var t0 := float(fx.env.get("t", 0.0))
	var age := (float(Time.get_ticks_msec()) - t0) / 1000.0
	var st := state(age)
	fx.offset.y += st.x
	fx.color = Color(fx.color.lerp(UIStyle.GOLD_HI, st.z), fx.color.a * st.y)
	return true


## [rise offset px, alpha, gold mix] of a line `age` seconds after its start (before it: hidden and
## low; after GLOW_S: at rest). Pure, so the curve is unit-testable.
static func state(age: float) -> Vector3:
	if age >= GLOW_S:
		return Vector3(0.0, 1.0, 0.0)
	var k := clampf(age / RISE_S, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	var g := GLOW_K * clampf(1.0 - age / GLOW_S, 0.0, 1.0) if age >= 0.0 else GLOW_K
	return Vector3(RISE_PX * (1.0 - k), k, g)
