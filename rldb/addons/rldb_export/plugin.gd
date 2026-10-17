@tool
extends EditorPlugin
## Registers the export hook that keeps two Windows builds in step (see dev_copy_export.gd).

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("res://addons/rldb_export/dev_copy_export.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
