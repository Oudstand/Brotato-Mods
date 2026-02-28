extends "res://ui/menus/global/focus_emulator.gd"

# MODOPTIONS MULTIPLAYER FIXES:
# 1. PopupMenu scrolling with keyboard/controller in multiplayer coop
# 2. Focus restoration when controls are deleted dynamically

# Cache for scroll position to avoid reading stale values from ScrollContainer
var _deferred_scroll_cache = {} # popup -> scroll_position

func _process(_delta: float) -> void:
	_validate_focus_references()

	if is_instance_valid(_focused_parent) and is_instance_valid(focused_control):
		._process(_delta)


func _handle_input(event: InputEvent) -> bool:
	var modal = get_viewport().get_modal_stack_top()
	if modal is PopupMenu:
		if _handle_popup_menu_input_custom(event, modal):
			return true

	# Fix vanilla's buggy focused_control restoration (doesn't check if _focused_parent is valid)
	if not is_instance_valid(focused_control) or focused_control.is_queued_for_deletion():
		if is_instance_valid(_focused_parent) and not _focused_parent.is_queued_for_deletion():
			if _focused_control_index >= 0 and _focused_control_index < _focused_parent.get_child_count():
				var new_control = _focused_parent.get_child(_focused_control_index)
				if is_instance_valid(new_control) and not new_control.is_queued_for_deletion():
					_set_focused_control_with_style(new_control, false)
				else:
					_clear_focused_control()
					return false
			else:
				_clear_focused_control()
				return false
		else:
			_clear_focused_control()
			return false

	if not is_instance_valid(focused_control) or focused_control.is_queued_for_deletion():
		return false
	if focused_control is HSlider and _handle_hslider_input(event, focused_control):
		return true

	if Utils.is_maybe_action_pressed(event, "ui_accept_%s" % _device):
		if not focused_control.is_visible_in_tree():
			return true
		if focused_control is BaseButton:
			if focused_control.disabled:
				return true
			if focused_control is OptionButton:
				_open_option_button(focused_control)
			elif focused_control.toggle_mode:
				var toggled = not focused_control.pressed
				focused_control.set_pressed_no_signal(toggled)
				if toggled:
					_press_button(focused_control)
				FocusEmulatorSignal.emit(focused_control, "toggled", player_index, toggled)
			else:
				_press_button(focused_control)
		return true

	var previous = focused_control
	var result = _get_focus_neighbour_for_event(event, previous)
	var new_control = result.control
	if new_control == null or new_control == previous:
		return result.input_matched_action
	assert(result.input_matched_action, "result.input_matched_action")
	_set_focused_control_with_style(new_control, false)
	FocusEmulatorSignal.emit(previous, "focus_exited", player_index)
	FocusEmulatorSignal.emit(new_control, "focus_entered", player_index)
	return true


func _validate_focus_references() -> void:
	if not is_instance_valid(_focused_parent) or (is_instance_valid(_focused_parent) and _focused_parent.is_queued_for_deletion()):
		_focused_parent = null
		_focused_control_index = -1

	if not is_instance_valid(focused_control) or (is_instance_valid(focused_control) and focused_control.is_queued_for_deletion()):
		focused_control = null
		_focused_control_index = -1


func _handle_popup_menu_input_custom(event: InputEvent, popup: PopupMenu) -> bool:
	var allow_echo = true
	var item_count = popup.get_item_count()

	if event.is_action_pressed("ui_up_%s" % _device, allow_echo):
		var old_index = popup.get_current_index()
		var new_index = (old_index - 1 + item_count) % item_count
		popup.set_current_index(new_index)
		call_deferred("_scroll_to_index", popup, new_index)
		return true
	elif event.is_action_pressed("ui_down_%s" % _device, allow_echo):
		var old_index = popup.get_current_index()
		var new_index = (old_index + 1) % item_count
		popup.set_current_index(new_index)
		call_deferred("_scroll_to_index", popup, new_index)
		return true
	elif event.is_action_pressed("ui_accept_%s" % _device):
		var id = popup.get_item_id(popup.get_current_index())
		FocusEmulatorSignal.emit(popup, "id_pressed", player_index, id)
		FocusEmulatorSignal.emit(popup, "index_pressed", player_index, popup.get_current_index())
		popup.hide()
		return true

	return false


func _scroll_to_index(popup: PopupMenu, item_index: int) -> void:
	var scroll_container = _find_scroll_container_recursive(popup)
	if scroll_container == null:
		return

	var item_count = popup.get_item_count()
	if item_count == 0:
		return

	var item_height = 64.0 # 60px icon + 4px padding
	
	# Try to be smart about height if possible, but keep fallback
	if scroll_container.get_child_count() > 0:
		var content = scroll_container.get_child(0)
		if content is Control and content.rect_size.y > 0:
			item_height = content.rect_size.y / float(item_count)
	
	if item_height <= 1.0:
		item_height = 64.0

	var viewport_height = scroll_container.rect_size.y
	
	# Fix for Fullscreen/Oversized Container:
	# If the container extends physically below the screen bottom, the bottom items are hidden.
	# We calculate the "effective" visible height by subtracting the overflow.
	var scroll_global_rect = scroll_container.get_global_rect()
	var screen_rect = get_viewport().get_visible_rect()
	
	# Check where container ends vs screen ends
	var container_phys_bottom = scroll_global_rect.position.y + viewport_height
	var screen_bottom = screen_rect.size.y
	
	if container_phys_bottom > screen_bottom:
		var overflow = container_phys_bottom - screen_bottom
		# Reduce effective height by overflow + safety margin
		viewport_height -= (overflow + 32.0)
		
		# Safety floor to prevent collapsing logic in weird states
		if viewport_height < 64.0:
			viewport_height = 64.0

	# Always read actual scroll from container
	var current_scroll = scroll_container.scroll_vertical

	var item_top = item_index * item_height
	var item_bottom = item_top + item_height
	var visible_top = current_scroll
	var visible_bottom = current_scroll + viewport_height

	# If item is fully visible, do nothing
	if item_top >= visible_top and item_bottom <= visible_bottom:
		return

	var new_scroll = current_scroll
	
	# Simple standard scrolling logic
	if item_top < visible_top:
		# Scroll Up
		if item_index <= 2:
			new_scroll = 0.0
		else:
			new_scroll = item_top
	elif item_bottom > visible_bottom:
		# Scroll Down
		new_scroll = item_bottom - viewport_height

	if new_scroll != current_scroll:
		scroll_container.scroll_vertical = new_scroll


# Recursively find ScrollContainer
func _find_scroll_container_recursive(node: Node):
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var result = _find_scroll_container_recursive(child)
		if result != null:
			return result
	return null


func _disconnect_focused_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	._disconnect_focused_control(control)


func _clear_focused_control() -> void:
	if focused_control == null:
		return
	if is_instance_valid(focused_control):
		._clear_focused_control()
	else:
		focused_control = null
		_focused_control_index = -1
		_focused_parent = null


func _ensure_valid_focus() -> bool:
	if is_instance_valid(focused_control) and not focused_control.is_queued_for_deletion():
		return true
	return _restore_focus()


func _restore_focus() -> bool:
	# Try to restore focus in the original parent first
	if is_instance_valid(_focused_parent) and not _focused_parent.is_queued_for_deletion():
		var children = _focused_parent.get_children()

		# Try to restore at the same index
		if _focused_control_index >= 0 and _focused_control_index < children.size():
			var candidate = children[_focused_control_index]
			if _is_focusable(candidate):
				_set_focused_control_with_style(candidate, false)
				return true

		# Try any child in the parent
		for child in children:
			if _is_focusable(child):
				_set_focused_control_with_style(child, false)
				return true

	# FALLBACK: If parent is gone, try to find a control in the grandparent
	ModLoaderLog.warning("Parent is invalid, searching for fallback control", "ModOptions-Focus")

	var search_root = get_viewport()
	if is_instance_valid(search_root):
		# Find any focusable control, but prefer Buttons and exclude TabButtons
		var focusable = _find_best_focusable_control(search_root)
		if focusable != null:
			_set_focused_control_with_style(focusable, false)
			ModLoaderLog.info("Found fallback control: %s" % focusable.name, "ModOptions-Focus")
			return true

	_clear_focused_control()
	return false


# Find the best focusable control: prefer Button, avoid TabButton
func _find_best_focusable_control(node: Node):
	var buttons = []
	var other_controls = []
	_categorize_focusable_controls(node, buttons, other_controls)

	# Prefer regular buttons over other controls
	if buttons.size() > 0:
		return buttons[0]
	if other_controls.size() > 0:
		return other_controls[0]
	return null


# Categorize controls: separate Buttons from TabButtons and other controls
func _categorize_focusable_controls(node: Node, buttons: Array, other_controls: Array) -> void:
	if _is_focusable(node):
		# Check if it's a TabButton (avoid those)
		if node.get_class() == "TabButton":
			# Skip TabButtons
			pass
		elif node is Button:
			buttons.append(node)
		else:
			other_controls.append(node)

	for child in node.get_children():
		_categorize_focusable_controls(child, buttons, other_controls)


func _is_focusable(node: Node) -> bool:
	return (
		is_instance_valid(node)
		and node is Control
		and not node.is_queued_for_deletion()
		and node.focus_mode == Control.FOCUS_ALL
		and node.is_visible_in_tree()
	)
