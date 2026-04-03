extends CanvasLayer

# ============================================================
# Wave Summary UI – Post-wave damage breakdown shown in the shop
# ============================================================
# Input is handled manually for ALL devices (keyboard + every controller)
# because Brotato's coop uses device-specific actions (ui_up_0, etc.)
# that Godot's built-in focus system does not respond to.
#
# In multiplayer each player navigates only their OWN column / card.
# ============================================================

const TIER_COLORS := {
	0: Color(0.90, 0.90, 0.90, 1.0),
	1: Color(0.35, 0.75, 1.0, 1.0),
	2: Color(0.68, 0.35, 1.0, 1.0),
	3: Color(1.0, 0.23, 0.23, 1.0),
	4: Color(1.0, 0.47, 0.23, 1.0),
}

onready var panel := $Root/Panel
onready var players_hbox := $Root/Panel/VBox/PlayersHBox
onready var close_btn := $Root/Panel/VBox/BottomBar/CloseBtn
onready var title_lbl := $Root/Panel/VBox/Title

# _grid[col][row] = Button
var _grid: Array = []
var _scrolls: Array = [] # _scrolls[col] = ScrollContainer

# ─── Focus state ─────────────────────────────────────────────
# Singleplayer: _focus_col / _focus_row navigate freely.
# Multiplayer:  _player_rows[player_idx] = row within their column (col == player_idx).
#               Each player's highlight is shown via a colored Panel overlay.
var _is_coop: bool = false
var _focus_col: int = 0
var _focus_row: int = 0
var _player_rows: Dictionary = {}      # player_idx → row
var _player_borders: Dictionary = {}   # player_idx → Panel node (current highlight)

# ─── Close state ─────────────────────────────────────────────
# We stay alive for 2 frames after closing to consume the ESC/B *release*
# event. Otherwise the release propagates to the pause menu.
var _closing: bool = false
var _parent_pause_mode: int = Node.PAUSE_MODE_INHERIT
var _show_item_count: bool = true

# ─── Lifecycle ───────────────────────────────────────────────

func _ready() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		_parent_pause_mode = parent_node.pause_mode
		parent_node.pause_mode = Node.PAUSE_MODE_STOP

	get_tree().paused = true
	self.pause_mode = Node.PAUSE_MODE_PROCESS
	_load_display_options()

	close_btn.text = tr("MENU_BACK")
	title_lbl.text = tr("DAMAGEMETER_SUMMARY_TITLE") + " (" + Text.text("WAVE", [str(RunData.current_wave)]) + ")"
	close_btn.connect("pressed", self, "_on_close")

	var bg := $Root/Background as Control
	if bg:
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# ── Load data ──────────────────────────────────────────
	var data_tracker = get_node_or_null("/root/ModLoader/Oudstand-DamageMeter/DamageMeterData")
	if not is_instance_valid(data_tracker) or data_tracker.last_wave_data.empty():
		get_tree().paused = false
		_restore_parent_pause_mode()
		queue_free()
		return

	var data: Array = data_tracker.last_wave_data
	var team_total := 0
	for p in data:
		team_total += p.total
	var total_players := data.size()

	# Adjust spacing based on player count
	if total_players >= 4:
		players_hbox.set("custom_constants/separation", 8)
	elif total_players == 3:
		players_hbox.set("custom_constants/separation", 12)

	for player_data in data:
		_build_player_card(player_data, team_total, total_players, players_hbox)

	# ── Focus init ─────────────────────────────────────────
	_is_coop = RunData.get_player_count() > 1

	if _is_coop:
		for i in range(min(RunData.get_player_count(), _grid.size())):
			_player_rows[i] = 0
		call_deferred("_apply_all_coop_focus")
	else:
		call_deferred("_apply_focus")

# ─── Input ───────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# While closing, consume EVERYTHING so the key release
	# doesn't reach the pause menu.
	if _closing:
		get_tree().set_input_as_handled()
		return

	if _is_coop:
		_handle_coop_input(event)
	else:
		_handle_solo_input(event)

	# Hard block any remaining keyboard/controller input so nothing leaks to shop/game.
	if event is InputEventKey \
	or event is InputEventJoypadButton \
	or event is InputEventJoypadMotion:
		get_tree().set_input_as_handled()

func _process(_delta: float) -> void:
	if _closing:
		# Wait until ALL cancel/pause keys are fully released before
		# unpausing.  This prevents the ESC *release* event from
		# reaching the pause menu after we free ourselves.
		if _is_any_close_key_held():
			return
		get_tree().paused = false
		_restore_parent_pause_mode()
		_restore_shop_focus()
		queue_free()
		return

	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _exit_tree() -> void:
	_restore_parent_pause_mode()

# ─── Solo input ──────────────────────────────────────────────

func _handle_solo_input(event: InputEvent) -> void:
	if _is_any_action_pressed(event, "ui_cancel"):
		_on_close()
		get_tree().set_input_as_handled()
	elif _is_any_action_pressed(event, "ui_up"):
		_navigate_solo(0, -1)
		get_tree().set_input_as_handled()
	elif _is_any_action_pressed(event, "ui_down"):
		_navigate_solo(0, 1)
		get_tree().set_input_as_handled()
	elif _is_any_action_pressed(event, "ui_left"):
		_navigate_solo(-1, 0)
		get_tree().set_input_as_handled()
	elif _is_any_action_pressed(event, "ui_right"):
		_navigate_solo(1, 0)
		get_tree().set_input_as_handled()
	elif _is_any_action_pressed(event, "ui_accept"):
		if _is_solo_on_close():
			_on_close()
		get_tree().set_input_as_handled()
	elif _is_any_action_pressed(event, "ui_pause"):
		get_tree().set_input_as_handled()

func _navigate_solo(dc: int, dr: int) -> void:
	if _grid.empty():
		return
	var new_col := clamp(_focus_col + dc, 0, _grid.size() - 1) as int
	var col_size: int = _grid[new_col].size()
	var new_row := clamp(_focus_row + dr, 0, col_size) as int
	_focus_col = new_col
	_focus_row = new_row
	_apply_focus()

func _is_solo_on_close() -> bool:
	if _grid.empty():
		return true
	return _focus_row >= _grid[_focus_col].size()

func _apply_focus() -> void:
	if _is_solo_on_close():
		close_btn.grab_focus()
	elif _focus_col < _grid.size() and _focus_row < _grid[_focus_col].size():
		_grid[_focus_col][_focus_row].grab_focus()
		_scroll_to_row(_focus_col, _focus_row)

# ─── Coop input ──────────────────────────────────────────────

func _handle_coop_input(event: InputEvent) -> void:
	# Determine which player triggered the event
	var actions := {
		"ui_cancel": "_coop_cancel",
		"ui_up":     "_coop_up",
		"ui_down":   "_coop_down",
		"ui_accept": "_coop_accept",
		"ui_pause":  "_coop_block",
		"ui_left":   "_coop_block",
		"ui_right":  "_coop_block",
	}
	for base_action in actions:
		var player_idx := _get_player_for_event(event, base_action)
		if player_idx >= 0:
			call(actions[base_action], player_idx)
			get_tree().set_input_as_handled()
			return

func _coop_cancel(_player_idx: int) -> void:
	_on_close()

func _coop_up(player_idx: int) -> void:
	_navigate_coop(player_idx, -1)

func _coop_down(player_idx: int) -> void:
	_navigate_coop(player_idx, 1)

func _coop_accept(player_idx: int) -> void:
	if _is_coop_on_close(player_idx):
		_on_close()

func _coop_block(_player_idx: int) -> void:
	pass  # just consume

func _navigate_coop(player_idx: int, dr: int) -> void:
	if not _player_rows.has(player_idx):
		return
	var col := min(player_idx, _grid.size() - 1) as int
	var col_size: int = _grid[col].size()
	var new_row := clamp(_player_rows[player_idx] + dr, 0, col_size) as int
	_player_rows[player_idx] = new_row
	_apply_coop_focus(player_idx)

func _is_coop_on_close(player_idx: int) -> bool:
	if not _player_rows.has(player_idx):
		return true
	var col := min(player_idx, _grid.size() - 1) as int
	return _player_rows[player_idx] >= _grid[col].size()

func _apply_all_coop_focus() -> void:
	for player_idx in _player_rows.keys():
		_apply_coop_focus(player_idx)

func _apply_coop_focus(player_idx: int) -> void:
	# Remove previous highlight for this player
	if _player_borders.has(player_idx) and is_instance_valid(_player_borders[player_idx]):
		_player_borders[player_idx].queue_free()
		_player_borders.erase(player_idx)

	var col := min(player_idx, _grid.size() - 1) as int
	var target: Control

	if _is_coop_on_close(player_idx):
		target = close_btn
	else:
		target = _grid[col][_player_rows[player_idx]]
		_scroll_to_row(col, _player_rows[player_idx])

	# Player 0 also uses native grab_focus (for keyboard/mouse)
	if player_idx == 0:
		target.grab_focus()

	# Add colored border overlay
	var color: Color = CoopService.get_player_color(player_idx)
	var border := Panel.new()
	border.name = "_hl_p%d" % player_idx
	border.anchor_right = 1.0
	border.anchor_bottom = 1.0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	border.add_stylebox_override("panel", style)
	target.add_child(border)
	_player_borders[player_idx] = border

func _get_player_for_event(event: InputEvent, base_action: String) -> int:
	# Check device-specific actions → map to player via CoopService
	for player_idx in range(RunData.get_player_count()):
		var device: int = CoopService.get_remapped_player_device(player_idx)
		if device < 0:
			continue
		var device_action := "%s_%d" % [base_action, device]
		if InputMap.has_action(device_action) and event.is_action_pressed(device_action):
			return player_idx
	# Standard action (keyboard) → player 0
	if event.is_action_pressed(base_action):
		return 0
	return -1

# ─── Close & Focus Restore ───────────────────────────────────

func _on_close() -> void:
	if _closing:
		return
	_closing = true
	# Hide immediately; actual close happens 2 frames later in _process
	$Root.visible = false

func _restore_shop_focus() -> void:
	var shop = get_parent()
	if is_instance_valid(shop) and shop.has_method("_get_go_button"):
		for i in range(RunData.get_player_count()):
			var go_btn = shop._get_go_button(i)
			if is_instance_valid(go_btn):
				Utils.focus_player_control(go_btn, i)

# ─── Shared: action check for solo mode ──────────────────────

func _is_any_action_pressed(event: InputEvent, action: String) -> bool:
	if event.is_action_pressed(action):
		return true
	for device in range(8):
		var da := "%s_%d" % [action, device]
		if InputMap.has_action(da) and event.is_action_pressed(da):
			return true
	return false

func _is_any_close_key_held() -> bool:
	for action in ["ui_cancel", "ui_pause"]:
		if Input.is_action_pressed(action):
			return true
		for device in range(8):
			var da := "%s_%d" % [action, device]
			if InputMap.has_action(da) and Input.is_action_pressed(da):
				return true
	return false

# ─── Player Card Builder ─────────────────────────────────────

func _build_player_card(p_data: Dictionary, team_total: int, player_count: int, container: Control) -> void:
	var col_items := []
	_grid.append(col_items)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.10, 0.12, 0.92)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	if player_count >= 4:
		card_style.content_margin_left = 10
		card_style.content_margin_right = 10
	elif player_count == 3:
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
	card.add_stylebox_override("panel", card_style)
	container.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set("custom_constants/separation", 12)
	card.add_child(vbox)

	# 1. Header
	var header := HBoxContainer.new()
	header.set("custom_constants/separation", 12)
	header.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_child(header)

	var player_icon_tex = _safe_get(p_data, "player_icon")
	if player_icon_tex:
		var p_icon := TextureRect.new()
		p_icon.texture = player_icon_tex
		p_icon.rect_min_size = Vector2(56, 56)
		p_icon.expand = true
		p_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(p_icon)

	var name_lbl := Label.new()
	name_lbl.text = tr(_safe_get(p_data, "player_name", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.align = Label.ALIGN_CENTER
	header.add_child(name_lbl)

	# 2. Team share bar (multiplayer only)
	var team_pct := (float(p_data.total) / float(team_total)) if team_total > 0 else 0.0
	# player_count is passed in (not _grid.size() which grows as cards are built)

	if player_count > 1:
		var bar_bg := ColorRect.new()
		bar_bg.rect_min_size = Vector2(0, 8)
		bar_bg.color = Color(0, 0, 0, 0.5)
		vbox.add_child(bar_bg)
		var bar_fill := ColorRect.new()
		bar_fill.anchor_right = team_pct
		bar_fill.anchor_bottom = 1.0
		bar_fill.color = Color(0.25, 0.55, 0.85, 0.85)
		bar_bg.add_child(bar_fill)

	# 3. Stats row
	var stats_row := HBoxContainer.new()
	stats_row.set("custom_constants/separation", 8)
	vbox.add_child(stats_row)

	var total_lbl := Label.new()
	var total_text := Text.get_formatted_number(p_data.total)
	if player_count > 1:
		total_text += "  (%d%%)" % int(team_pct * 100)
	total_lbl.text = total_text
	total_lbl.add_color_override("font_color", Color(1, 0.85, 0.35))
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(total_lbl)

	var dps := _safe_get(p_data, "dps", 0) as int
	var dps_lbl := Label.new()
	if dps > 0:
		dps_lbl.text = "%s DPS" % Text.get_formatted_number(dps)
	else:
		dps_lbl.text = "< 1 DPS" if p_data.total > 0 else "0 DPS"
	dps_lbl.add_color_override("font_color", Color(0.7, 0.7, 0.7))
	dps_lbl.align = Label.ALIGN_RIGHT
	stats_row.add_child(dps_lbl)

	vbox.add_child(HSeparator.new())

	# 4. Scrollable item list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.set("scroll_horizontal_enabled", false)
	_scrolls.append(scroll)
	vbox.add_child(scroll)

	var items_vbox := VBoxContainer.new()
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.set("custom_constants/separation", 4)
	scroll.add_child(items_vbox)

	if p_data.total <= 0:
		return
	var sources: Array = _safe_get(p_data, "sources", [])
	for source in sources:
		var item_btn := _create_source_row(source, p_data.total, player_count, _show_item_count)
		items_vbox.add_child(item_btn)
		col_items.append(item_btn)

# ─── Source Row ───────────────────────────────────────────────

func _create_source_row(source: Dictionary, player_total: int, player_count: int, show_item_count: bool) -> Button:
	var tier: int = _safe_get(source, "tier", 0)
	var is_cursed: bool = _safe_get(source, "is_cursed", false)
	var bar_color: Color = _get_tier_color(tier)
	var compact_mode := player_count >= 3
	var icon_size := 52
	var row_height := 56
	var value_col_width := 112

	var btn := Button.new()
	btn.rect_min_size.y = row_height
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_PASS

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0.15)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	btn.add_stylebox_override("normal", normal_style)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1, 1, 1, 0.08)
	focus_style.corner_radius_top_left = 6
	focus_style.corner_radius_top_right = 6
	focus_style.corner_radius_bottom_left = 6
	focus_style.corner_radius_bottom_right = 6
	focus_style.border_width_left = 2
	focus_style.border_width_right = 2
	focus_style.border_width_top = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = Color(1, 1, 1, 0.35)
	btn.add_stylebox_override("focus", focus_style)
	btn.add_stylebox_override("hover", focus_style)
	var pressed_style := focus_style.duplicate()
	pressed_style.bg_color = Color(1, 1, 1, 0.12)
	btn.add_stylebox_override("pressed", pressed_style)

	# Damage proportion bar – colored by tier instead of always red
	var pct := float(source.damage) / float(player_total) if player_total > 0 else 0.0
	var dmg_bar := ColorRect.new()
	dmg_bar.anchor_right = pct
	dmg_bar.anchor_bottom = 1.0
	dmg_bar.color = Color(bar_color.r, bar_color.g, bar_color.b, 0.14)
	dmg_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(dmg_bar)

	var hbox := HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.margin_left = 8 if compact_mode else 10
	hbox.margin_right = -8 if compact_mode else -10
	hbox.set("custom_constants/separation", 8 if compact_mode else 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	# Icon with tier-colored background
	var icon_panel := PanelContainer.new()
	icon_panel.rect_min_size = Vector2(icon_size, icon_size)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_panel)

	var icon_style := StyleBoxFlat.new()
	icon_style.corner_radius_top_left = 5
	icon_style.corner_radius_top_right = 5
	icon_style.corner_radius_bottom_left = 5
	icon_style.corner_radius_bottom_right = 5
	ItemService.change_inventory_element_stylebox_from_tier(icon_style, tier, 0.3)
	if is_cursed:
		icon_style.border_width_left = 2
		icon_style.border_width_right = 2
		icon_style.border_width_top = 2
		icon_style.border_width_bottom = 2
		icon_style.border_color = Color(0.85, 0.2, 0.2, 0.9)
	icon_panel.add_stylebox_override("panel", icon_style)

	var icon_tex = _safe_get(source, "icon")
	var icon_rect: TextureRect = null
	if icon_tex:
		icon_rect = TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.rect_min_size = Vector2(icon_size - 4, icon_size - 4)
		icon_rect.expand = true
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon_rect)

	var count: int = _safe_get(source, "count", 1)
	var item_name_full: String = tr(_safe_get(source, "name", ""))
	var full_text := ("x%d %s" % [count, item_name_full]) if count > 1 else item_name_full
	btn.hint_tooltip = full_text

	if show_item_count and count > 1 and is_instance_valid(icon_rect):
		var badge := Panel.new()
		badge.anchor_left = 1.0
		badge.anchor_top = 1.0
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.margin_left = -20
		badge.margin_top = -14
		badge.margin_right = -2
		badge.margin_bottom = -2
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0, 0, 0, 0.72)
		badge_style.corner_radius_top_left = 3
		badge_style.corner_radius_top_right = 3
		badge_style.corner_radius_bottom_left = 3
		badge_style.corner_radius_bottom_right = 3
		badge.add_stylebox_override("panel", badge_style)

		var badge_lbl := Label.new()
		badge_lbl.anchor_right = 1.0
		badge_lbl.anchor_bottom = 1.0
		badge_lbl.text = "x%d" % count
		badge_lbl.add_font_override("font", load("res://resources/fonts/actual/base/font_smallest_text.tres"))
		badge_lbl.align = Label.ALIGN_CENTER
		badge_lbl.valign = Label.VALIGN_CENTER
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(badge_lbl)
		icon_rect.add_child(badge)

	var value_lbl := Label.new()
	value_lbl.rect_min_size = Vector2(value_col_width, 0)
	value_lbl.text = Text.get_formatted_number(source.damage)
	value_lbl.text = "%s  (%d%%)" % [value_lbl.text, int(pct * 100)]
	value_lbl.add_color_override("font_color", _get_tier_color(tier))
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_lbl.align = Label.ALIGN_RIGHT
	value_lbl.valign = Label.VALIGN_CENTER
	value_lbl.clip_text = true
	value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_lbl.hint_tooltip = full_text
	hbox.add_child(value_lbl)

	return btn

# ─── Helpers ─────────────────────────────────────────────────

static func _safe_get(dict: Dictionary, key: String, default = null):
	return dict[key] if dict.has(key) and dict[key] != null else default

static func _get_tier_color(tier: int) -> Color:
	if TIER_COLORS.has(tier):
		return TIER_COLORS[tier]
	return Color(0.9, 0.9, 0.9)

func _restore_parent_pause_mode() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		parent_node.pause_mode = _parent_pause_mode

func _get_mod_options() -> Node:
	var root = get_tree().get_root()
	if not root:
		return null
	var mod_loader = root.get_node_or_null("ModLoader")
	if not mod_loader:
		return null
	var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null
	return mod_options_mod.get_node_or_null("ModOptions")

func _load_display_options() -> void:
	_show_item_count = true
	var mod_options = _get_mod_options()
	if not is_instance_valid(mod_options):
		return
	var show_count_val = mod_options.get_value("DamageMeter", "show_item_count")
	if show_count_val != null:
		_show_item_count = show_count_val

func _scroll_to_row(col: int, row: int) -> void:
	if col < 0 or col >= _scrolls.size():
		return
	if col < 0 or col >= _grid.size():
		return
	if row < 0 or row >= _grid[col].size():
		return

	var scroll = _scrolls[col]
	if not is_instance_valid(scroll):
		return

	var row_btn = _grid[col][row]
	if not is_instance_valid(row_btn):
		return

	var row_top = int(row_btn.rect_position.y)
	var row_bottom = int(row_btn.rect_position.y + row_btn.rect_size.y)
	var view_top = int(scroll.scroll_vertical)
	var view_bottom = int(scroll.scroll_vertical + scroll.rect_size.y)

	if row_top < view_top:
		scroll.scroll_vertical = row_top
	elif row_bottom > view_bottom:
		scroll.scroll_vertical = row_bottom - int(scroll.rect_size.y)
