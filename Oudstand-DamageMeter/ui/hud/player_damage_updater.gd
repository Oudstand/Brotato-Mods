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

# Performance-Optimierung: Cache für Source-Struktur
var _source_cache: Array = []  # Pro Spieler: Array von Source-Objekten
var _cache_valid: PoolByteArray = PoolByteArray()  # Pro Spieler: ist Cache gültig?

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
	_source_cache.resize(player_count)
	_cache_valid.resize(player_count)
	
	for i in range(player_count):
		_prev_totals[i] = -1
		_prev_sigs[i] = ""
		_source_cache[i] = []
		_cache_valid[i] = 0
	
	# Events lauschen für Cache-Invalidierung
	var root = get_tree().root
	if root.has_signal("item_bought") or root.has_signal("item_sold"):
		root.connect("item_bought", self, "_invalidate_all_caches")
		root.connect("item_sold", self, "_invalidate_all_caches")
	
	update_timer = Timer.new()
	update_timer.wait_time = UPDATE_INTERVAL
	update_timer.connect("timeout", self, "_update_damage_bars")
	add_child(update_timer)
	update_timer.start()

func _invalidate_all_caches() -> void:
	for i in range(_cache_valid.size()):
		_cache_valid[i] = 0

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
	# Schnelle Checks zuerst
	if not is_instance_valid(source):
		return 0
	
	# Waffen tracken immer Schaden (schnellster Pfad)
	if "dmg_dealt_last_wave" in source:
		var dmg = source.dmg_dealt_last_wave
		return int(dmg) if typeof(dmg) == TYPE_INT or typeof(dmg) == TYPE_REAL else 0
	
	# Bounds check
	if player_index < 0 or player_index >= RunData.tracked_item_effects.size():
		return 0
	
	# Items/Characters müssen explizit Schaden tracken
	if not "my_id" in source:
		return 0
	
	if not _is_damage_tracking_item(source):
		return 0
	
	var item_id = source.my_id
	var effects = RunData.tracked_item_effects[player_index]
	
	if not effects.has(item_id):
		return 0
	
	var current_val = effects.get(item_id, 0)
	
	# Array-Check (manche Items tracken Arrays statt Zahlen)
	if typeof(current_val) == TYPE_ARRAY:
		return 0
	
	var start_val = wave_start_item_damages.get(player_index, {}).get(item_id, 0)
	return int(max(0, current_val - start_val))

func _create_group_key(source: Object) -> String:
	if not is_instance_valid(source):
		return ""
	
	var base = source.my_id if "my_id" in source else ""
	var tier = source.tier if "tier" in source else -1
	var cursed = source.is_cursed if "is_cursed" in source else false
	
	return "%s_t%d_c%s" % [base, tier, cursed]

func _build_source_cache(player_index: int) -> Array:
	"""Baut Cache für alle möglichen Damage-Sources (ohne Schadenswerte)"""
	var sources = []
	
	# Waffen sammeln
	var weapons = RunData.get_player_weapons(player_index)
	for weapon in weapons:
		if not is_instance_valid(weapon) or not "my_id" in weapon:
			continue
		
		sources.append(weapon)
		
		# Spawned items (Türme, Landminen)
		for spawned in _get_spawned_items_for_weapon(weapon):
			sources.append(spawned)
	
	# Items sammeln
	var items = RunData.get_player_items(player_index)
	for item in items:
		if not is_instance_valid(item) or not "my_id" in item:
			continue
		
		sources.append(item)
		
		# Spawned items von Items (z.B. Taschenfabrik)
		for spawned in _get_spawned_items_for_item(item):
			sources.append(spawned)
	
	return sources

func _collect_grouped_sources(player_index: int) -> Array:
	# Cache nutzen wenn verfügbar
	if _cache_valid[player_index] == 0:
		_source_cache[player_index] = _build_source_cache(player_index)
		_cache_valid[player_index] = 1
	
	# Gruppierung mit aktuellen Schadenswerten
	var groups = {}
	var cached_sources = _source_cache[player_index]
	
	for source in cached_sources:
		if not is_instance_valid(source):
			continue
		
		var dmg = _get_source_damage(source, player_index)
		
		if dmg <= 0:
			continue
		
		var key = _create_group_key(source)
		if not groups.has(key):
			groups[key] = {
				"source": source,
				"damage": 0,
				"group_key": key,
				"count": 0
			}
		
		groups[key].damage += dmg
		groups[key].count += 1
	
	# Dictionary zu Array konvertieren
	var result = []
	result.resize(groups.size())
	var idx = 0
	for group in groups.values():
		result[idx] = group
		idx += 1
	
	return result

func _get_top_sources(player_index: int) -> Array:
	var all_sources = _collect_grouped_sources(player_index)
	all_sources.sort_custom(self, "_cmp_desc_by_damage")
	
	# Optimiert: slice mit fester Größe
	var count = min(all_sources.size(), TOP_K)
	if count == 0:
		return []
	
	var result = []
	result.resize(count)
	for i in range(count):
		result[i] = all_sources[i]
	
	return result

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
	
	# Gesamtschaden berechnen (MUSS immer neu berechnet werden!)
	for i in range(player_count):
		var sources = _collect_grouped_sources(i)
		var total = 0
		for group in sources:
			total += group.damage
		
		totals[i] = total
		if total > max_total:
			max_total = total
	
	# Prozentsätze berechnen (MUSS immer neu berechnet werden!)
	var percentages = PoolRealArray()
	percentages.resize(player_count)
	
	if max_total > 0:
		var max_float = float(max_total)
		for i in range(player_count):
			percentages[i] = (float(totals[i]) / max_float) * 100.0
	else:
		for i in range(player_count):
			percentages[i] = 0.0
	
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
		
		# Balken IMMER aktualisieren (weil prozentual)
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
