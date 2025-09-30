extends "res://ui/hud/ui_wave_timer.gd"

const UPDATE_INTERVAL: float = 0.25
const TOP_K: int = 6
const MOD_NAME: String = "DamageMeter"

onready var _hud: Control = get_tree().get_current_scene().get_node("UI/HUD")

var update_timer: Timer = null
var active_displays: Array = []                 
var _player_damage_containers: Array = []       
var wave_start_item_damages: Dictionary = {}    

var _prev_totals: PoolIntArray = PoolIntArray()
var _prev_sigs: Array = []                      
var _all_sources_cache: Array = []

static func _cmp_desc_by_damage(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("damage", 0)) > int(b.get("damage", 0))

static func _sig_for_sources(srcs: Array) -> String:
	var parts: PoolStringArray = PoolStringArray()
	for d in srcs:
		var s: Object = d.get("source", null)
		var dmg: int = int(d.get("damage", 0))
		var sid: String = "-1"
		if is_instance_valid(s) and s.has_method("get_category"):
			sid = str(s.my_id)
		parts.append(sid + ":" + str(dmg))
	return parts.join("|")

static func _insert_topk(topk: Array, entry: Dictionary) -> void:
	var dmg: int = int(entry.get("damage", 0))
	var inserted: bool = false
	for i in range(topk.size()):
		if dmg > int(topk[i].get("damage", 0)):
			topk.insert(i, entry)
			inserted = true
			break
	if not inserted:
		topk.append(entry)
	if topk.size() > TOP_K:
		topk.resize(TOP_K)

func _ready() -> void:
	var player_count: int = RunData.get_player_count()
	_player_damage_containers.clear()
	for i in range(4):
		var idx_str: String = str(i + 1)
		var path: String = "LifeContainerP%s/PlayerDamageContainerP%s" % [idx_str, idx_str]
		var container: Object = _hud.get_node_or_null(path)
		_player_damage_containers.append(container)
		if not is_instance_valid(container):
			push_warning("%s: Container für Spieler %s nicht gefunden" % [MOD_NAME, idx_str])
	active_displays.clear()
	for i in range(player_count):
		var dn: Object = _player_damage_containers[i] if i < _player_damage_containers.size() else null
		if is_instance_valid(dn):
			active_displays.append(dn)
	wave_start_item_damages.clear()
	for i in range(player_count):
		wave_start_item_damages[i] = {}
		if RunData.tracked_item_effects.size() > i:
			for item in RunData.get_player_items(i):
				if is_instance_valid(item) and "tracking_text" in item and item.tracking_text == "DAMAGE_DEALT":
					wave_start_item_damages[i][item.my_id] = int(RunData.tracked_item_effects[i].get(item.my_id, 0))
	_prev_totals.resize(player_count)
	_prev_sigs.resize(player_count)
	for i in range(player_count):
		_prev_totals[i] = -1
		_prev_sigs[i] = ""
	_all_sources_cache.resize(player_count)
	update_timer = Timer.new()
	update_timer.one_shot = false
	update_timer.wait_time = UPDATE_INTERVAL
	update_timer.connect("timeout", self, "update_damage_bars")
	add_child(update_timer)
	update_timer.start()

func get_damage_for_source(source: Object, player_index: int) -> int:
	if not is_instance_valid(source):
		return 0
	if source.has_method("get_category") and source.get_category() == Category.WEAPON:
		return int(source.dmg_dealt_last_wave)
	if "tracking_text" in source and source.tracking_text == "DAMAGE_DEALT":
		var start_map: Dictionary = wave_start_item_damages.get(player_index, {})
		var start_val: int = int(start_map.get(source.my_id, 0))
		var cur_val: int = 0
		if RunData.tracked_item_effects.size() > player_index:
			var pmap: Dictionary = RunData.tracked_item_effects[player_index]
			cur_val = int(pmap.get(source.my_id, 0))
		var diff_float: float = cur_val - start_val
		var diff: int = int(max(0, floor(diff_float)))

		return diff
	return 0

func update_damage_bars() -> void:
	var wave_active: bool = is_instance_valid(wave_timer) and wave_timer.time_left > 0.0
	if not wave_active:
		for d in active_displays:
			if is_instance_valid(d):
				d.visible = false
		return
	var player_count: int = RunData.get_player_count()
	for i in range(4):
		var node: Object = _player_damage_containers[i] if i < _player_damage_containers.size() else null
		if is_instance_valid(node):
			node.visible = i < player_count
	for i in range(player_count):
		_all_sources_cache[i] = RunData.get_player_weapons(i) + RunData.get_player_items(i)
	var totals: PoolIntArray = PoolIntArray()
	totals.resize(player_count)
	var max_total: int = 0
	for i in range(player_count):
		var sum_i: int = 0
		for s in _all_sources_cache[i]:
			sum_i += get_damage_for_source(s, i)
		totals[i] = sum_i
		if sum_i > max_total:
			max_total = sum_i
	for i in range(player_count):
		if active_displays.size() <= i or not is_instance_valid(active_displays[i]):
			continue
		var display: Object = active_displays[i]
		var total: int = int(totals[i])
		if _prev_totals[i] == total:
			continue
		var topk: Array = []
		for s in _all_sources_cache[i]:
			var dmg: int = get_damage_for_source(s, i)
			if dmg > 0:
				_insert_topk(topk, {"source": s, "damage": dmg})
		if topk.size() > 1:
			topk.sort_custom(self, "_cmp_desc_by_damage")
		var is_top_player: bool = (player_count > 1 and total == max_total and total > 0)
		var icon: Texture = null
		var character_obj: Object = RunData.get_player_character(i)
		if is_instance_valid(character_obj):
			icon = character_obj.icon
		var sig: String = _sig_for_sources(topk)
		var needs_update: bool = (_prev_sigs[i] != sig)
		if needs_update:
			display.update_total_damage(total, max_total, is_top_player, player_count == 1, icon, i)
			display.update_source_list(topk, i)
			_prev_totals[i] = total
			_prev_sigs[i] = sig
