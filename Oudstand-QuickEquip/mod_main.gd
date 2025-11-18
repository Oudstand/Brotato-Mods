extends Node

const MOD_ID := "Oudstand-QuickEquip"
const MOD_DIR_NAME := "Oudstand-QuickEquip"

# ModOptions registration state
var options_registered := false
var registration_retry_count := 0
const MAX_REGISTRATION_RETRIES := 5

# Flag to prevent duplicate items in the same run (used by extension)
var _items_added_this_run := false

# Core modules (no type hints - loaded dynamically in _init)
var _tracker
var _sync_manager


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_load_core_modules(mod_dir_path)
	_load_translations(mod_dir_path)
	_install_extensions(mod_dir_path)


func _load_core_modules(mod_dir_path: String) -> void:
	var core_dir := mod_dir_path.plus_file("core")

	# Load utility class
	var utils_script = load(core_dir.plus_file("utils.gd"))

	# Load and instantiate tracker
	var tracker_script = load(core_dir.plus_file("item_tracker.gd"))
	_tracker = tracker_script.new()

	# Load and instantiate sync manager (pass self as owner node)
	var sync_manager_script = load(core_dir.plus_file("item_sync_manager.gd"))
	_sync_manager = sync_manager_script.new(_tracker, self)


func _load_translations(mod_dir_path: String) -> void:
	var translations_dir := mod_dir_path.plus_file("translations")
	ModLoaderMod.add_translation(translations_dir.plus_file("QuickEquip.en.translation"))
	ModLoaderMod.add_translation(translations_dir.plus_file("QuickEquip.de.translation"))


func _install_extensions(mod_dir_path: String) -> void:
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("run_data_extension.gd"))
	# Fix vanilla division by zero bug when removing projectile items (e.g., Alien Eyes)
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("projectile_effect_extension.gd"))


func _ready():
	ModLoaderLog.info("QuickEquip Mod ready!", MOD_ID)
	# Try to register options with a delay to ensure ModOptions is ready
	call_deferred("_register_mod_options")


func _process(_delta):
	# Reset tracking when returning to menu
	if is_instance_valid(RunData) and RunData.get_player_count() == 0:
		if _tracker.has_tracked_items():
			_clear_all_tracking()
			ModLoaderLog.info("Back in menu. QuickEquip tracking reset.", MOD_ID)


func _get_mod_options() -> Node:
	# Use absolute path via root for robustness (works regardless of node tree position)
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


func _register_mod_options() -> void:
	if options_registered:
		return

	# Retry loop instead of recursion to avoid stack buildup
	var mod_options = null
	while registration_retry_count < MAX_REGISTRATION_RETRIES:
		mod_options = _get_mod_options()
		if mod_options:
			break

		registration_retry_count += 1
		if registration_retry_count < MAX_REGISTRATION_RETRIES:
			yield(get_tree().create_timer(0.2), "timeout")

	if not mod_options:
		ModLoaderLog.error("Failed to register options after %d retries" % MAX_REGISTRATION_RETRIES, MOD_ID)
		return

	var selector_configs = [
		{
			"id_suffix": "weapons",
			"label_suffix": "WEAPONS",
			"item_type": "weapon",
			"extra": {"help_text": "QUICKEQUIP_WEAPONS_HELP"}
		},
		{
			"id_suffix": "items",
			"label_suffix": "ITEMS",
			"item_type": "item",
			"extra": {"help_text": "QUICKEQUIP_ITEMS_HELP"}
		},
		{
			"id_suffix": "abilities",
			"label_suffix": "ABILITIES",
			"item_type": "character",
			"extra": {
				"help_text": "QUICKEQUIP_ABILITIES_HELP",
				"show_count": false,
				"show_cursed": false
			}
		}
	]

	var options_array: Array = []
	for player_index in range(4):
		var player_num = player_index + 1
		var enable_id = "enable_player_%d" % player_num

		options_array.append({
			"type": "toggle",
			"id": enable_id,
			"label": "QUICKEQUIP_ENABLE_PLAYER_%d" % player_num,
			"default": player_num == 1
		})

		for selector_config in selector_configs:
			var selector_option = {
				"type": "item_selector",
				"id": "player_%d_%s" % [player_num, selector_config["id_suffix"]],
				"label": "QUICKEQUIP_PLAYER_%d_%s" % [player_num, selector_config["label_suffix"]],
				"default": [],
				"item_type": selector_config["item_type"],
				"visible_if": enable_id
			}

			if selector_config.has("extra"):
				for extra_key in selector_config["extra"].keys():
					selector_option[extra_key] = selector_config["extra"][extra_key]

			options_array.append(selector_option)

	mod_options.register_mod_options("QuickEquip", {
		"tab_title": "Quick Equip",
		"options": options_array,
		"info_text": "QUICKEQUIP_INFO_TEXT"
	})

	options_registered = true
	ModLoaderLog.info("QuickEquip options registered successfully", MOD_ID)

	# Connect to config changes to reapply items when options change during a run
	if not mod_options.is_connected("config_changed", self, "_on_config_changed"):
		mod_options.connect("config_changed", self, "_on_config_changed")


func _on_config_changed(mod_id: String, option_id: String, new_value) -> void:
	# Only react to QuickEquip config changes
	if mod_id != "QuickEquip":
		return

	# Only reapply items if a run is active
	if not is_instance_valid(RunData) or RunData.get_player_count() == 0:
		return

	# Only reapply if player-related options changed
	if option_id.begins_with("enable_player_") or option_id.begins_with("player_"):
		# Extract player number from option_id (e.g., "player_2_weapons" -> 2)
		var player_num = -1
		var regex = RegEx.new()
		regex.compile("(?:enable_)?player_(\\d+)")
		var result = regex.search(option_id)
		if result:
			player_num = int(result.get_string(1))

		if player_num > 0 and player_num <= 4:
			var player_index = player_num - 1
			ModLoaderLog.info("Items configuration changed for player %d, syncing..." % player_num, MOD_ID)
			_sync_single_player(player_index)
		else:
			ModLoaderLog.warning("Could not extract player number from option_id: %s" % option_id, MOD_ID)


func _clear_all_tracking() -> void:
	# Clear all tracking data when returning to menu
	# Note: We don't remove items here since the run is ending anyway
	_items_added_this_run = false
	_tracker.clear_all()


func _sync_single_player(player_index: int) -> void:
	# Sync items for a single player during active run
	if not is_instance_valid(RunData) or RunData.get_player_count() == 0:
		return

	# Additional safety: Check if we're in the Main scene (not menu)
	var tree = get_tree()
	if tree:
		var current_scene = tree.get_current_scene()
		if not current_scene or current_scene.name != "Main":
			return

	# Read configuration from ModOptions
	var mod_options = _get_mod_options()
	if not mod_options:
		ModLoaderLog.error("ModOptions not available", MOD_ID)
		return

	var player_num = player_index + 1

	var enabled_value = mod_options.get_value("QuickEquip", "enable_player_%d" % player_num)
	var player_enabled = enabled_value is bool and enabled_value
	if not player_enabled:
		_sync_manager.clear_all_given_items(player_index)
		return

	# Get lists for this specific player
	var weapons_to_give = mod_options.get_value("QuickEquip", "player_%d_weapons" % player_num)
	var items_to_give = mod_options.get_value("QuickEquip", "player_%d_items" % player_num)
	var abilities_to_apply = mod_options.get_value("QuickEquip", "player_%d_abilities" % player_num)

	if not weapons_to_give is Array:
		weapons_to_give = []
	if not items_to_give is Array:
		items_to_give = []
	if not abilities_to_apply is Array:
		abilities_to_apply = []

	# If all lists are empty, clear player's items
	if weapons_to_give.empty() and items_to_give.empty() and abilities_to_apply.empty():
		_sync_manager.clear_all_given_items(player_index)
		return

	# Sync via manager for this player
	_sync_manager.sync_items(weapons_to_give, items_to_give, abilities_to_apply, player_index)


# === Extension Interface ===
# These methods are called by run_data_extension.gd

func _track_weapon_instance(weapon_id: String, is_cursed: bool, weapon_data: WeaponData, player_index: int) -> void:
	_tracker.track_weapon_instance(weapon_id, is_cursed, weapon_data, player_index)


func _track_item_instance(item_id: String, is_cursed: bool, item_data: ItemData, player_index: int) -> void:
	_tracker.track_item_instance(item_id, is_cursed, item_data, player_index)


func _track_character_ability(character_id: String, ability_resource: CharacterData, player_index: int) -> void:
	_tracker.track_character_ability(character_id, ability_resource, player_index)


func _update_tracking_configs(weapons_config: Array, items_config: Array, abilities_config: Array, player_index: int) -> void:
	_tracker.update_tracking_configs(weapons_config, items_config, abilities_config, player_index)
