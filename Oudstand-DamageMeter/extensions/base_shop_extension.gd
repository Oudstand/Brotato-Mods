extends "res://ui/menus/shop/base_shop.gd"

var _dmg_summary_btns: Array = []

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
		var go_btn = _get_go_button(i)
		if not is_instance_valid(go_btn) or not is_instance_valid(go_btn.get_parent()):
			continue

		var summary_btn = go_btn.duplicate()
		summary_btn.name = "DmgSummaryButton_P" + str(i)
		summary_btn.text = tr("DAMAGEMETER_SUMMARY_BTN")
		
		# Remove old signals and connect ours
		for conn in summary_btn.get_signal_connection_list("pressed"):
			summary_btn.disconnect("pressed", conn.target, conn.method)
		summary_btn.connect("pressed", self, "_on_dmg_summary_pressed")
		
		var parent_container = go_btn.get_parent()
		parent_container.add_child(summary_btn)
		parent_container.move_child(summary_btn, go_btn.get_index())
		_dmg_summary_btns.append(summary_btn)

func _on_dmg_summary_pressed() -> void:
	var popup_scene = load("res://mods-unpacked/Oudstand-DamageMeter/ui/summary/wave_summary_ui.tscn")
	if popup_scene:
		var popup = popup_scene.instance()
		add_child(popup)
