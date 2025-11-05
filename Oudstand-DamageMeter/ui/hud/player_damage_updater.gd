extends "res://ui/hud/ui_wave_timer.gd"

# === SETTINGS ===
# Config is managed by ModOptions
# Configure in-game via Options → Damage Meter
# ================

const MOD_NAME: String = "DamageMeter"

# Fixed settings (not configurable via ModOptions)
const UPDATE_INTERVAL: float = 0.1
const ANIMATION_SPEED: float = 6.0
const MIN_DAMAGE_FILTER: int = 1
const COMPACT_MODE: bool = false

# Config values (loaded from ModOptions)
var TOP_K: int = 6
var SHOW_ITEM_COUNT: bool = true
var SHOW_DPS: bool = false
var BAR_OPACITY: float = 1.0
var SHOW_PERCENTAGE: bool = true
var HIDE_TOTAL_BAR_SINGLEPLAYER: bool = false

onready var _hud: Control = get_tree().get_current_scene().get_node("UI/HUD")

var _update_accumulator: float = 0.0
var active_displays: Array = []
var all_display_containers: Array = []
var wave_start_item_damages: Dictionary = {}
var wave_start_time: float = 0.0

var _prev_totals: Array = []
var _prev_sigs: Array = []

# Performance optimization: Cache for source structure
var _source_cache: Array = []
var _cache_valid: PoolByteArray = PoolByteArray()

static func _cmp_desc_by_damage(a: Dictionary, b: Dictionary) -> bool:
	return a.damage > b.damage

static func _create_signature(sources: Array) -> String:
	var parts: PoolStringArray = PoolStringArray()
	for entry in sources:
		var key = entry.get("group_key", "")
		var dmg = entry.get("damage", 0)
		var cnt = entry.get("count", 1)
		parts.append("%s:%d:%d" % [key, dmg, cnt])
	return parts.join("|")

func _get_mod_options() -> Node:
	# Try to find ModOptions via ModLoader parent structure
	# Extended script nodes are in scene tree, we can navigate up
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

func _load_config() -> void:
	var mod_options = _get_mod_options()
	if not mod_options:
		ModLoaderLog.warning("ModOptions not found, using defaults", MOD_NAME)
		return

	TOP_K = int(mod_options.get_value("DamageMeter", "top_k"))
	SHOW_ITEM_COUNT = mod_options.get_value("DamageMeter", "show_item_count")
	SHOW_DPS = mod_options.get_value("DamageMeter", "show_dps")
	BAR_OPACITY = mod_options.get_value("DamageMeter", "opacity")
	SHOW_PERCENTAGE = mod_options.get_value("DamageMeter", "show_percentage")
	HIDE_TOTAL_BAR_SINGLEPLAYER = mod_options.get_value("DamageMeter", "hide_total_bar_singleplayer")

func _on_config_changed(_mod_id: String, _option_id: String, _new_value) -> void:
	# Reload config from ModOptions
	_load_config()

	# Update displays
	for display in active_displays:
		if is_instance_valid(display):
			display.set_animation_settings(ANIMATION_SPEED, BAR_OPACITY, COMPACT_MODE)

	# Invalidate cache to apply changes immediately
	_invalidate_all_caches()

func _ready() -> void:
	# Load config from ModOptions
	_load_config()

	# Connect to config changes
	var mod_options = _get_mod_options()
	if mod_options:
		mod_options.connect("config_changed", self, "_on_config_changed")

	var player_count: int = RunData.get_player_count()

	for i in range(4):
		var path = "LifeContainerP%s/PlayerDamageContainerP%s" % [str(i + 1), str(i + 1)]
		var container = _hud.get_node_or_null(path)
		if is_instance_valid(container):
			all_display_containers.append(container)

			if i < player_count:
				active_displays.append(container)
				# Apply loaded settings
				container.set_animation_settings(ANIMATION_SPEED, BAR_OPACITY, COMPACT_MODE)
				ModLoaderLog.debug("Set settings for P%d: BAR_OPACITY=%.2f" % [i+1, BAR_OPACITY], MOD_NAME)
			else:
				container.visible = false
		else:
			all_display_containers.append(null)
	
	if active_displays.empty():
		return
	
	_snapshot_wave_start(player_count)
	wave_start_time = OS.get_ticks_msec() / 1000.0
	
	_prev_totals.resize(player_count)
	_prev_sigs.resize(player_count)
	_source_cache.resize(player_count)
	_cache_valid.resize(player_count)
	
	for i in range(player_count):
		_prev_totals[i] = -1
		_prev_sigs[i] = ""
		_source_cache[i] = []
		_cache_valid[i] = 0

func _invalidate_all_caches() -> void:
	for i in range(_cache_valid.size()):
		_cache_valid[i] = 0

func _snapshot_wave_start(player_count: int) -> void:
	wave_start_item_damages.clear()
	wave_start_time = OS.get_ticks_msec() / 1000.0

	# Update charm tracking state for performance optimization
	var charm_tracker = get_node_or_null("/root/ModLoader/Oudstand-DamageMeter/DamageMeterCharmTracker")
	if is_instance_valid(charm_tracker):
		charm_tracker.update_charm_tracking_state()

		# Initialize charmed_enemies_damage key if charm tracking is enabled
		# This ensures the key exists in RunData.tracked_item_effects
		# It will be filtered by MIN_DAMAGE_FILTER until damage >= 1
		if charm_tracker.charm_tracking_enabled:
			for i in range(player_count):
				if RunData.tracked_item_effects.size() > i:
					RunData.tracked_item_effects[i]["charmed_enemies_damage"] = 0


	# Find builder turrets and update their tracking keys
	_fix_builder_turret_tracking_keys(player_count)

	for i in range(player_count):
		if RunData.tracked_item_effects.size() <= i:
			continue

		var item_map = {}
		for item_id in RunData.tracked_item_effects[i].keys():
			var val = RunData.tracked_item_effects[i].get(item_id, 0)
			var current_val = int(val) if typeof(val) != TYPE_ARRAY else 0

			# For builder turret items, the game resets the counter between waves
			# We reset both the snapshot AND the actual value to ensure sync
			if item_id.begins_with("item_builder_turret_"):
				RunData.tracked_item_effects[i][item_id] = 0
				item_map[item_id] = 0
			# For charmed enemies damage, also reset between waves
			elif item_id == "charmed_enemies_damage":
				RunData.tracked_item_effects[i][item_id] = 0
				item_map[item_id] = 0
			else:
				item_map[item_id] = current_val

		wave_start_item_damages[i] = item_map

func _fix_builder_turret_tracking_keys(_player_count: int) -> void:
	# Get the main scene to access structures
	var main = get_tree().get_current_scene()
	if not is_instance_valid(main):
		return

	# Try to get EntitySpawner
	var entity_spawner = main.get_node_or_null("EntitySpawner")
	if not is_instance_valid(entity_spawner) or not "structures" in entity_spawner:
		return

	# Iterate through all structures to find builder turrets
	for structure in entity_spawner.structures:
		if not is_instance_valid(structure):
			continue

		# Check if it's a builder turret
		if not structure.get_script():
			continue

		var script_path = structure.get_script().resource_path
		if "builder_turret" in script_path.to_lower():
			# Found a builder turret!
			if "player_index" in structure and "_damage_tracking_key" in structure and "_current_level" in structure:
				var current_level = structure._current_level
				var expected_key = "item_builder_turret_" + str(current_level)

				# Update the tracking key to match the current level
				if structure._damage_tracking_key != expected_key:
					structure._damage_tracking_key = expected_key

func _get_turret_id_for_tier(weapon: Object) -> String:
	if not is_instance_valid(weapon) or not "tier" in weapon:
		return ""
	
	match weapon.tier:
		Tier.COMMON: return "item_turret"
		Tier.UNCOMMON: return "item_turret_flame"
		Tier.RARE: return "item_turret_laser"
		Tier.LEGENDARY: return "item_turret_rocket"
	
	return ""

func _get_spawned_items_for_weapon(weapon: Object) -> Array:
	var spawned = []
	
	if not is_instance_valid(weapon) or not "name" in weapon:
		return spawned
	
	if weapon.name == "WEAPON_WRENCH":
		var turret_id = _get_turret_id_for_tier(weapon)
		if turret_id:
			var turret = ItemService.get_item_from_id(turret_id)
			if is_instance_valid(turret):
				spawned.append(turret)
	elif weapon.name == "WEAPON_SCREWDRIVER":
		var landmine = ItemService.get_item_from_id("item_landmines")
		if is_instance_valid(landmine):
			spawned.append(landmine)
	
	return spawned

func _get_spawned_items_for_item(item: Object) -> Array:
	var spawned = []

	if not is_instance_valid(item) or not "my_id" in item:
		return spawned

	if item.my_id == "item_pocket_factory":
		var turret = ItemService.get_item_from_id("item_turret")
		if is_instance_valid(turret):
			spawned.append(turret)

	return spawned

func _create_virtual_charm_item() -> Dictionary:
	var charm_item = {
		"my_id": "charmed_enemies_damage",
		"name": "CHARMED_ENEMIES",
		"tier": Tier.COMMON,
		"is_cursed": false
	}

	# Use Romantic character icon for charm damage
	for character in ItemService.characters:
		if is_instance_valid(character) and character.my_id == "character_romantic":
			if "icon" in character and is_instance_valid(character.icon):
				charm_item["icon"] = character.icon
				break

	return charm_item

func _is_damage_tracking_item(source) -> bool:
	# Allow both Objects and Dictionaries
	if not is_instance_valid(source) and typeof(source) != TYPE_DICTIONARY:
		return false

	if "name" in source and source.name == "ITEM_BUILDER_TURRET":
		return true

	# Special case for charmed enemies (virtual Dictionary item)
	if "my_id" in source and source.my_id == "charmed_enemies_damage":
		return true

	if not "tracking_text" in source:
		return false

	return source.tracking_text == "DAMAGE_DEALT"

func _get_source_damage(source, player_index: int) -> int:
	# Allow both Objects and Dictionaries
	if not is_instance_valid(source) and typeof(source) != TYPE_DICTIONARY:
		return 0

	if "dmg_dealt_last_wave" in source:
		return int(source.dmg_dealt_last_wave)

	if player_index < 0 or player_index >= RunData.tracked_item_effects.size():
		return 0

	if not "my_id" in source:
		return 0

	if not _is_damage_tracking_item(source):
		return 0

	var item_id = source.my_id
	var effects = RunData.tracked_item_effects[player_index]

	if not effects.has(item_id):
		return 0

	var current_val = effects.get(item_id, 0)

	if typeof(current_val) == TYPE_ARRAY:
		return 0

	var start_val = wave_start_item_damages.get(player_index, {}).get(item_id, 0)
	var damage_diff = int(current_val - start_val)

	return max(0, damage_diff) as int

func _create_group_key(source) -> String:
	# Allow both Objects and Dictionaries
	if not is_instance_valid(source) and typeof(source) != TYPE_DICTIONARY:
		return ""

	var base = source.my_id if "my_id" in source else ""
	var tier = source.tier if "tier" in source else -1
	var cursed = source.is_cursed if "is_cursed" in source else false

	# For items, ignore cursed status (damage is tracked together by the game)
	# For weapons, keep cursed status (damage is tracked per weapon instance)
	var is_weapon = "dmg_dealt_last_wave" in source

	if is_weapon:
		return "%s_t%d_c%s" % [base, tier, cursed]
	else:
		return "%s_t%d" % [base, tier]

func _build_source_cache(player_index: int) -> Array:
	var sources = []

	# Direct access to weapons (no .duplicate())
	var weapons = RunData.players_data[player_index].weapons
	for weapon in weapons:
		if not is_instance_valid(weapon) or not "my_id" in weapon:
			continue

		sources.append(weapon)

		for spawned in _get_spawned_items_for_weapon(weapon):
			sources.append(spawned)

	# Direct access to items (no .duplicate())
	var items = RunData.players_data[player_index].items
	for item in items:
		if not is_instance_valid(item) or not "my_id" in item:
			continue

		sources.append(item)

		for spawned in _get_spawned_items_for_item(item):
			sources.append(spawned)

	# Add virtual item for charmed enemies damage (if tracked)
	if RunData.tracked_item_effects.size() > player_index:
		var effects = RunData.tracked_item_effects[player_index]
		if effects.has("charmed_enemies_damage"):
			var charm_item = _create_virtual_charm_item()
			sources.append(charm_item)

	return sources

func _collect_grouped_sources(player_index: int) -> Array:
	if _cache_valid[player_index] == 0:
		_source_cache[player_index] = _build_source_cache(player_index)
		_cache_valid[player_index] = 1

	var groups = {}
	var cached_sources = _source_cache[player_index]

	for source in cached_sources:
		# Skip invalid sources, but allow Dictionaries (charm item)
		if not is_instance_valid(source) and typeof(source) != TYPE_DICTIONARY:
			continue

		var dmg = _get_source_damage(source, player_index)

		if dmg < MIN_DAMAGE_FILTER:
			continue

		var key = _create_group_key(source)

		if groups.has(key):
			groups[key].count += 1

			# For weapons, accumulate damage (each weapon has its own dmg_dealt_last_wave)
			# For items, don't accumulate (they share the same tracked_item_effects entry)
			var is_weapon = "dmg_dealt_last_wave" in source
			if is_weapon:
				groups[key].damage += dmg

			# Prefer non-cursed icon for items (if this item is not cursed and current source is cursed)
			var current_is_cursed = groups[key].source.is_cursed if "is_cursed" in groups[key].source else false
			var new_is_cursed = source.is_cursed if "is_cursed" in source else false

			if current_is_cursed and not new_is_cursed:
				groups[key].source = source

			continue

		groups[key] = {
			"source": source,
			"damage": dmg,
			"group_key": key,
			"count": 1
		}

	# Override count for Pocket Factory spawned turrets
	_apply_spawned_count_overrides(groups, player_index)

	# Remove items that double-count damage (their damage is already included in weapon/item sources)
	# - Greek Fire: damage is included in burning sources
	# - Giant Belt: damage is included in crit sources
	groups.erase("item_greek_fire_t3")
	groups.erase("item_giant_belt_t3")

	return groups.values()

func _apply_spawned_count_overrides(groups: Dictionary, player_index: int) -> void:
	# Get Main scene to access Pocket Factory spawn counts
	var main = get_tree().get_current_scene()
	if not is_instance_valid(main) or not main.has_method("get_pocket_factory_spawns"):
		return

	var has_pf_item = RunData.get_nb_item("item_pocket_factory", player_index) > 0
	if not has_pf_item:
		return

	var pf_spawns = main.get_pocket_factory_spawns(player_index)
	if pf_spawns < 0:
		return

	# Find common turret group and add Pocket Factory spawns to count
	var turret_key = "item_turret_t0"  # Common turret (items don't include cursed status in key)
	if groups.has(turret_key):
		var base_count = groups[turret_key].count
		var non_pf_sources = max(0, base_count - 1)  # subtract Pocket Factory placeholder if present
		groups[turret_key].count = pf_spawns + non_pf_sources

func _get_top_sources(player_index: int) -> Array:
	var all_sources = _collect_grouped_sources(player_index)
	all_sources.sort_custom(self, "_cmp_desc_by_damage")

	var count = min(all_sources.size(), TOP_K)
	if count == 0:
		return []

	var result = []
	result.resize(count)
	for i in range(count):
		result[i] = all_sources[i]

	return result

func _physics_process(delta: float) -> void:
	_update_accumulator += delta
	if _update_accumulator >= UPDATE_INTERVAL:
		_update_accumulator -= UPDATE_INTERVAL
		_update_damage_bars()

func _update_damage_bars() -> void:
	var wave_active = is_instance_valid(wave_timer) and wave_timer.time_left > 0.0
	
	if not wave_active:
		for display in active_displays:
			if is_instance_valid(display):
				display._target_alpha = 0.0
		return
	
	var player_count = active_displays.size()
	var totals = []
	totals.resize(player_count)
	var max_total = 0

	for i in range(player_count):
		var sources = _collect_grouped_sources(i)
		var total = 0
		for group in sources:
			total += group.damage
		
		totals[i] = total
		if total > max_total:
			max_total = total

	var percentages = PoolRealArray()
	percentages.resize(player_count)

	if max_total > 0:
		var max_float = float(max_total)
		for i in range(player_count):
			percentages[i] = (float(totals[i]) / max_float) * 100.0
	else:
		for i in range(player_count):
			percentages[i] = 0.0

	var elapsed = (OS.get_ticks_msec() / 1000.0) - wave_start_time
	var dps_values = []
	dps_values.resize(player_count)

	# Initialize all values to 0
	for i in range(player_count):
		dps_values[i] = 0

	if elapsed > 0.1:
		for i in range(player_count):
			dps_values[i] = int(float(totals[i]) / elapsed)
	
	var show_percentage_ui = SHOW_PERCENTAGE and player_count > 1
	var hide_total_bar = HIDE_TOTAL_BAR_SINGLEPLAYER and player_count == 1

	for i in range(player_count):
		if i >= active_displays.size() or not is_instance_valid(active_displays[i]):
			continue

		var display = active_displays[i]
		display.visible = true
		display._target_alpha = BAR_OPACITY

		# Hide total damage bar in singleplayer if option is enabled
		var total_bar = display.get_node_or_null("TotalDamageBar")
		if is_instance_valid(total_bar):
			total_bar.visible = not hide_total_bar

		var total = totals[i]
		var dps = dps_values[i] if SHOW_DPS else 0
		var top_sources = _get_top_sources(i)
		var signature = _create_signature(top_sources)

		var total_changed = _prev_totals[i] != total
		var sig_changed = _prev_sigs[i] != signature

		var character = RunData.get_player_character(i)
		var icon = character.icon if is_instance_valid(character) and "icon" in character else null

		display.update_total_damage(
			total,
			percentages[i],
			max_total,
			icon,
			i,
			SHOW_DPS,
			dps,
			show_percentage_ui
		)

		if sig_changed:
			display.update_source_list(top_sources, i, SHOW_ITEM_COUNT)
			_prev_sigs[i] = signature
		
		if total_changed:
			_prev_totals[i] = total
