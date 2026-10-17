class_name PromptPlate
extends HousePanel
## Plate of the input-required prompt (F04-13): the house plate (HousePanel, F06-01) with the
## prompt's margins. The header strip carries the actor tag; `attend()` is its attention loop and
## `fit()` sizes it to exactly its content for a given width.


func _init() -> void:
	super("", "", Vector2(16, 14), 7)
