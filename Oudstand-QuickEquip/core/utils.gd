extends Reference

# QuickEquip utility functions (loaded dynamically, no class_name needed)

# Utility functions for QuickEquip mod

static func make_item_key(id: String, is_cursed: bool) -> String:
	return "%s|%s" % [id, String(is_cursed)]


static func config_array_to_map(config: Array, include_cursed: bool = true) -> Dictionary:
	var result = {}
	for entry in config:
		if not entry is Dictionary:
			continue
		var id = entry.get("id", "")
		if id.empty():
			continue
		var count = int(entry.get("count", 1))
		if count <= 0:
			continue
		var cursed = include_cursed and bool(entry.get("cursed", false))
		var key = id
		if include_cursed:
			key = make_item_key(id, cursed)
		if result.has(key):
			result[key].count += count
		else:
			result[key] = {"id": id, "cursed": cursed, "count": count}
	return result


static func deep_copy_config(config: Array) -> Array:
	var copy = []
	for entry in config:
		if entry is Dictionary:
			copy.append(entry.duplicate(true))
	return copy


static func get_weapon_template(weapon_id: String):
	if not is_instance_valid(ItemService):
		return null
	var all_weapons_list = ItemService.get("weapons")
	if all_weapons_list == null:
		return null

	for weapon in all_weapons_list:
		var current_weapon_id = weapon.my_id if "my_id" in weapon else ""
		if not current_weapon_id.empty() and current_weapon_id == weapon_id:
			return weapon

	return null


static func equip_weapon_on_player(scene_tree, weapon_data: WeaponData, player_index: int) -> void:
	if scene_tree == null:
		return
	var main = scene_tree.get_current_scene()
	if is_instance_valid(main) and "_players" in main:
		if player_index < 0 or player_index >= main._players.size():
			return
		var player = main._players[player_index]
		if is_instance_valid(player) and "current_weapons" in player and player.has_method("add_weapon"):
			var weapon_pos = player.current_weapons.size()
			player.add_weapon(weapon_data, weapon_pos)


static func remove_weapon_node_at_pos(scene_tree, player_index: int, weapon_pos: int) -> void:
	if scene_tree == null:
		return
	var main = scene_tree.get_current_scene()
	if not is_instance_valid(main) or not ("_players" in main):
		return
	if player_index < 0 or player_index >= main._players.size():
		return
	var player = main._players[player_index]
	if not is_instance_valid(player) or not ("current_weapons" in player):
		return

	var nodes_to_remove = []
	for weapon_node in player.current_weapons:
		if is_instance_valid(weapon_node) and weapon_node.weapon_pos == weapon_pos:
			nodes_to_remove.append(weapon_node)

	for node in nodes_to_remove:
		player.current_weapons.erase(node)
		node.queue_free()

	for i in range(player.current_weapons.size()):
		player.current_weapons[i].weapon_pos = i
