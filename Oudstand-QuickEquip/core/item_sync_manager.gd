class_name QuickEquipItemSyncManager
extends Reference

# Manages syncing items/weapons/abilities during runtime

const MOD_ID := "Oudstand-QuickEquip"
const Utils = preload("res://mods-unpacked/Oudstand-QuickEquip/core/utils.gd")

var _tracker
var _owner_node  # Reference to the mod_main node for accessing get_tree()


func _init(tracker, owner_node):
	_tracker = tracker
	_owner_node = owner_node


# === Public API ===

func sync_items(weapons_config: Array, items_config: Array, abilities_config: Array, player_index: int) -> void:
	# Get DLC data for curse functionality
	var dlc_data = null
	if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
		dlc_data = ProgressData.get_dlc_data("abyssal_terrors")

	# Sync all three types
	_sync_weapons_config(weapons_config, dlc_data, player_index)
	_sync_items_config(items_config, dlc_data, player_index)
	_sync_character_abilities(abilities_config, player_index)

	ModLoaderLog.info("Items synced successfully during run", MOD_ID)

	# UI Refresh: Force player entity and stats update
	if _owner_node and _owner_node.get_tree():
		yield(_owner_node.get_tree(), "idle_frame")
	else:
		return

	# Reset linked stats and recalculate from scratch
	for i in RunData.get_player_count():
		LinkedStats.reset_player(i)

	# Force RunData to recalculate all effects from items
	if is_instance_valid(RunData) and RunData.has_method("init_cache_player_effects"):
		for i in RunData.get_player_count():
			RunData.init_cache_player_effects(i)

	# Update player stats to apply recalculated bonuses
	var main = _owner_node.get_tree().get_current_scene()
	if is_instance_valid(main) and "_players" in main:
		for i in range(main._players.size()):
			var player = main._players[i]
			if is_instance_valid(player) and player.has_method("update_player_stats"):
				player.update_player_stats(false)


func clear_all_given_items(player_index: int) -> void:
	_remove_all_tracked_weapons(player_index)
	_remove_all_tracked_items(player_index)
	_clear_character_abilities(player_index)
	_tracker.last_weapon_config.erase(player_index)
	_tracker.last_item_config.erase(player_index)
	_tracker.last_ability_config.erase(player_index)

	ModLoaderLog.info("Cleared all QuickEquip items for player %d" % player_index, MOD_ID)


# === Sync Logic ===

func _sync_weapons_config(desired_config: Array, dlc_data, player_index: int) -> void:
	var desired_map = Utils.config_array_to_map(desired_config)
	var current_config = _tracker.last_weapon_config.get(player_index, [])
	var current_map = Utils.config_array_to_map(current_config)

	# Remove weapons that are no longer in config
	for key in current_map.keys():
		var current_count = current_map[key].count
		var desired_count = 0
		if desired_map.has(key):
			desired_count = desired_map[key].count
		var to_remove = current_count - desired_count
		if to_remove > 0:
			_remove_tracked_weapons(key, to_remove, player_index)

	# Add weapons that are new or increased
	for key in desired_map.keys():
		var desired_count = desired_map[key].count
		var current_count = 0
		if current_map.has(key):
			current_count = current_map[key].count
		var to_add = desired_count - current_count
		if to_add > 0:
			var entry = desired_map[key]
			_add_weapon_instances(entry.id, entry.cursed, to_add, dlc_data, player_index)

	_tracker.last_weapon_config[player_index] = Utils.deep_copy_config(desired_config)


func _sync_items_config(desired_config: Array, dlc_data, player_index: int) -> void:
	var desired_map = Utils.config_array_to_map(desired_config)
	var current_config = _tracker.last_item_config.get(player_index, [])
	var current_map = Utils.config_array_to_map(current_config)

	# Remove items that are no longer in config
	for key in current_map.keys():
		var current_count = current_map[key].count
		var desired_count = 0
		if desired_map.has(key):
			desired_count = desired_map[key].count
		var to_remove = current_count - desired_count
		if to_remove > 0:
			_remove_tracked_items(key, to_remove, player_index)

	# Add items that are new or increased
	for key in desired_map.keys():
		var desired_count = desired_map[key].count
		var current_count = 0
		if current_map.has(key):
			current_count = current_map[key].count
		var to_add = desired_count - current_count
		if to_add > 0:
			var entry = desired_map[key]
			_add_item_instances(entry.id, entry.cursed, to_add, dlc_data, player_index)

	_tracker.last_item_config[player_index] = Utils.deep_copy_config(desired_config)


func _sync_character_abilities(desired_config: Array, player_index: int) -> void:
	if not is_instance_valid(ItemService):
		ModLoaderLog.error("ItemService not available, cannot apply character abilities.", MOD_ID)
		return

	var desired_map = Utils.config_array_to_map(desired_config, false)
	var current_config = _tracker.last_ability_config.get(player_index, [])
	var current_map = Utils.config_array_to_map(current_config, false)

	# Remove abilities that are no longer in config
	for key in current_map.keys():
		var current_count = current_map[key].count
		var desired_count = 0
		if desired_map.has(key):
			desired_count = desired_map[key].count
		var to_remove = current_count - desired_count
		if to_remove > 0:
			_remove_character_abilities(key, to_remove, player_index)

	# Add abilities that are new or increased
	for key in desired_map.keys():
		var desired_count = desired_map[key].count
		var current_count = 0
		if current_map.has(key):
			current_count = current_map[key].count
		var to_add = desired_count - current_count
		if to_add > 0:
			_add_character_abilities(key, to_add, player_index)

	_tracker.last_ability_config[player_index] = Utils.deep_copy_config(desired_config)


# === Add Logic ===

func _add_weapon_instances(weapon_id: String, is_cursed: bool, count: int, dlc_data, player_index: int) -> void:
	if count <= 0:
		return

	# Safety check: Don't add weapons if player index is invalid
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		ModLoaderLog.warning("Cannot add weapon - invalid player_index %d (player_count: %d)" % [player_index, RunData.get_player_count() if is_instance_valid(RunData) else -1], MOD_ID)
		return

	var base_weapon = Utils.get_weapon_template(weapon_id)
	if base_weapon == null:
		ModLoaderLog.error("Weapon not found in ItemService.weapons: %s" % weapon_id, MOD_ID)
		return

	for _i in range(count):
		var weapon = base_weapon.duplicate()

		if is_cursed and dlc_data:
			weapon = dlc_data.curse_item(weapon, player_index, true)
		else:
			weapon.is_cursed = is_cursed

		var returned_weapon = RunData.add_weapon(weapon, player_index)
		if _owner_node:
			Utils.equip_weapon_on_player(_owner_node.get_tree(), returned_weapon, player_index)
		_tracker.track_weapon_instance(weapon_id, is_cursed, returned_weapon, player_index)


func _add_item_instances(item_id: String, is_cursed: bool, count: int, dlc_data, player_index: int) -> void:
	if count <= 0:
		return

	# Safety check: Don't add items if player index is invalid
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		ModLoaderLog.warning("Cannot add item - invalid player_index %d (player_count: %d)" % [player_index, RunData.get_player_count() if is_instance_valid(RunData) else -1], MOD_ID)
		return

	var item = ItemService.get_element(ItemService.items, item_id)
	if not is_instance_valid(item):
		ModLoaderLog.error("Failed to create item: %s" % item_id, MOD_ID)
		return

	for _i in range(count):
		var item_copy = item.duplicate()

		if is_cursed and dlc_data:
			item_copy = dlc_data.curse_item(item_copy, player_index, true)
		else:
			item_copy.is_cursed = is_cursed

		RunData.add_item(item_copy, player_index)
		_tracker.track_item_instance(item_id, is_cursed, item_copy, player_index)


func _add_character_abilities(character_id: String, count: int, player_index: int) -> void:
	if count <= 0:
		return

	# Safety check: Don't add abilities if player index is invalid
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		ModLoaderLog.warning("Cannot add ability - invalid player_index %d (player_count: %d)" % [player_index, RunData.get_player_count() if is_instance_valid(RunData) else -1], MOD_ID)
		return

	var character_data = ItemService.get_element(ItemService.characters, character_id)
	if not is_instance_valid(character_data):
		ModLoaderLog.error("Character ability not found: %s" % character_id, MOD_ID)
		return

	for _i in range(count):
		var ability_copy = character_data.duplicate()
		RunData.add_item(ability_copy, player_index)
		_tracker.track_character_ability(character_id, ability_copy, player_index)


# === Remove Logic ===

func _remove_tracked_weapons(key: String, count: int, player_index: int) -> void:
	if count <= 0:
		return
	if not _tracker.given_weapons.has(player_index) or not _tracker.given_weapons[player_index].has(key):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		_tracker.given_weapons[player_index].erase(key)
		return

	var weapon_list: Array = _tracker.given_weapons[player_index][key]
	for _i in range(min(count, weapon_list.size())):
		var weapon_data = weapon_list.pop_back()
		_remove_weapon_resource(weapon_data, player_index)

	if weapon_list.empty():
		_tracker.given_weapons[player_index].erase(key)
	else:
		_tracker.given_weapons[player_index][key] = weapon_list


func _remove_tracked_items(key: String, count: int, player_index: int) -> void:
	if count <= 0:
		return
	if not _tracker.given_items.has(player_index) or not _tracker.given_items[player_index].has(key):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		_tracker.given_items[player_index].erase(key)
		return

	var item_list: Array = _tracker.given_items[player_index][key]
	for _i in range(min(count, item_list.size())):
		var item_data = item_list.pop_back()
		if is_instance_valid(item_data):
			RunData.remove_item(item_data, player_index)

	if item_list.empty():
		_tracker.given_items[player_index].erase(key)
	else:
		_tracker.given_items[player_index][key] = item_list


func _remove_character_abilities(key: String, count: int, player_index: int) -> void:
	if count <= 0:
		return
	if not _tracker.applied_character_abilities.has(player_index) or not _tracker.applied_character_abilities[player_index].has(key):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		_tracker.applied_character_abilities[player_index].erase(key)
		return

	var ability_list: Array = _tracker.applied_character_abilities[player_index][key]
	for _i in range(min(count, ability_list.size())):
		var ability_resource = ability_list.pop_back()
		if is_instance_valid(ability_resource):
			RunData.remove_item(ability_resource, player_index, true)

	if ability_list.empty():
		_tracker.applied_character_abilities[player_index].erase(key)
	else:
		_tracker.applied_character_abilities[player_index][key] = ability_list


func _remove_all_tracked_weapons(player_index: int) -> void:
	if not _tracker.given_weapons.has(player_index):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		_tracker.given_weapons.erase(player_index)
		return
	for key in _tracker.given_weapons[player_index].keys():
		_remove_tracked_weapons(key, _tracker.given_weapons[player_index][key].size(), player_index)
	_tracker.given_weapons.erase(player_index)


func _remove_all_tracked_items(player_index: int) -> void:
	if not _tracker.given_items.has(player_index):
		return
	if not is_instance_valid(RunData) or RunData.get_player_count() <= player_index:
		_tracker.given_items.erase(player_index)
		return
	for key in _tracker.given_items[player_index].keys():
		_remove_tracked_items(key, _tracker.given_items[player_index][key].size(), player_index)
	_tracker.given_items.erase(player_index)


func _clear_character_abilities(player_index: int) -> void:
	if not _tracker.applied_character_abilities.has(player_index):
		return
	if _tracker.applied_character_abilities[player_index].empty():
		return

	var can_remove = is_instance_valid(RunData) and RunData.get_player_count() > player_index

	if not can_remove:
		_tracker.applied_character_abilities.erase(player_index)
		return

	var keys = _tracker.applied_character_abilities[player_index].keys()
	for key in keys:
		_remove_character_abilities(key, _tracker.applied_character_abilities[player_index][key].size(), player_index)

	_tracker.applied_character_abilities.erase(player_index)


func _remove_weapon_resource(weapon_data: WeaponData, player_index: int) -> void:
	if not is_instance_valid(weapon_data):
		return

	var current_weapons = RunData.get_player_weapons(player_index)
	for i in range(current_weapons.size()):
		if current_weapons[i] == weapon_data:
			if _owner_node:
				Utils.remove_weapon_node_at_pos(_owner_node.get_tree(), player_index, i)
			RunData.remove_weapon_by_index(i, player_index)
			return
