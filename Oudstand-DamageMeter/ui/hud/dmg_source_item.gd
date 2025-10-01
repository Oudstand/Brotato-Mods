extends Control

const SPACING_LEFT: int = 8
const SPACING_RIGHT: int = 12

onready var content: HBoxContainer = $Content
onready var icon: TextureRect = $Content/Icon
onready var label: Label = $Content/Label

var _is_right: bool = false

func set_data(source_info: Dictionary) -> void:
	var source = source_info.get("source")
	if is_instance_valid(source) and "icon" in source:
		label.text = str(source_info.get("damage", 0))
		icon.texture = source.icon

func set_mod_alignment(is_right: bool) -> void:
	if _is_right == is_right:
		return
	
	_is_right = is_right
	
	# Anchors setzen
	content.anchor_left = 1.0 if is_right else 0.0
	content.anchor_right = content.anchor_left
	
	# Kinder sortieren
	if is_right:
		content.move_child(label, 0)
		content.move_child(icon, 1)
	else:
		content.move_child(icon, 0)
		content.move_child(label, 1)
	
	# Spacing
	content.add_constant_override("separation", SPACING_RIGHT if is_right else SPACING_LEFT)
	
	# Margins sofort UND deferred aktualisieren für Sicherheit
	_update_margins()
	call_deferred("_update_margins")

func _update_margins() -> void:
	if not is_instance_valid(content):
		return
	
	var size = content.get_combined_minimum_size()
	
	if _is_right:
		content.margin_left = -size.x
		content.margin_right = 0
	else:
		content.margin_left = 0
		content.margin_right = size.x
