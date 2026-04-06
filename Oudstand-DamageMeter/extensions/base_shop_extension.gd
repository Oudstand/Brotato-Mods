extends "res://ui/menus/shop/base_shop.gd"

var _dmg_summary_btns: Array = []
var _summary_icon: Texture = null

func _ready() -> void:
	var mod_options = get_node_or_null("/root/ModLoader/Oudstand-ModOptions/ModOptions")
	var show_btn = true
	var auto_open = false
	
	if is_instance_valid(mod_options):
		var val = mod_options.get_value("DamageMeter", "show_wave_summary")
		if val != null:
			show_btn = val
		
		var auto_val = mod_options.get_value("DamageMeter", "auto_open_wave_summary")
		if auto_val != null:
			auto_open = auto_val

	if show_btn:
		call_deferred("_inject_summary_buttons")

	# Auto-open should work independently from button visibility.
	if auto_open:
		call_deferred("_maybe_auto_open")

func _maybe_auto_open() -> void:
	# Only auto-open if data is available
	var data_tracker = get_node_or_null("/root/ModLoader/Oudstand-DamageMeter/DamageMeterData")
	if is_instance_valid(data_tracker) and not data_tracker.last_wave_data.empty():
		_on_dmg_summary_pressed()

func _inject_summary_buttons() -> void:
	var data_tracker = get_node_or_null("/root/ModLoader/Oudstand-DamageMeter/DamageMeterData")
	if not is_instance_valid(data_tracker) or data_tracker.last_wave_data.empty():
		return

	var player_count = RunData.get_player_count()
	for i in range(player_count):
		var reroll_btn = _get_reroll_button(i)
		if not is_instance_valid(reroll_btn) or not is_instance_valid(reroll_btn.get_parent()):
			continue

		var top_container: Control = reroll_btn.get_parent()
		var btn_name = "DmgSummaryButton_P" + str(i)

		if top_container.has_node(btn_name):
			continue

		var summary_btn = Button.new()
		summary_btn.name = btn_name
		summary_btn.text = ""
		summary_btn.icon = _get_summary_icon()
		summary_btn.expand_icon = true
		summary_btn.rect_min_size = Vector2(60, 0)
		summary_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		summary_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		summary_btn.focus_mode = Control.FOCUS_ALL

		summary_btn.connect("pressed", self, "_on_dmg_summary_pressed")

		top_container.add_child(summary_btn)
		top_container.move_child(summary_btn, min(reroll_btn.get_index() + 1, top_container.get_child_count() - 1))
		call_deferred("_match_button_height", summary_btn, reroll_btn)
		call_deferred("_wire_summary_focus", summary_btn, reroll_btn, i)
		_dmg_summary_btns.append(summary_btn)

func _on_dmg_summary_pressed() -> void:
	var popup_scene = load("res://mods-unpacked/Oudstand-DamageMeter/ui/summary/wave_summary_ui.tscn")
	if popup_scene:
		var popup = popup_scene.instance()
		add_child(popup)

func _match_button_height(summary_btn: Control, reference_btn: Control) -> void:
	if not is_instance_valid(summary_btn) or not is_instance_valid(reference_btn):
		return
	var h = int(reference_btn.rect_size.y)
	if h <= 0:
		h = int(reference_btn.rect_min_size.y)
	if h > 0:
		summary_btn.rect_min_size.y = h

func _wire_summary_focus(summary_btn: Control, reroll_btn: Control, player_index: int) -> void:
	if not is_instance_valid(summary_btn) or not is_instance_valid(reroll_btn):
		return

	var go_btn = _get_go_button(player_index)
	var old_right = reroll_btn.focus_neighbour_right

	# Link horizontal navigation explicitly so the summary button is reachable
	# by keyboard/controller in coop and solo layouts.
	reroll_btn.focus_neighbour_right = reroll_btn.get_path_to(summary_btn)
	summary_btn.focus_neighbour_left = summary_btn.get_path_to(reroll_btn)

	# Inherit reroll's previous right target (if any), so navigation can continue.
	if old_right != NodePath("") and reroll_btn.has_node(old_right):
		var right_target = reroll_btn.get_node(old_right) as Control
		if is_instance_valid(right_target) and right_target != summary_btn:
			summary_btn.focus_neighbour_right = summary_btn.get_path_to(right_target)

	# Keep vertical navigation consistent with reroll where possible.
	var old_top = reroll_btn.focus_neighbour_top
	if old_top != NodePath("") and reroll_btn.has_node(old_top):
		var top_target = reroll_btn.get_node(old_top) as Control
		if is_instance_valid(top_target):
			summary_btn.focus_neighbour_top = summary_btn.get_path_to(top_target)

	var old_bottom = reroll_btn.focus_neighbour_bottom
	if old_bottom != NodePath("") and reroll_btn.has_node(old_bottom):
		var bottom_target = reroll_btn.get_node(old_bottom) as Control
		if is_instance_valid(bottom_target):
			summary_btn.focus_neighbour_bottom = summary_btn.get_path_to(bottom_target)
	elif is_instance_valid(go_btn):
		summary_btn.focus_neighbour_bottom = summary_btn.get_path_to(go_btn)

func _get_summary_icon() -> Texture:
	if _summary_icon != null:
		return _summary_icon

	var icon_path := "res://mods-unpacked/Oudstand-DamageMeter/ui/icons/summary_icon.png"
	var loaded = load(icon_path)
	if loaded != null:
		_summary_icon = loaded
		return _summary_icon

	# Fallback if import data is missing on some setups.
	var image = Image.new()
	var err = image.load(icon_path)
	if err == OK:
		var tex = ImageTexture.new()
		tex.create_from_image(image, 0)
		_summary_icon = tex
		return _summary_icon

	_summary_icon = load("res://ui/menus/global/gameplay_icon.png")
	return _summary_icon
