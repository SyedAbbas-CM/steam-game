@tool
extends EditorScript

## Import LoY dungeon level definitions from levels.xml → DungeonLevelData .tres files

func _run() -> void:
	var source = "res://../../Downloads/legends-of-yore-export/data/levels/levels.xml"
	var file = FileAccess.open(source, FileAccess.READ)
	if not file:
		print("ERROR: Cannot open " + source)
		return

	var xml = file.get_as_text()
	file.close()

	var out_dir = "res://resources/levels/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var count = 0
	var pos = 0
	while true:
		var level_start = xml.find("<level ", pos)
		if level_start < 0:
			break

		# Find matching </level> or self-closing />
		var close_tag = xml.find("</level>", level_start)
		var self_close = xml.find("/>", level_start)

		var level_end: int
		if close_tag >= 0 and (self_close < 0 or close_tag < self_close):
			level_end = close_tag + 8
		elif self_close >= 0:
			# Make sure this /> belongs to the level tag, not a child
			var first_gt = xml.find(">", level_start)
			if first_gt >= 0 and first_gt < self_close:
				# There was a > before />, so this level has children
				level_end = xml.find("</level>", level_start)
				if level_end < 0:
					break
				level_end += 8
			else:
				level_end = self_close + 2
		else:
			break

		var block = xml.substr(level_start, level_end - level_start)
		var level = _parse_level(block)
		if level and level.id != "":
			var safe_name = level.id.to_lower().replace(" ", "_").replace("-", "_")
			ResourceSaver.save(level, out_dir + safe_name + ".tres")
			count += 1

		pos = level_end

	print("Imported " + str(count) + " dungeon levels")

func _parse_level(block: String) -> DungeonLevelData:
	var level = DungeonLevelData.new()

	var tag_end = block.find(">")
	var tag = block.substr(0, tag_end + 1) if tag_end >= 0 else block

	level.id = _get_attr(tag, "id")
	level.tileset = int(_get_attr(tag, "tileset"))
	level.chests = int(_get_attr(tag, "chests"))
	level.width = int(_get_attr(tag, "width")) if _get_attr(tag, "width") != "" else 50
	level.height = int(_get_attr(tag, "height")) if _get_attr(tag, "height") != "" else 35
	level.rooms = int(_get_attr(tag, "rooms")) if _get_attr(tag, "rooms") != "" else 25
	level.min_monsters = int(_get_attr(tag, "minMonsters"))
	level.max_monsters = int(_get_attr(tag, "maxMonsters")) if _get_attr(tag, "maxMonsters") != "" else 2
	level.aggro_chance = int(_get_attr(tag, "aggroChance"))
	level.requires_key = _get_attr(tag, "key") == "true"
	level.legend = _get_attr(tag, "legend")

	# Parse monsterChance entries
	var monster_pool: Array = []
	var mpos = 0
	while true:
		var mi = block.find("<monsterChance", mpos)
		if mi < 0:
			break
		var me = block.find("/>", mi)
		if me < 0:
			break
		var mtag = block.substr(mi, me - mi + 2)
		var mtype = _get_attr(mtag, "type")
		var mchance = int(_get_attr(mtag, "chance")) if _get_attr(mtag, "chance") != "" else 1
		if mtype != "" and mtype != "none":
			monster_pool.append({"type": mtype, "chance": mchance})
		mpos = me + 2
	level.monster_pool = monster_pool

	# Parse fixed monster entries
	var fixed: Array = []
	var fpos = 0
	while true:
		var fi = block.find("<monster ", fpos)
		if fi < 0:
			break
		var fe = block.find("/>", fi)
		if fe < 0:
			break
		var ftag = block.substr(fi, fe - fi + 2)
		var ftype = _get_attr(ftag, "type")
		var fcount = int(_get_attr(ftag, "count")) if _get_attr(ftag, "count") != "" else 1
		if ftype != "":
			fixed.append({"type": ftype, "count": fcount})
		fpos = fe + 2
	level.fixed_monsters = fixed

	# Parse chest loot tables
	var chests: Array = []
	var cpos = 0
	while true:
		var ci = block.find("<chest ", cpos)
		if ci < 0:
			break
		var ce = block.find("</chest>", ci)
		if ce < 0:
			break
		var cblock = block.substr(ci, ce - ci + 8)
		var ctag_end = cblock.find(">")
		var ctag = cblock.substr(0, ctag_end + 1)

		var chest_data = {
			"min_items": int(_get_attr(ctag, "minItems")) if _get_attr(ctag, "minItems") != "" else 1,
			"max_items": int(_get_attr(ctag, "maxItems")) if _get_attr(ctag, "maxItems") != "" else 1,
			"trap_chance": int(_get_attr(ctag, "trapChance")),
			"items": [] as Array
		}

		# Parse itemChance entries
		var ipos = 0
		while true:
			var ii = cblock.find("<itemChance", ipos)
			if ii < 0:
				break
			var ie = cblock.find("/>", ii)
			if ie < 0:
				break
			var itag = cblock.substr(ii, ie - ii + 2)
			var item = {
				"name": _get_attr(itag, "name"),
				"chance": int(_get_attr(itag, "chance")) if _get_attr(itag, "chance") != "" else 1,
				"min": int(_get_attr(itag, "min")) if _get_attr(itag, "min") != "" else 1,
				"max": int(_get_attr(itag, "max")) if _get_attr(itag, "max") != "" else 1,
			}
			chest_data["items"].append(item)
			ipos = ie + 2

		chests.append(chest_data)
		cpos = ce + 8
	level.chest_loot = chests
	return level

func _get_attr(tag: String, attr_name: String) -> String:
	var search = " " + attr_name + '="'
	var start = tag.find(search)
	if start < 0:
		search = '\t' + attr_name + '="'
		start = tag.find(search)
	if start < 0:
		return ""
	start += search.length()
	var end = tag.find('"', start)
	if end < 0:
		return ""
	return tag.substr(start, end - start)
