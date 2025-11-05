extends Node

const MOD_ID := "Oudstand-QuickEquip"
const MOD_DIR_NAME := "Oudstand-QuickEquip"

# Diese Variable stellt sicher, dass die Items nur einmal pro Lauf gegeben werden.
var items_given := false
var options_registered := false
var registration_retry_time := 0.0

# Track which items/weapons were given to properly remove them later
var given_weapons := []  # Array of weapon IDs
var given_items := []    # Array of item IDs


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_load_translations(mod_dir_path)


func _load_translations(mod_dir_path: String) -> void:
	var translations_dir := mod_dir_path.plus_file("translations")
	ModLoaderMod.add_translation(translations_dir.plus_file("QuickEquip.en.translation"))
	ModLoaderMod.add_translation(translations_dir.plus_file("QuickEquip.de.translation"))


func _ready():
	ModLoaderLog.info("QuickEquip Mod ready. Waiting for a run to start...", MOD_ID)
	## Register options with a small delay to ensure ModOptions is ready
	call_deferred("_register_mod_options")


func _get_mod_options() -> Node:
	# Get sibling mod node (both are children of ModLoader)
	var parent = get_parent()
	if not parent:
		return null
	var mod_options_mod = parent.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null
	return mod_options_mod.get_node_or_null("ModOptions")


func _register_mod_options() -> void:
	var mod_options = _get_mod_options()
	if not mod_options:
		return
	mod_options.register_mod_options("QuickEquip", {
		"tab_title": "Quick Equip",
		"options": [
			{
				"type": "item_selector",
				"id": "weapons_list",
				"label": "QUICKEQUIP_WEAPONS_LABEL",
				"default": [],
				"item_type": "weapon",
				"help_text": "QUICKEQUIP_WEAPONS_HELP"
			},
			{
				"type": "item_selector",
				"id": "items_list",
				"label": "QUICKEQUIP_ITEMS_LABEL",
				"default": [],
				"item_type": "item",
				"help_text": "QUICKEQUIP_ITEMS_HELP"
			}
		],
		"info_text": "QUICKEQUIP_INFO_TEXT"
	})

	options_registered = true
	ModLoaderLog.info("QuickEquip options registered successfully", MOD_ID)

	# Connect to config changes to reapply items when options change during a run
	if not mod_options.is_connected("config_changed", self, "_on_config_changed"):
		mod_options.connect("config_changed", self, "_on_config_changed")


func _process(delta):
	# Try to register if not yet registered (with throttling to avoid spam)
	if not options_registered:
		registration_retry_time += delta
		if registration_retry_time >= 0.5:  # Try every 0.5 seconds
			registration_retry_time = 0.0
			_register_mod_options()
		return

	# Wir prüfen in jedem Frame (Polling), ob ein Lauf gestartet wurde.
	# Ein Signal-basierter Ansatz war in Tests nicht zuverlässig, daher diese robuste Methode.
	if not items_given and is_instance_valid(RunData) and RunData.get_player_count() > 0 and RunData.current_wave >= 1:
		# WICHTIG: Wir müssen warten, bis die Main-Szene aktiv ist (nicht mehr Pause/Character Selection)
		var current_scene = get_tree().get_current_scene()
		if not is_instance_valid(current_scene) or current_scene.name != "Main":
			return  # Warte, bis Main-Szene aktiv ist

		items_given = true
		ModLoaderLog.info("Run detected in Main scene (Wave >= 1, Players > 0). Giving items now!", "TestItems")

		# Wir warten eine Sekunde, um sicherzustellen, dass die Spiel-UI vollständig geladen ist,
		# bevor wir versuchen, sie zu aktualisieren.
		yield(get_tree().create_timer(1.0), "timeout")
		_give_items()

	# Wenn der Spieler zum Menü zurückkehrt (Spieleranzahl ist 0), setzen wir den Mod zurück.
	if items_given and RunData.get_player_count() == 0:
		items_given = false
		given_weapons.clear()
		given_items.clear()
		ModLoaderLog.info("Back in menu. QuickEquip Mod is reset for the next run.", "TestItems")


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	# Only react to QuickEquip config changes
	if mod_id != "QuickEquip":
		return

	# Only reapply items if a run is active
	if not items_given or RunData.get_player_count() == 0:
		return

	# Only reapply if weapons_list or items_list changed
	if option_id == "weapons_list" or option_id == "items_list":
		ModLoaderLog.info("Items configuration changed, clearing and reapplying items...", MOD_ID)
		_clear_all_given_items()
		_give_items()


func _clear_all_given_items() -> void:
	var player_index = 0

	# Get the player entity
	var main = get_tree().get_current_scene()
	var player = null
	if is_instance_valid(main) and "_players" in main:
		player = main._players[player_index]

	# Step 1: Remove weapon nodes from player entity
	if is_instance_valid(player) and "current_weapons" in player:
		var nodes_to_remove = []
		var rundata_weapons = RunData.get_player_weapons(player_index)
		for weapon_node in player.current_weapons:
			if is_instance_valid(weapon_node):
				# Safely check if weapon_pos is within bounds
				if weapon_node.weapon_pos >= 0 and weapon_node.weapon_pos < rundata_weapons.size():
					var weapon_data = rundata_weapons[weapon_node.weapon_pos]
					if is_instance_valid(weapon_data) and given_weapons.has(weapon_data.my_id):
						nodes_to_remove.append(weapon_node)

		for node in nodes_to_remove:
			player.current_weapons.erase(node)
			node.queue_free()
			ModLoaderLog.info("Removed weapon node", MOD_ID)

		# Update remaining weapon positions
		for i in range(player.current_weapons.size()):
			player.current_weapons[i].weapon_pos = i

	# Step 2: Remove weapon data from RunData (iterate backwards)
	var current_weapons = RunData.get_player_weapons(player_index)
	for i in range(current_weapons.size() - 1, -1, -1):
		var weapon = current_weapons[i]
		if is_instance_valid(weapon) and given_weapons.has(weapon.my_id):
			RunData.remove_weapon_by_index(i, player_index)
			ModLoaderLog.info("Removed weapon data: %s" % weapon.my_id, MOD_ID)

	# Step 3: Remove items from RunData
	var current_items = RunData.get_player_items(player_index)
	var items_to_remove = []
	for item in current_items:
		if is_instance_valid(item) and given_items.has(item.my_id):
			items_to_remove.append(item)

	for item in items_to_remove:
		RunData.remove_item(item, player_index)
		ModLoaderLog.info("Removed item: %s" % item.my_id, MOD_ID)

	# Clear the tracking arrays
	given_weapons.clear()
	given_items.clear()

	ModLoaderLog.info("Cleared all QuickEquip items", MOD_ID)


func _give_items():
	ModLoaderLog.info("=== GIVING TEST ITEMS ===", "TestItems")
	var player_index = 0

	# Read configuration from ModOptions
	var mod_options = _get_mod_options()
	if not mod_options:
		ModLoaderLog.error("ModOptions not available", "TestItems")
		return

	# Get lists from ModOptions (now Arrays of Dictionaries)
	var weapons_to_give = mod_options.get_value("QuickEquip", "weapons_list")
	var items_to_give = mod_options.get_value("QuickEquip", "items_list")

	if not weapons_to_give is Array:
		weapons_to_give = []
	if not items_to_give is Array:
		items_to_give = []

	# --- Waffen-Logik ---
	var all_weapons_list = ItemService.get("weapons")
	if is_instance_valid(ItemService) and all_weapons_list != null:
		for weapon_data in weapons_to_give:
			# weapon_data is now a Dictionary: {id, count, cursed}
			var weapon_id = weapon_data.get("id", "")
			var is_cursed = weapon_data.get("cursed", false)
			var count = weapon_data.get("count", 1)

			if weapon_id.empty():
				continue

			var base_weapon = null
			for w in all_weapons_list:
				var current_weapon_id = w.my_id if "my_id" in w else ""
				if not current_weapon_id.empty() and current_weapon_id == weapon_id:
					base_weapon = w
					break

			if is_instance_valid(base_weapon):
				for _i in range(count):
					var weapon = base_weapon.duplicate()
					weapon.is_cursed = is_cursed
					var returned_weapon = RunData.add_weapon(weapon, player_index)

					# Actually equip the weapon by adding it to the player entity
					var main = get_tree().get_current_scene()
					if is_instance_valid(main) and "_players" in main:
						var player = main._players[player_index]
						if is_instance_valid(player) and player.has_method("add_weapon"):
							# Use current size of player weapons array as position
							var weapon_pos = player.current_weapons.size()
							player.add_weapon(returned_weapon, weapon_pos)
							ModLoaderLog.info("Equipped weapon: %s at position %d" % [weapon_id, weapon_pos], "TestItems")

				# Track this weapon ID for later removal
				if not given_weapons.has(weapon_id):
					given_weapons.append(weapon_id)

				# Verify weapons were added
				var current_weapons = RunData.get_player_weapons(player_index)
				ModLoaderLog.info("Added weapon: %s (cursed: %s, count: %d) - Total weapons now: %d" % [weapon_id, is_cursed, count, current_weapons.size()], "TestItems")
			else:
				ModLoaderLog.error("Weapon not found in ItemService.weapons: %s" % weapon_id, "TestItems")
	else:
		ModLoaderLog.error("ItemService or ItemService.weapons not found!", "TestItems")

	# --- Item-Logik ---
	for item_data in items_to_give:
		# item_data is now a Dictionary: {id, count, cursed}
		var item_id = item_data.get("id", "")
		var is_cursed = item_data.get("cursed", false)
		var count = item_data.get("count", 1)

		if item_id.empty():
			continue

		var item = ItemService.get_element(ItemService.items, item_id)
		if is_instance_valid(item):
			for _i in range(count):
				var item_copy = item.duplicate()
				item_copy.is_cursed = is_cursed
				RunData.add_item(item_copy, player_index)

			# Track this item ID for later removal
			if not given_items.has(item_id):
				given_items.append(item_id)

			# Verify items were added
			var current_items = RunData.get_player_items(player_index)
			ModLoaderLog.info("Added item: %s (cursed: %s, count: %d) - Total items now: %d" % [item_id, is_cursed, count, current_items.size()], "TestItems")
		else:
			ModLoaderLog.error("Failed to create item: %s" % item_id, "TestItems")
	
	ModLoaderLog.info("=== ITEMS GIVEN SUCCESSFULLY ===", "TestItems")

	# UI Refresh: Force player entity and stats update (signals no longer exist in 1.1.13.0)
	yield(get_tree(), "idle_frame")

	# Get the main scene to access players
	var main = get_tree().get_current_scene()
	if is_instance_valid(main) and "_players" in main:
		for i in range(main._players.size()):
			var player = main._players[i]
			if is_instance_valid(player) and player.has_method("update_player_stats"):
				player.update_player_stats(false)

	# Reset linked stats to recalculate all stat bonuses
	for i in RunData.get_player_count():
		LinkedStats.reset_player(i)
