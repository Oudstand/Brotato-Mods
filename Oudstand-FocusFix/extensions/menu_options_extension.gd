extends "res://ui/menus/pages/menu_options.gd"

# CLEAN SLATE STRATEGY:
# We override init() to fix the crash on open.
# We override _on_BackButton_pressed() to fix the crash on close.

func init() -> void:
	# Original code uses: var focus_emulator := Utils.get_focus_emulator(0)
	# This fails if Utils return type is not matching or null logic causes crash.
	# We replicate logic but use safe access
	if focus_before_created == null:
		# Use untyped variable to avoid inferrence issues
		var focus_emulator = Utils.get_focus_emulator(0)
		if focus_emulator != null:
			focus_before_created = focus_emulator.focused_control
		else:
			focus_before_created = get_focus_owner()
	
	var audio_btn = get_node_or_null("%Audio_but")
	if audio_btn:
		audio_btn.grab_focus()

	if RunData.is_coop_run:
		var fe = Utils.get_focus_emulator(0)
		if fe != null: # Fix: Added check
			if lb_texture: lb_texture.player_index = fe.player_index
			if rb_texture: rb_texture.player_index = fe.player_index

	var all_children = video_container.get_children()
	all_children.append_array(audio_container.get_children())

	for child in all_children:
		if child is CheckButton:
			all_check_buttons.push_back(child)

	adjust_buttons_font_size()
	
	var back_btn = get_node_or_null("%BackButton")
	if back_btn:
		back_btn.grab_focus()

	master_slider.set_value(ProgressData.settings.volume.master )
	sound_slider.set_value(ProgressData.settings.volume.sound)
	music_slider.set_value(ProgressData.settings.volume.music)

	var i = 0

	for language in ProgressData.languages:
		if language == ProgressData.settings.language:
			language_button.select(i)
			break
		i += 1

	var selected_background = ProgressData.settings.background
	if selected_background > ItemService.backgrounds.size():
		selected_background = 0

	background_button.select(selected_background)
	background_button._on_BackgroundButton_item_selected(selected_background)

	if not ItemService.is_connected("backgrounds_updated", background_button, "on_backgrounds_updated"):
		var _e = ItemService.connect("backgrounds_updated", background_button, "on_backgrounds_updated")

	visual_effects_button.pressed = ProgressData.settings.visual_effects
	screenshake_button.pressed = ProgressData.settings.screenshake
	fullscreen_button.pressed = ProgressData.settings.fullscreen
	damage_display_button.pressed = ProgressData.settings.damage_display
	optimize_end_waves_button.pressed = ProgressData.settings.optimize_end_waves
	limit_fps_button.pressed = ProgressData.settings.limit_fps

	mute_on_focus_lost_button.pressed = ProgressData.settings.mute_on_focus_lost
	on_lost_focus_button.select(ProgressData.settings.on_lost_focus)
	new_tracks_button.set_pressed_no_signal(ProgressData.settings.streamer_mode_tracks)
	old_tracks_button.set_pressed_no_signal(ProgressData.settings.legacy_tracks)

	color_positive._init_color(Color(ProgressData.settings.color_positive))
	color_negative._init_color(Color(ProgressData.settings.color_negative))
	color_tier0._init_color(Color(ProgressData.settings.tier_0_color))
	color_tier1._init_color(Color(ProgressData.settings.tier_1_color))
	color_tier2._init_color(Color(ProgressData.settings.tier_2_color))
	color_tier3._init_color(Color(ProgressData.settings.tier_3_color))
	color_tier4._init_color(Color(ProgressData.settings.tier_4_color))
	color_tier5._init_color(Color(ProgressData.settings.tier_5_color))

	_main_screen_keyart_list()
	var id: int = ProgressData.settings.main_screen_keyart
	var indx: int = main_screen_keyart.get_item_index(id)
	main_screen_keyart.select(indx)

	if not ProgressData.is_dlc_available("abyssal_terrors"):
		abyssal_terrors_tracks_button.hide()

	abyssal_terrors_tracks_button.set_pressed_no_signal(not ProgressData.settings.deactivated_dlc_tracks.has("abyssal_terrors"))
	init_values_from_progress_data()

	if is_in_a_run:
		for node in get_tree().get_nodes_in_group("hide_in_run"):
			node.hide()


# Override to prevent crash if focus_before_created is null on close
func _on_BackButton_pressed() -> void:
	if focus_before_created != null and is_instance_valid(focus_before_created):
		focus_before_created.grab_focus()
	elif RunData.is_coop_run:
		# Fallback for coop: try to restore focus to something valid using safe check
		var fe = Utils.get_focus_emulator(0)
		if fe != null and fe.focused_control != null and is_instance_valid(fe.focused_control):
			fe.focused_control.grab_focus()
		else:
			# Fallback if everything fails, just dont crash.
			pass
	else:
		# Maybe grab focus on parent?
		pass

	emit_signal("back_button_pressed")
