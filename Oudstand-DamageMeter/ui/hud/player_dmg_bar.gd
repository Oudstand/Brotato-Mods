extends VBoxContainer

export(PackedScene) var source_item_scene

onready var progress_bar: ProgressBar = $TotalDamageBar/ProgressBar
onready var icon_rect: TextureRect = $TotalDamageBar/HBoxContainer/CharacterIcon
onready var label: Label = $TotalDamageBar/HBoxContainer/DamageLabel
onready var source_list: VBoxContainer = $SourceListBackground/MarginContainer/SourceList
onready var hbox: HBoxContainer = $TotalDamageBar/HBoxContainer

var style_normal: StyleBox = null
var style_top_player: StyleBox = null

var _current_progress: float = 0.0
var _target_progress: float = 0.0
var _mirrored: bool = false
var _icon_position: int = -1
var _target_alpha: float = 1.0
var _current_alpha: float = 1.0

const LERP_SPEED: float = 6.0
const FADE_SPEED: float = 8.0
const ROW_HEIGHT: int = 32
const SEPARATION: int = 2
const MAX_SOURCES: int = 6

func _ready() -> void:
	_init_styles()
	progress_bar.value = 0.0
	progress_bar.connect("resized", self, "_on_progress_resized")

func _init_styles() -> void:
	var base_style = progress_bar.get("custom_styles/fg")
	style_normal = base_style if base_style else StyleBoxFlat.new()
	style_top_player = style_normal.duplicate()
	
	if style_top_player is StyleBoxFlat:
		style_top_player.bg_color = Color(0.9, 0.75, 0.3)
	
	progress_bar.add_stylebox_override("fg", style_normal)

func _process(delta: float) -> void:
	# Smooth Progress Animation
	if abs(_current_progress - _target_progress) > 0.1:
		_current_progress = lerp(_current_progress, _target_progress, LERP_SPEED * delta)
		progress_bar.value = _current_progress
	
	# Smooth Fade In/Out
	if abs(_current_alpha - _target_alpha) > 0.01:
		_current_alpha = lerp(_current_alpha, _target_alpha, FADE_SPEED * delta)
		modulate.a = _current_alpha

func _on_progress_resized() -> void:
	if _mirrored:
		progress_bar.rect_pivot_offset = progress_bar.rect_size / 2.0

func _set_layout(player_index: int) -> void:
	var is_right = (player_index == 1 or player_index == 3)
	
	# Label Alignment
	label.align = Label.ALIGN_RIGHT if is_right else Label.ALIGN_LEFT
	hbox.alignment = BoxContainer.ALIGN_END if is_right else BoxContainer.ALIGN_BEGIN
	
	# Icon Position
	var target_pos = 1 if is_right else 0
	if _icon_position != target_pos:
		hbox.move_child(icon_rect, target_pos)
		_icon_position = target_pos
	
	# Progress Bar Mirror
	if _mirrored != is_right:
		_mirrored = is_right
		progress_bar.rect_scale.x = -1.0 if is_right else 1.0
		progress_bar.rect_pivot_offset = progress_bar.rect_size / 2.0 if is_right else Vector2.ZERO

func update_total_damage(damage: int, max_damage: int, is_top: bool, is_single: bool, icon: Texture, player_index: int) -> void:
	_set_layout(player_index)
	
	label.text = str(damage)
	icon_rect.texture = icon
	
	# Progress berechnen
	if damage == 0 or max_damage == 0:
		_target_progress = 0.0
	elif is_single:
		_target_progress = 100.0
	else:
		_target_progress = float(damage) / float(max_damage) * 100.0
	
	# Style setzen
	var new_style = style_top_player if (is_top and damage > 0) else style_normal
	progress_bar.add_stylebox_override("fg", new_style)

func update_source_list(sources: Array, player_index: int) -> void:
	if sources.empty():
		for child in source_list.get_children():
			child.visible = false
		source_list.rect_min_size.y = 0
		var bg = get_node_or_null("SourceListBackground")
		if is_instance_valid(bg):
			bg.rect_min_size.y = 0
		return
	
	var is_right = (player_index == 1 or player_index == 3)
	var existing = source_list.get_children()
	var count = min(sources.size(), MAX_SOURCES)
	
	# Update/Create Items
	for i in range(count):
		var item
		if i < existing.size():
			item = existing[i]
		else:
			item = source_item_scene.instance()
			source_list.add_child(item)
		
		item.visible = true
		item.set_data(sources[i])
		item.set_mod_alignment(is_right)
	
	# Hide unused items
	for i in range(count, existing.size()):
		existing[i].visible = false
	
	# Resize Container
	var height = count * ROW_HEIGHT + max(0, count - 1) * SEPARATION
	source_list.rect_min_size.y = height
	source_list.add_constant_override("separation", SEPARATION)
	
	var bg = get_node_or_null("SourceListBackground")
	if is_instance_valid(bg):
		bg.rect_min_size.y = height
