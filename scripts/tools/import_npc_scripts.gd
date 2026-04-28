extends SceneTree

## Parses LoY NPC script XMLs and creates NpcScript .tres resources

const SCRIPTS_DIR = "/Users/developer-cloudprimero/Downloads/legends-of-yore-export/data/scripts/"
const OUTPUT_DIR = "res://resources/npcs/scripts/"

func _init():
	_import_all()
	quit()

func _import_all() -> void:
	var dir = DirAccess.open(SCRIPTS_DIR)
	if not dir:
		print("ERROR: Cannot open scripts dir")
		return

	var count = 0
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".xml"):
			var content = FileAccess.get_file_as_string(SCRIPTS_DIR + fname)
			if content != "":
				var res = NpcScriptData.new()
				res.commands = commands
				var out_name = fname.get_basename()
				var err = ResourceSaver.save(res, OUTPUT_DIR + out_name + ".tres")
				if err == OK:
					count += 1
					print("  " + out_name + ": " + str(commands.size()) + " commands")
				else:
					print("  ERROR: " + out_name + " -> " + str(err))
		fname = dir.get_next()

	print("Imported " + str(count) + " NPC scripts")

func _parse_script(content: String) -> Array:
	# Strip <script> wrapper
	var script_start = content.find("<script>")
	var script_end = content.find("</script>")
	if script_start >= 0 and script_end >= 0:
		inner = content.substr(script_start + 8, script_end - script_start - 8)

	return _parse_commands(inner)

func _parse_commands(content: String) -> Array:
	var commands: Array = []

	while pos < content.length():
		while pos < content.length() and content[pos] in [" ", "\t", "\n", "\r"]:
			pos += 1
		if pos >= content.length():
			break
		if content[pos] != "<":
			pos += 1
			continue

		var tag_start = pos
		pos += 1
		if pos >= content.length() or content[pos] == "/":
			var close_end = content.find(">", pos)
			pos = close_end + 1 if close_end >= 0 else pos + 1
			continue

		var tag_name_end = pos
		while tag_name_end < content.length() and content[tag_name_end] not in [" ", ">", "/"]:
			tag_name_end += 1
		var tag_name = content.substr(pos, tag_name_end - pos)

		var tag_end = content.find(">", tag_name_end)
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
					var dialog_close = _find_close(content, tag_end + 1, "showDialog")
					if dialog_close >= 0:
						cmd["options"] = _parse_options(inner)
						pos = dialog_close + 13
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
					var close = _find_close(content, tag_end + 1, tag_name)
					if close >= 0:
						cmd["script"] = _parse_commands(inner)
						pos = close + tag_name.length() + 3
					else:
						pos = tag_end + 1
				else:
					pos = tag_end + 1
				commands.append(cmd)

			"startQuest":
				commands.append({"cmd": "startQuest", "id": _get_attr(full_tag, "id")})
				pos = tag_end + 1
			"completeQuest":
				commands.append({"cmd": "completeQuest"})
				pos = tag_end + 1
			"set":
				commands.append({"cmd": "set", "id": _get_attr(full_tag, "id"), "index": _get_attr(full_tag, "index"), "value": _get_attr(full_tag, "value")})
				pos = tag_end + 1
			"increment":
				commands.append({"cmd": "increment", "index": _get_attr(full_tag, "index")})
				pos = tag_end + 1
			"getItem":
				commands.append({"cmd": "getItem", "name": _get_attr(full_tag, "name"), "count": _get_attr(full_tag, "count")})
				pos = tag_end + 1
			"takeItem":
				commands.append({"cmd": "takeItem", "name": _get_attr(full_tag, "name"), "count": _get_attr(full_tag, "count")})
				pos = tag_end + 1
			"moveToMap":
				commands.append({"cmd": "moveToMap", "map": _get_attr(full_tag, "map"), "x": _get_attr(full_tag, "x"), "y": _get_attr(full_tag, "y")})
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
			var opt_close = _find_close(content, opt_tag_end + 1, "option")
			if opt_close >= 0:
				var inner = content.substr(opt_tag_end + 1, opt_close - opt_tag_end - 1)
				options.append({"name": opt_name, "script": _parse_commands(inner)})
				pos = opt_close + 9
			else:
				options.append({"name": opt_name, "script": []})
				pos = opt_tag_end + 1
	return options

func _find_close(content: String, start: int, tag_name: String) -> int:
	var depth = 1
	var pos = start
	while pos < content.length() and depth > 0:
		var next_open = content.find("<" + tag_name, pos)
		var next_close = content.find("</" + tag_name + ">", pos)
		if next_close < 0:
			return -1
		if next_open >= 0 and next_open < next_close:
			var te = content.find(">", next_open)
			if te >= 0 and content[te - 1] != "/":
				depth += 1
			pos = te + 1 if te >= 0 else next_open + 1
		else:
			depth -= 1
			if depth == 0:
				return next_close
			pos = next_close + tag_name.length() + 3
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
