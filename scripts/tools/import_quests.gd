extends SceneTree

## Parses all LoY quest XML files and creates QuestDefinition .tres resources

const QUESTS_DIR = "/Users/developer-cloudprimero/Downloads/legends-of-yore-export/data/quests/"
const OUTPUT_DIR = "res://resources/quests/"

func _init():
	_import_all()
	quit()

func _import_all() -> void:
	# List of all quest files from quests.xml
	var quest_files = [
		"end", "q1", "q2", "q3", "q4", "q5", "q6", "q7", "q8", "q9", "q10", "q11",
		"a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
		"a8", "a9", "a10", "a11", "a12", "a13", "a14",
		"a15", "a16", "a17", "a18", "a19",
		"a20", "a21", "a23",
		"z1", "z2", "z3", "z4", "z5", "z6", "z7", "z8", "z9", "z10", "z11", "z12",
		"p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p9", "p10",
	]

	var count = 0
	for qf in quest_files:
		var path = QUESTS_DIR + qf + ".xml"
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			print("  SKIP: " + path)
			continue
		var content = file.get_as_text()
		file.close()

		if quest:
			var out_path = OUTPUT_DIR + qf + ".tres"
			var err = ResourceSaver.save(quest, out_path)
			if err == OK:
				count += 1
			else:
				print("  ERROR saving " + out_path + ": " + str(err))

	print("Imported " + str(count) + " quests")

func _parse_quest(content: String, filename: String) -> QuestDefinition:
	var quest = QuestDefinition.new()

	# Parse quest attributes from <quest> tag
	var quest_tag_end = content.find(">")
	if quest_tag_end < 0:
		return null
	var quest_tag = content.substr(0, quest_tag_end + 1)

	quest.id = _get_attr(quest_tag, "id")
	if quest.id == "":
		quest.id = filename
	quest.title = _get_attr(quest_tag, "title")
	quest.summary = _get_attr(quest_tag, "summary")
	quest.level = _get_attr_int(quest_tag, "level", 1)
	quest.location = _get_attr(quest_tag, "location")
	quest.target_location = _get_attr(quest_tag, "targetLocation")

	# Parse properties
	var prop_idx = 0
	while true:
		var prop_start = content.find("<property", prop_idx)
		if prop_start < 0:
			break
		var prop_end = content.find(">", prop_start) + 1
		var prop_tag = content.substr(prop_start, prop_end - prop_start)
		quest.properties.append({
			"name": _get_attr(prop_tag, "name"),
			"type": _get_attr(prop_tag, "type"),
			"index": _get_attr_int(prop_tag, "index", 0),
		})
		prop_idx = prop_end

	# Parse <start> section
	var start_begin = content.find("<start>")
	var start_end = content.find("</start>")
	if start_begin >= 0 and start_end >= 0:
		var start_content = content.substr(start_begin + 7, start_end - start_begin - 7)
		quest.start_script = _parse_commands(start_content)

	# Parse <cancel> section
	var cancel_begin = content.find("<cancel>")
	var cancel_end = content.find("</cancel>")
	if cancel_begin >= 0 and cancel_end >= 0:
		var cancel_content = content.substr(cancel_begin + 8, cancel_end - cancel_begin - 8)
		quest.cancel_script = _parse_commands(cancel_content)

	# Parse <event> sections
	var ev_idx = 0
	while true:
		var ev_start = content.find("<event ", ev_idx)
		if ev_start < 0:
			break
		var ev_tag_end = content.find(">", ev_start)
		var ev_tag = content.substr(ev_start, ev_tag_end - ev_start + 1)
		var ev_type = _get_attr(ev_tag, "type")
		var ev_param = _get_attr(ev_tag, "param")

		# Find matching </event>
		var ev_close = content.find("</event>", ev_tag_end)
		if ev_close < 0:
			break
		var ev_content = content.substr(ev_tag_end + 1, ev_close - ev_tag_end - 1)
		var ev_script = _parse_commands(ev_content)

		quest.events.append({
			"type": ev_type,
			"param": ev_param,
			"script": ev_script,
		})

		ev_idx = ev_close + 8

	return quest

func _parse_commands(content: String) -> Array:
	var commands: Array = []

	while pos < content.length():
		# Skip whitespace
		while pos < content.length() and content[pos] in [" ", "\t", "\n", "\r"]:
			pos += 1
		if pos >= content.length():
			break
		if content[pos] != "<":
			pos += 1
			continue

		# Find tag name
		var tag_start = pos
		pos += 1
		if pos >= content.length() or content[pos] == "/":
			# Closing tag — skip
			var close_end = content.find(">", pos)
			if close_end >= 0:
				pos = close_end + 1
			else:
				pos += 1
			continue

		var tag_name_end = pos
		while tag_name_end < content.length() and content[tag_name_end] not in [" ", ">", "/"]:
			tag_name_end += 1
		var tag_name = content.substr(pos, tag_name_end - pos)

		# Find end of opening tag
		if tag_end < 0:
			break
		var full_tag = content.substr(tag_start, tag_end - tag_start + 1)

		match tag_name:
			"showDialog":
					"cmd": "showDialog",
					"name": _get_attr(full_tag, "name"),
					"portrait": _get_attr_int(full_tag, "portrait", 0),
					"text": _get_attr(full_tag, "text"),
					"options": [],
				}
				if not self_closing:
					# Parse options inside showDialog
					var dialog_close = _find_matching_close(content, tag_end + 1, "showDialog")
					if dialog_close >= 0:
						cmd["options"] = _parse_options(inner)
						pos = dialog_close + 13  # len("</showDialog>")
					else:
						pos = tag_end + 1
				else:
					pos = tag_end + 1
				commands.append(cmd)

			"if", "ifNot":
				var cmd: Dictionary = {
					"cmd": tag_name,
					"attribute": _get_attr(full_tag, "attribute"),
					"compare": _get_attr(full_tag, "compare"),
					"operation": _get_attr(full_tag, "operation"),
					"script": [],
				}
				if not self_closing:
					var if_close = _find_matching_close(content, tag_end + 1, tag_name)
					if if_close >= 0:
						cmd["script"] = _parse_commands(inner)
						pos = if_close + tag_name.length() + 3
					else:
						pos = tag_end + 1
				else:
					pos = tag_end + 1
				commands.append(cmd)

			"startQuest":
				commands.append({
					"cmd": "startQuest",
					"id": _get_attr(full_tag, "id"),
				})
				pos = tag_end + 1

			"completeQuest":
				commands.append({"cmd": "completeQuest"})
				pos = tag_end + 1

			"set":
				commands.append({
					"cmd": "set",
					"id": _get_attr(full_tag, "id"),
					"index": _get_attr(full_tag, "index"),
					"value": _get_attr(full_tag, "value"),
				})
				pos = tag_end + 1

			"increment":
				commands.append({
					"cmd": "increment",
					"index": _get_attr(full_tag, "index"),
				})
				pos = tag_end + 1

			"getItem":
				commands.append({
					"cmd": "getItem",
					"name": _get_attr(full_tag, "name"),
					"count": _get_attr(full_tag, "count"),
				})
				pos = tag_end + 1

			"takeItem":
				commands.append({
					"cmd": "takeItem",
					"name": _get_attr(full_tag, "name"),
					"count": _get_attr(full_tag, "count"),
				})
				pos = tag_end + 1

			"getExp":
				commands.append({
					"cmd": "getExp",
					"value": _get_attr(full_tag, "value"),
				})
				pos = tag_end + 1

			"moveToMap":
				commands.append({
					"cmd": "moveToMap",
					"map": _get_attr(full_tag, "map"),
					"x": _get_attr(full_tag, "x"),
					"y": _get_attr(full_tag, "y"),
				})
				pos = tag_end + 1

			_:
				pos = tag_end + 1

	return commands

func _parse_options(content: String) -> Array:
	var options: Array = []

	while true:
		var opt_start = content.find("<option", pos)
		if opt_start < 0:
			break
		var opt_tag_end = content.find(">", opt_start)
		if opt_tag_end < 0:
			break
		var opt_tag = content.substr(opt_start, opt_tag_end - opt_start + 1)
		var opt_name = _get_attr(opt_tag, "name")
		var self_closing = opt_tag.ends_with("/>")

		if self_closing:
			options.append({"name": opt_name, "script": []})
			pos = opt_tag_end + 1
		else:
			var opt_close = _find_matching_close(content, opt_tag_end + 1, "option")
			if opt_close >= 0:
				var inner = content.substr(opt_tag_end + 1, opt_close - opt_tag_end - 1)
				var sub_script = _parse_commands(inner)
				options.append({"name": opt_name, "script": sub_script})
				pos = opt_close + 9  # len("</option>")
			else:
				options.append({"name": opt_name, "script": []})
				pos = opt_tag_end + 1

	return options

func _find_matching_close(content: String, start: int, tag_name: String) -> int:
	var depth = 1
	var pos = start
	var open_tag = "<" + tag_name
	var close_tag = "</" + tag_name + ">"

	while pos < content.length() and depth > 0:
		var next_open = content.find(open_tag, pos)
		var next_close = content.find(close_tag, pos)

		if next_close < 0:
			return -1

		if next_open >= 0 and next_open < next_close:
			# Check if it's self-closing
			var tag_end = content.find(">", next_open)
			if tag_end >= 0 and content[tag_end - 1] != "/":
				depth += 1
			pos = tag_end + 1 if tag_end >= 0 else next_open + 1
		else:
			depth -= 1
			if depth == 0:
				return next_close
			pos = next_close + close_tag.length()

	return -1

func _get_attr(tag: String, attr_name: String) -> String:
	var search = " " + attr_name + '="'
	var start = tag.find(search)
	if start < 0:
		return ""
	start += search.length()
	var end = tag.find('"', start)
	if end < 0:
		return ""
	return tag.substr(start, end - start)

func _get_attr_int(tag: String, attr_name: String, default_val: int = 0) -> int:
	var val = _get_attr(tag, attr_name)
	if val == "":
		return default_val
	return int(val)
