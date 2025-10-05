extends "res://ui/hud/ui_wave_timer.gd"

const UPDATE_INTERVAL: float = 0.1
const TOP_K: int = 6
const MOD_NAME: String = "DamageMeter"

onready var _hud: Control = get_tree().get_current_scene().get_node("UI/HUD")

var update_timer: Timer = null
var active_displays: Array = []
var all_display_containers: Array = []
var wave_start_item_damages: Dictionary = {}

var _prev_totals: PoolIntArray = PoolIntArray()
var _prev_sigs: Array = []

static func _cmp_desc_by_damage(a: Dictionary, b: Dictionary) -> bool:
	return a.damage > b.damage

static func _create_signature(sources: Array) -> String:
	var parts: PoolStringArray = PoolStringArray()
	for entry in sources:
		var key = entry.get("group_key", "")
		var dmg = entry.get("damage", 0)
		parts.append("%s:%d" % [key, dmg])
	return parts.join("|")

func _ready() -> void:
	var player_count: int = RunData.get_player_count()
	
	for i in range(4):
		var path = "LifeContainerP%s/PlayerDamageContainerP%s" % [str(i + 1), str(i + 1)]
		var container = _hud.get_node_or_null(path)
		if is_instance_valid(container):
			all_display_containers.append(container)
			
			if i < player_count:
				active_displays.append(container)
			else:
				container.visible = false
		else:
			all_display_containers.append(null)
	
	if active_displays.empty():
		return
	
	_snapshot_wave_start(player_count)
	
	_prev_totals.resize(player_count)
	_prev_sigs.resize(player_count)
	for i in range(player_count):
		_prev_totals[i] = -1
		_prev_sigs[i] = ""
	
	update_timer = Timer.new()
	update_timer.wait_time = UPDATE_INTERVAL
	update_timer.connect("timeout", self, "_update_damage_bars")
	add_child(update_timer)
	update_timer.start()

func _snapshot_wave_start(player_count: int) -> void:
	wave_start_item_damages.clear()
	
	for i in range(player_count):
		if RunData.tracked_item_effects.size() <= i:
			continue
		
		var item_map = {}
		for item_id in RunData.tracked_item_effects[i].keys():
			var val = RunData.tracked_item_effects[i].get(item_id, 0)
			item_map[item_id] = int(val) if typeof(val) != TYPE_ARRAY else 0
		
		wave_start_item_damages[i] = item_map

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
	
	# Taschenfabrik spawnt normale Geschütze
	if item.my_id == "item_pocket_factory":
		var turret = ItemService.get_item_from_id("item_turret")
		if is_instance_valid(turret):
			spawned.append(turret)
	
	return spawned

func _is_damage_tracking_item(source: Object) -> bool:
	"""Prüft ob ein Item Schaden trackt"""
	if not is_instance_valid(source):
		return false
	
	# Spezialfall: Engineering Turret (ITEM_BUILDER_TURRET) trackt immer Schaden
	if "name" in source and source.name == "ITEM_BUILDER_TURRET":
		return true
	
	# Items ohne tracking_text tracken keinen Schaden
	if not "tracking_text" in source:
		return false
	
	# Nur Items mit DAMAGE_DEALT tracking
	return source.tracking_text == "DAMAGE_DEALT"

func _get_source_damage(source: Object, player_index: int) -> int:
	if not is_instance_valid(source) or RunData.tracked_item_effects.size() <= player_index:
		return 0
	
	# Waffen tracken immer Schaden
	if source.has_method("get_category") and source.get_category() == Category.WEAPON:
		return int(source.dmg_dealt_last_wave) if "dmg_dealt_last_wave" in source else 0
	
	# Items/Characters müssen explizit Schaden tracken
	if "my_id" in source:
		if not _is_damage_tracking_item(source):
			return 0
		
		var item_id = source.my_id
		if not RunData.tracked_item_effects[player_index].has(item_id):
			return 0
		
		var start_val = wave_start_item_damages.get(player_index, {}).get(item_id, 0)
		var current_val = RunData.tracked_item_effects[player_index].get(item_id, 0)
		
		if typeof(current_val) == TYPE_ARRAY:
			return 0
		
		return int(max(0, current_val - start_val))
	
	return 0

func _create_group_key(source: Object) -> String:
	if not is_instance_valid(source):
		return ""
	
	var base = source.my_id if "my_id" in source else ""
	var tier = source.tier if "tier" in source else -1
	var cursed = source.is_cursed if "is_cursed" in source else false
	
	return "%s_t%d_c%s" % [base, tier, cursed]

func _add_to_group(groups: Dictionary, source: Object, damage: int) -> void:
	"""Fügt Schaden zu einer Gruppe hinzu oder erstellt neue Gruppe"""
	if damage <= 0:
		return
	
	var key = _create_group_key(source)
	if not groups.has(key):
		groups[key] = {
			"source": source,
			"damage": 0,
			"group_key": key,
			"count": 0
		}
	
	groups[key].damage += damage
	groups[key].count += 1

func _collect_grouped_sources(player_index: int) -> Array:
	var groups = {}
	
	# Waffen sammeln
	for weapon in RunData.get_player_weapons(player_index):
		if not is_instance_valid(weapon) or not "my_id" in weapon:
			continue
		
		var dmg = _get_source_damage(weapon, player_index)
		_add_to_group(groups, weapon, dmg)
		
		# Spawned items (Türme, Landminen)
		for spawned in _get_spawned_items_for_weapon(weapon):
			var spawned_dmg = _get_source_damage(spawned, player_index)
			_add_to_group(groups, spawned, spawned_dmg)
	
	# Items sammeln
	for item in RunData.get_player_items(player_index):
		if not is_instance_valid(item) or not "my_id" in item:
			continue
		
		var dmg = _get_source_damage(item, player_index)
		_add_to_group(groups, item, dmg)
		
		# Spawned items von Items (z.B. Taschenfabrik)
		for spawned in _get_spawned_items_for_item(item):
			var spawned_dmg = _get_source_damage(spawned, player_index)
			_add_to_group(groups, spawned, spawned_dmg)
	
	var result = []
	for group in groups.values():
		result.append(group)
	
	return result

func _get_top_sources(player_index: int) -> Array:
	var all_sources = _collect_grouped_sources(player_index)
	all_sources.sort_custom(self, "_cmp_desc_by_damage")
	return all_sources.slice(0, TOP_K - 1) if all_sources.size() > TOP_K else all_sources

func _update_damage_bars() -> void:
	var wave_active = is_instance_valid(wave_timer) and wave_timer.time_left > 0.0
	
	if not wave_active:
		for display in active_displays:
			if is_instance_valid(display):
				display._target_alpha = 0.0
		return
	
	var player_count = active_displays.size()
	var totals = PoolIntArray()
	totals.resize(player_count)
	var max_total = 0
	
	# Gesamtschaden berechnen
	for i in range(player_count):
		var sources = _collect_grouped_sources(i)
		var total = 0
		for group in sources:
			total += group.damage
		
		totals[i] = total
		if total > max_total:
			max_total = total
	
	# Prozentsätze berechnen
	var percentages = []
	for i in range(player_count):
		var pct = 0.0
		if max_total > 0:
			pct = (float(totals[i]) / float(max_total)) * 100.0
		percentages.append(pct)
	
	# UI aktualisieren
	for i in range(player_count):
		if i >= active_displays.size() or not is_instance_valid(active_displays[i]):
			continue
		
		var display = active_displays[i]
		display.visible = true
		display._target_alpha = 1.0
		
		var total = totals[i]
		var top_sources = _get_top_sources(i)
		var signature = _create_signature(top_sources)
		
		var total_changed = _prev_totals[i] != total
		var sig_changed = _prev_sigs[i] != signature
		
		var character = RunData.get_player_character(i)
		var icon = character.icon if is_instance_valid(character) and "icon" in character else null
		
		# Balken immer aktualisieren (auch wenn nur max_total sich ändert)
		display.update_total_damage(total, percentages[i], max_total, icon, i)
		
		# Source List nur bei Änderung aktualisieren
		if sig_changed:
			display.update_source_list(top_sources, i)
			_prev_sigs[i] = signature
		
		if total_changed:
			_prev_totals[i] = total

func _exit_tree() -> void:
	if is_instance_valid(update_timer):
		update_timer.queue_free()
