@tool
extends SceneTree

## Headless tool: generates mq01–mq20 quest .tres files for "The Hollow Tide" main quest chain.
## Run: godot --headless --script scripts/tools/generate_quest_chain.gd

const OUT_DIR = "res://resources/quests/"

func _init() -> void:
	print("=== Generating The Hollow Tide quest chain ===")
	for q in quests:
		_save_quest(q)
	print("Done — %d quests written to %s" % [quests.size(), OUT_DIR])
	quit()

func _save_quest(q: Dictionary) -> void:
	var path = OUT_DIR + q.id + ".tres"

	var lines: Array[String] = []
	lines.append('[gd_resource type="Resource" script_class="QuestDefinition" load_steps=2 format=3]')
	lines.append('')
	lines.append('[ext_resource type="Script" path="res://scripts/quests/quest_definition.gd" id="1_gen"]')
	lines.append('')
	lines.append('[resource]')
	lines.append('script = ExtResource("1_gen")')
	lines.append('id = "%s"' % q.id)
	lines.append('title = "%s"' % q.title.replace('"', '\\"'))
	if q.has("summary"):
		lines.append('summary = "%s"' % q.summary.replace('"', '\\"'))
	lines.append('level = %d' % q.level)
	lines.append('location = "%s"' % q.location)
	if q.get("target_location", "") != "":
		lines.append('target_location = "%s"' % q.target_location)
	if q.get("prerequisite", "") != "":
		lines.append('prerequisite = "%s"' % q.prerequisite)
	if q.get("prerequisite_list", []).size() > 0:
		var pl = ', '.join(q.prerequisite_list.map(func(s): return '"%s"' % s))
		lines.append('prerequisite_list = Array[String]([%s])' % pl)
	if q.get("boss_dungeon", "") != "":
		lines.append('boss_dungeon = "%s"' % q.boss_dungeon)
	if q.get("boss_enemy_path", "") != "":
		lines.append('boss_enemy_path = "%s"' % q.boss_enemy_path)
	if q.get("properties", []).size() > 0:
		lines.append('properties = %s' % var_to_str(q.properties))
	lines.append('start_script = %s' % var_to_str(q.start_script))
	if q.get("cancel_script", []).size() > 0:
		lines.append('cancel_script = %s' % var_to_str(q.cancel_script))
	lines.append('events = %s' % var_to_str(q.events))

	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		print("ERROR: Cannot write %s" % path)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("  Wrote %s" % path)

# --- Helper: dialogue command ---
func _dlg(name: String, portrait: int, text: String, options: Array = []) -> Dictionary:
	if options.size() == 0:
		options = [{"name": "Continue", "script": []}]
	return {"cmd": "showDialog", "name": name, "portrait": portrait, "text": text, "options": options}

func _opt(label: String, script: Array = []) -> Dictionary:
	return {"name": label, "script": script}

func _start_q(id: String = "") -> Dictionary:
	if id != "":
		d["id"] = id
	return d

func _complete_q(id: String = "") -> Dictionary:
	var d: Dictionary = {"cmd": "completeQuest"}
	if id != "":
		d["id"] = id
	return d

func _inc(idx: int = 0) -> Dictionary:
	return {"cmd": "increment", "index": str(idx)}

func _get_exp(value: int) -> Dictionary:
	return {"cmd": "getExp", "value": str(value)}

func _get_gold(amount: int) -> Dictionary:
	return {"cmd": "getItem", "name": "Gold", "count": str(amount)}

func _get_item(name: String, count: int = 1) -> Dictionary:
	return {"cmd": "getItem", "name": name, "count": str(count)}

func _set_val(qid: String, idx: int, val: int) -> Dictionary:
	return {"cmd": "set", "id": qid, "index": str(idx), "value": str(val)}

func _if_val(attr: String, compare: int, op: String, script: Array) -> Dictionary:
	return {"cmd": "if", "attribute": attr, "compare": str(compare), "operation": op, "script": script}

func _if_not(attr: String, compare: int, op: String, script: Array) -> Dictionary:
	return {"cmd": "ifNot", "attribute": attr, "compare": str(compare), "operation": op, "script": script}

# =========================================================================
func _build_quests() -> Array:
	var quests: Array = []

	# -------------------------------------------------------------------
	# MQ01 — Waking in Ash
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq01",
		"title": "Waking in Ash",
		"summary": "The healer says the brand on your arm matches symbols found on dead livestock at the farm. Travel there to investigate.",
		"level": 1,
		"location": "haven",
		"target_location": "duskfarm",
		"start_script": [
			_dlg("Healer Maren", 160, "You're awake. Don't move too fast — whatever marked you nearly killed you.", [
				_opt("What happened to me?", [
					_dlg("Healer Maren", 160, "Found you face-down in the ash outside town. That brand on your arm... I've seen those symbols before. On the dead livestock at the farm south of here.", [
						_opt("I'll go look.", [_start_q()]),
						_opt("Not my problem.", [])
					])
				])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "duskfarm",
				"script": [
					_dlg("", 0, "The stench hits you before you see it. Cattle lie twisted in the dirt, their hides branded with the same symbol that burns on your arm. Black ichor seeps from the marks into the soil.", [
						_opt("Examine the ichor", [
							_dlg("", 0, "The ichor leads toward the dungeon entrance at the edge of the farm. Something down there is the source.", [
								_opt("Continue", [_get_exp(100), _complete_q()])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ02 — What the Dead Left Behind
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq02",
		"title": "What the Dead Left Behind",
		"summary": "Follow the ichor into the dungeon beneath the farm. Kill blighted creatures and find the carved tablet on the boss floor.",
		"level": 2,
		"location": "haven",
		"target_location": "haven",
		"prerequisite": "mq01",
		"properties": [{"name": "Blighted Killed", "type": "number", "index": 0}],
		"start_script": [
			_dlg("Healer Maren", 160, "You found the source? The ichor leads underground. Whatever's down there, it's spreading.", [
				_opt("I'll clear it out.", [
					_dlg("Healer Maren", 160, "Kill whatever blighted creatures you find. And look for anything that explains what's causing this. A tablet, markings — anything.", [
						_opt("Understood.", [_start_q()])
					])
				])
			])
		],
		"events": [
			{
				"type": "kill",
				"param": "Skeleton",
				"script": [_inc(0)]
			},
			{
				"type": "kill",
				"param": "Zombie",
				"script": [_inc(0)]
			},
			{
				"type": "boss_killed",
				"param": "haven",
				"script": [
					_dlg("", 0, "Among the remains you find a stone tablet covered in the same symbols as your brand. The carvings show coordinates — directions to something deeper.", [
						_opt("Take the tablet", [_set_val("mq02", 1, 1)])
					])
				]
			},
			{
				"type": "quest",
				"param": "haven",
				"script": [
					_if_val("session-mq02-1", 0, "gt", [
						_dlg("Healer Maren", 160, "Let me see... these coordinates point somewhere west. Take this to the Elder — he reads the old language.", [
							_opt("Thanks.", [_get_exp(300), _get_gold(200), _complete_q()])
						])
					]),
					_if_val("session-mq02-1", 1, "lt", [
						_dlg("Healer Maren", 160, "Still hunting down there? Be careful. And find that tablet.", [
							_opt("I will.", [])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ03 — The Elder's Silence
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq03",
		"title": "The Elder's Silence",
		"summary": "The Elder refuses to help. A scholar offers to translate the tablet — but needs her stolen journal from the wilds.",
		"level": 3,
		"location": "haven",
		"target_location": "wastes",
		"prerequisite": "mq02",
		"start_script": [
			_dlg("Elder", 147, "I know what that tablet says. And I wish I didn't. Leave it alone.", [
				_opt("People are dying.", [
					_dlg("Elder", 147, "Then let them die quietly. You don't know what you're waking up.", [
						_opt("Fine. Someone else will help.", [
							_dlg("Scholar Vela", 162, "The Elder won't talk? Coward. I can translate it — but bandits stole my journal in the wilds to the north. Bring it back and I'll read your tablet.", [
								_opt("Deal.", [_start_q()])
							])
						])
					])
				])
			])
		],
		"events": [
			{
				"type": "kill",
				"param": "Bandit",
				"script": [
					_if_val("session-mq03-0", 1, "lt", [
						_dlg("", 0, "A battered journal falls from the bandit's pack. This must be Vela's.", [
							_opt("Take it", [_set_val("mq03", 0, 1)])
						])
					])
				]
			},
			{
				"type": "quest",
				"param": "haven",
				"script": [
					_if_val("session-mq03-0", 0, "gt", [
						_dlg("Scholar Vela", 162, "My journal! Now let me see that tablet... The coordinates point to the old seal beneath Thule. But there are intermediate markers — in the valley, the mountains, the frozen north. Something is breaking the seals.", [
							_opt("What seals?", [
								_dlg("Scholar Vela", 162, "Ancient bindings that kept something locked beneath the earth. If they're breaking... you need to move fast. Head to the wilds — reports of something wrong there.", [
									_opt("On my way.", [_get_exp(400), _complete_q()])
								])
							])
						])
					]),
					_if_val("session-mq03-0", 1, "lt", [
						_dlg("Scholar Vela", 162, "Find my journal in the wilds to the north. Bandits took it.", [
							_opt("I'm looking.", [])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ04 — Blood in the Grass
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq04",
		"title": "Blood in the Grass",
		"summary": "Your mark burns in the wilds. A destroyed caravan — survivors saw black-robed figures heading south.",
		"level": 5,
		"location": "haven",
		"target_location": "wastes",
		"prerequisite": "mq03",
		"start_script": [
			_dlg("Scholar Vela", 162, "Travelers coming from the wilds speak of a destroyed caravan. Your mark may react to the corruption there. Go see what happened.", [
				_opt("I'll investigate.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "wastes",
				"script": [
					_dlg("", 0, "Your arm erupts in pain. The brand glows with sickly light. Ahead, an overturned caravan. Bodies. A survivor crawls toward you.", [
						_opt("Help them", [
							_dlg("Wounded Trader", 0, "Black robes... they came from nowhere. Took nothing. Just... touched people. And they stopped moving. Headed south... toward the valley...", [
								_opt("South. The valley.", [_get_exp(300), _complete_q()])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ05 — The Hollow Shepherd
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq05",
		"title": "The Hollow Shepherd",
		"summary": "A silent village — residents stand motionless, eyes black. The Hollow Shepherd commands them. Pursue into the dungeon.",
		"level": 7,
		"location": "wastes",
		"target_location": "mirage",
		"prerequisite": "mq04",
		"boss_dungeon": "mirage",
		"boss_enemy_path": "res://resources/enemies/quest/hollow_shepherd.tres",
		"start_script": [
			_dlg("", 0, "The valley village is silent. People stand in the streets, unmoving. Their eyes are black — empty. A cowled figure watches from the dungeon entrance.", [
				_opt("Pursue the figure", [_start_q()])
			])
		],
		"events": [
			{
				"type": "boss_killed",
				"param": "Hollow Shepherd",
				"script": [
					_dlg("", 0, "The Shepherd crumbles. In its robes you find a sealed letter addressed to 'The Warden of Heim.' The villagers begin to stir — confused, terrified, alive.", [
						_opt("Read the letter", [
							_dlg("", 0, "The letter speaks of 'the Tide rising on schedule' and 'the second seal already weakened.' It's signed with your brand symbol.", [
								_opt("Take the letter to Heim.", [_get_exp(800), _complete_q()])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ06 — The Warden's Warning
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq06",
		"title": "The Warden's Warning",
		"summary": "Deliver the Shepherd's letter to the Warden in Heim. Learn the truth about the Tide and receive Key Fragment 1/3.",
		"level": 8,
		"location": "mirage",
		"target_location": "ashheim",
		"prerequisite": "mq05",
		"start_script": [
			_dlg("", 0, "The letter must reach the Warden of Heim. He'll know what the Hollow Shepherd was planning.", [
				_opt("Travel to Heim.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "ashheim",
				"script": [
					_dlg("Warden Aldric", 148, "That letter... I'd hoped we had more time. The Hollow Tide — it happened before, centuries ago. An ancient king broke the seals seeking immortality. We bound him beneath Thule.", [
						_opt("The seals are breaking.", [
							_dlg("Warden Aldric", 148, "Three fragments of the Seal Key were hidden across the land. Take this one. Find the others before the Tide consumes everything. The frozen north and the southern coast hold the rest.", [
								_opt("I won't fail.", [_get_exp(600), _get_item("Key Fragment", 1), _complete_q()])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ07 — Frozen Witnesses
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq07",
		"title": "Frozen Witnesses",
		"summary": "A patrol frozen in black ice in the cold wastes. Their journal describes a 'woman in white.'",
		"level": 10,
		"location": "ashheim",
		"target_location": "frostpass",
		"prerequisite": "mq06",
		"start_script": [
			_dlg("Warden Aldric", 148, "The northern fragment was guarded by a priestess in the frozen temple. But we've lost contact. Scouts sent north haven't returned.", [
				_opt("I'll find them.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "frostpass",
				"script": [
					_dlg("", 0, "Soldiers frozen mid-stride in columns of black ice. Their faces are locked in terror. A journal lies at one's feet.", [
						_opt("Read the journal", [
							_dlg("", 0, "'Day 4 — The priestess has changed. Her eyes are white now. She speaks in a voice that isn't hers. We tried to leave. She wouldn't let us.' The entries end there.", [
								_opt("The priestess is corrupted.", [_get_exp(400), _complete_q()])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ08 — The Witch of Nord (DECISION QUEST)
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq08",
		"title": "The Witch of Nord",
		"summary": "Confront the corrupted priestess in the frozen dungeon. Choose: spare her or strike her down.",
		"level": 12,
		"location": "frostpass",
		"target_location": "frostpass",
		"prerequisite": "mq07",
		"boss_dungeon": "nord",
		"boss_enemy_path": "res://resources/enemies/quest/corrupted_priestess.tres",
		"start_script": [
			_dlg("", 0, "The frozen temple entrance looms ahead. Whatever the priestess has become, she holds the second fragment. Steel yourself.", [
				_opt("Enter the temple.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "boss_killed",
				"param": "Corrupted Priestess",
				"script": [
					_dlg("", 0, "The priestess collapses. The corruption recedes from her eyes — for a moment, she's herself again. 'Please...' she whispers. 'It wasn't me. The Tide... it speaks through the seals.'", [
						_opt("Spare her", [
							_set_val("mq08", 0, 1),
							_dlg("Priestess Yara", 288, "Thank you... Take the fragment. And know this: the one who broke the seals — he's not just imprisoned. He's awake. He's been calling to his servants for years.", [
								_opt("I'll stop him.", [_get_exp(1200), _get_item("Key Fragment", 1), _complete_q()])
							])
						]),
						_opt("Strike her down", [
							_set_val("mq08", 0, 2),
							_dlg("", 0, "You end it cleanly. The fragment falls from her hand, cold as the ice around you. Whatever warning she had dies with her.", [
								_opt("Take the fragment.", [_get_exp(1200), _get_item("Key Fragment", 1), _complete_q()])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ09 — A Ship That Shouldn't Sail
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq09",
		"title": "A Ship That Shouldn't Sail",
		"summary": "A ghost ship at Gomb harbor. The harbor master denies it. A fisherman points to a hidden cove.",
		"level": 12,
		"location": "ashheim",
		"target_location": "cliffs",
		"prerequisite": "mq06",
		"start_script": [
			_dlg("Warden Aldric", 148, "The third fragment was sent south by sea. But sailors report a ghost ship at Gomb — flying no colors. The harbor master claims nothing's wrong. Investigate.", [
				_opt("I'll check Gomb.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "briarvale",
				"script": [
					_dlg("Harbor Master", 155, "Ghost ship? Nonsense. Just fog playing tricks. Nothing to see here.", [
						_opt("Ask around", [
							_dlg("Old Fisherman", 0, "He's lying. I saw crates unloaded at night — marked with a strange brand. They took them to the bluffs south of here. Hidden cove.", [
								_opt("The bluffs.", [])
							])
						])
					])
				]
			},
			{
				"type": "zone_enter",
				"param": "cliffs",
				"script": [
					_dlg("", 0, "Hidden among the rocks: stacks of crates, each branded with your symbol. Shipping manifests list a destination — Tor'Kaan, the pirate city to the east.", [
						_opt("Follow the trail.", [_get_exp(500), _complete_q()])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ10 — The Merchant's Deal (DECISION QUEST)
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq10",
		"title": "The Merchant's Deal",
		"summary": "Follow the crates to the pirate city. The guild master spreads Tide artifacts for power. Join or fight.",
		"level": 14,
		"location": "cliffs",
		"target_location": "saltmere",
		"prerequisite": "mq09",
		"properties": [{"name": "Informants Found", "type": "number", "index": 0}],
		"start_script": [
			_dlg("", 0, "The crates lead east to the pirate city. Someone there is distributing Tide artifacts for profit.", [
				_opt("Head to Tor'Kaan.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "activate",
				"param": "Dock Worker",
				"script": [
					_if_val("session-mq10-0", 3, "lt", [
						_dlg("Dock Worker", 0, "The crates? Guild Master Renzo. He pays well for silence. His warehouse is by the east dock.", [
							_opt("Thanks.", [_inc(0)])
						])
					])
				]
			},
			{
				"type": "activate",
				"param": "Tavern Keeper",
				"script": [
					_if_val("session-mq10-0", 3, "lt", [
						_dlg("Tavern Keeper", 0, "Renzo's been buying strange artifacts from ships no one recognizes. Sells them to anyone with coin. People who buy them... change.", [
							_opt("Change how?", [
								_dlg("Tavern Keeper", 0, "Quiet. Obedient. Like those villagers you hear about up north.", [
									_opt("Got it.", [_inc(0)])
								])
							])
						])
					])
				]
			},
			{
				"type": "activate",
				"param": "Smuggler",
				"script": [
					_if_val("session-mq10-0", 3, "lt", [
						_dlg("Smuggler", 0, "Renzo doesn't know what he's selling. Or maybe he does and doesn't care. Either way, he's got something in his vault — glows like your arm does.", [
							_opt("The fragment.", [_inc(0)])
						])
					])
				]
			},
			{
				"type": "quest",
				"param": "saltmere",
				"script": [
					_if_val("session-mq10-0", 2, "gt", [
						_dlg("Guild Master Renzo", 0, "So you've been asking questions. I know what you want. I'll give it to you — for a price. Join me. The Tide is coming regardless. Might as well profit.", [
							_opt("Never.", [
								_set_val("mq10", 1, 2),
								_dlg("Guild Master Renzo", 0, "Then you'll take it from my cold hands.", [
									_opt("So be it.", [_get_exp(1000), _get_item("Key Fragment", 1), _complete_q()])
								])
							]),
							_opt("What's your offer?", [
								_set_val("mq10", 1, 1),
								_dlg("Guild Master Renzo", 0, "Smart. Take the fragment — and 2000 gold. All I ask is you forget what you saw here.", [
									_opt("Deal.", [_get_exp(600), _get_gold(2000), _get_item("Key Fragment", 1), _complete_q()])
								])
							])
						])
					]),
					_if_val("session-mq10-0", 3, "lt", [
						_dlg("", 0, "You need to find informants in the city. Ask around the docks, tavern, and back alleys.", [
							_opt("Keep looking.", [])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ11 — The Gathering
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq11",
		"title": "The Gathering",
		"summary": "Bring the 3 fragments to the Sage in Cennyn. She needs 3 elders to perform the binding ritual.",
		"level": 14,
		"location": "cenneth",
		"target_location": "cenneth",
		"prerequisite_list": ["mq08", "mq10"],
		"properties": [{"name": "Elders Gathered", "type": "number", "index": 0}],
		"start_script": [
			_dlg("Sage Elowen", 163, "Three fragments... yes. But I cannot bind them alone. I need the three elders: Kor the Ironbound, Talmita the Sun Speaker, and the Guardian of Paititi.", [
				_opt("What do they need?", [
					_dlg("Sage Elowen", 163, "Kor needs proof the Tide is real — show him your brand. Talmita needs her Sun Disc recovered from the Peaks. And Paititi's shrine must be cleansed of corruption.", [
						_opt("I'll gather them.", [_start_q()])
					])
				])
			])
		],
		"events": [
			{
				"type": "activate",
				"param": "Elder Kor",
				"script": [
					_if_val("session-mq11-0", 3, "lt", [
						_dlg("Elder Kor", 150, "The Hollow Tide? Stories to frighten children. Show me proof.", [
							_opt("Show the brand", [
								_dlg("Elder Kor", 150, "...By the old gods. That's the Seal Mark. I'll come. Tell Elowen I'm ready.", [
									_opt("Thank you.", [_inc(0)])
								])
							])
						])
					])
				]
			},
			{
				"type": "quest",
				"param": "cenneth",
				"script": [
					_if_val("session-mq11-0", 2, "gt", [
						_dlg("Sage Elowen", 163, "All three are here. The binding ritual will take time. But first — the shrine in Paititi and the relic in the Peaks must be secured. Go.", [
							_opt("On my way.", [_get_exp(800), _complete_q()])
						])
					]),
					_if_val("session-mq11-0", 3, "lt", [
						_dlg("Sage Elowen", 163, "We still need more elders. Keep searching.", [
							_opt("I will.", [])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ12 — The Shrine of Thorns
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq12",
		"title": "The Shrine of Thorns",
		"summary": "Clear the corrupted shrine in Paititi's jungle dungeon. Kill the Tide-corrupted treant.",
		"level": 15,
		"location": "cenneth",
		"target_location": "feverjungle",
		"prerequisite": "mq11",
		"start_script": [
			_dlg("Sage Elowen", 163, "The shrine in the jungle has been consumed by corruption. A great tree guardian turned against its purpose. Destroy it and cleanse the shrine.", [
				_opt("I'll handle it.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "boss_killed",
				"param": "feverjungle",
				"script": [
					_dlg("", 0, "The corrupted treant falls, and the black vines recede. Light returns to the shrine. The Guardian of Paititi appears from the shadows.", [
						_opt("It's done.", [
							_dlg("Guardian of Paititi", 0, "The shrine breathes again. I will join the ritual. Tell Elowen the jungle stands with her.", [
								_opt("Thank you.", [_get_exp(1000), _inc(0), _complete_q()])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ13 — The Relic of Talmita
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq13",
		"title": "The Relic of Talmita",
		"summary": "Retrieve the Sun Disc from the Peaks dungeon. Bandits consumed by the Tide guard it.",
		"level": 16,
		"location": "cenneth",
		"target_location": "stormcrag",
		"prerequisite": "mq11",
		"start_script": [
			_dlg("Sage Elowen", 163, "Talmita's Sun Disc was stolen and taken to the mountain peaks. The thieves who took it are likely already lost to the Tide. Retrieve it.", [
				_opt("Consider it done.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "boss_killed",
				"param": "stormcrag",
				"script": [
					_dlg("", 0, "The hollowed bandits collapse. Among their hoard, the Sun Disc gleams — untouched by corruption. Talmita will be pleased.", [
						_opt("Take the Sun Disc", [
							_set_val("mq13", 0, 1)
						])
					])
				]
			},
			{
				"type": "quest",
				"param": "cenneth",
				"script": [
					_if_val("session-mq13-0", 0, "gt", [
						_dlg("Talmita", 0, "The Sun Disc... I can feel its warmth again. You have my gratitude and my presence at the ritual.", [
							_opt("We'll need it.", [_get_exp(1000), _complete_q()])
						])
					]),
					_if_val("session-mq13-0", 1, "lt", [
						_dlg("Sage Elowen", 163, "The Sun Disc is in the peaks. Clear the dungeon there.", [
							_opt("On my way.", [])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ14 — The Road to Thule
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq14",
		"title": "The Road to Thule",
		"summary": "The corruption thickens. The vale village is hollowed. The frozen ground bleeds ichor.",
		"level": 18,
		"location": "cenneth",
		"target_location": "frostgrave",
		"prerequisite_list": ["mq12", "mq13"],
		"start_script": [
			_dlg("Sage Elowen", 163, "The ritual is prepared. But the Seal Key must be brought to Thule itself — to the chamber beneath the city. The road north is dangerous. The Tide grows stronger the closer you get.", [
				_opt("I'll cut through.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "frostgrave",
				"script": [
					_dlg("", 0, "The ground bleeds black. Villages along the road stand empty — not destroyed, just... vacant. The people aren't dead. They're hollowed. Husks that breathe but don't live. Thule is close.", [
						_opt("Press on.", [_get_exp(600), _complete_q()])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ15 — The Last Garrison
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq15",
		"title": "The Last Garrison",
		"summary": "Thule's garrison is under siege. Kill 15 Tide creatures. The commander will open the catacomb gate.",
		"level": 19,
		"location": "frostgrave",
		"target_location": "thule",
		"prerequisite": "mq14",
		"properties": [{"name": "Tide Creatures Killed", "type": "number", "index": 0}],
		"start_script": [
			_dlg("", 0, "Thule's walls still hold — barely. The garrison fights a losing battle against waves of Tide creatures. Help them, and they may open the catacombs beneath the city.", [
				_opt("For Thule.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "kill",
				"param": "Zombie",
				"script": [_inc(0)]
			},
			{
				"type": "kill",
				"param": "Skeleton",
				"script": [_inc(0)]
			},
			{
				"type": "kill",
				"param": "Spectre",
				"script": [_inc(0)]
			},
			{
				"type": "quest",
				"param": "thule",
				"script": [
					_if_val("session-mq15-0", 14, "gt", [
						_dlg("Commander Rhis", 149, "You've done more than any soldier could. The catacombs are open. Whatever's down there... end it.", [
							_opt("I intend to.", [_get_exp(1000), _complete_q()])
						])
					]),
					_if_val("session-mq15-0", 15, "lt", [
						_dlg("Commander Rhis", 149, "The creatures keep coming. We need more of them put down before I can spare the men to open the gate.", [
							_opt("I'll keep fighting.", [])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ16 — The Catacombs
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq16",
		"title": "The Catacombs",
		"summary": "Descend into Thule's catacombs. Ancient lore reveals the old kingdom. Kill the Tide Guardian construct.",
		"level": 20,
		"location": "thule",
		"target_location": "thule",
		"prerequisite": "mq15",
		"start_script": [
			_dlg("Commander Rhis", 149, "The gate is open. The catacombs go deep — older than Thule itself. Our scouts never came back. Whatever guards the path to the seal chamber, it won't let you pass easily.", [
				_opt("Then I'll make it.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "boss_killed",
				"param": "thule",
				"script": [
					_dlg("", 0, "The Tide Guardian — a construct of bone and corrupted stone — shatters. Beyond it, stairs descend to the seal chamber. The walls are covered in murals: a king, a crown, a kingdom consumed.", [
						_opt("Descend", [_get_exp(1500), _complete_q()])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ17 — The Broken Seal (FINAL BOSS)
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq17",
		"title": "The Broken Seal",
		"summary": "The seal chamber is shattered. The Hollow King awaits. Use the Seal Key to weaken him. 3-phase fight.",
		"level": 22,
		"location": "thule",
		"target_location": "hellgate",
		"prerequisite": "mq16",
		"boss_dungeon": "end",
		"boss_enemy_path": "res://resources/enemies/quest/hollow_king.tres",
		"start_script": [
			_dlg("", 0, "The seal chamber. Shattered stone, rivers of black ichor, and in the center — a throne. He sits there, waiting. The Hollow King. The one who broke the world to escape death.", [
				_opt("Face him.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "boss_killed",
				"param": "The Hollow King",
				"script": [
					_dlg("", 0, "The Hollow King falls. The corruption convulses, searching for a new anchor. The broken seal pulses — it can be remade, but at a cost.", [
						_opt("What cost?", [_get_exp(5000), _complete_q()])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ18 — The Price of Sealing (FINAL DECISION)
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq18",
		"title": "The Price of Sealing",
		"summary": "The seal must be remade. Someone must bind permanently. Choose who — or redirect the Tide elsewhere.",
		"level": 22,
		"location": "hellgate",
		"target_location": "hellgate",
		"prerequisite": "mq17",
		"start_script": [
			_dlg("Sage Elowen", 163, "The seal requires a living anchor. Someone must bind themselves to it — forever. There is no other way.", [
				_opt("What are the options?", [
					_dlg("Sage Elowen", 163, "You could bind yourself. Or... there may be another way.", [
						_opt("I'll bind myself.", [
							_set_val("mq18", 0, 1),
							_dlg("Sage Elowen", 163, "Your sacrifice will be remembered. The Tide ends here.", [
								_opt("Do it.", [_start_q(), _get_exp(3000), _complete_q()])
							])
						]),
						_opt("Is there another way?", [
							_if_val("session-mq08-0", 0, "gt", [
								_dlg("Priestess Yara", 288, "I was part of this corruption. Let me be its prison. It's the least I can do.", [
									_opt("Let her bind.", [
										_set_val("mq18", 0, 2),
										_dlg("Sage Elowen", 163, "So be it. The priestess will hold the seal.", [
											_opt("Thank you, Yara.", [_start_q(), _get_exp(3000), _complete_q()])
										])
									]),
									_opt("No. I'll find another way.", [
										_set_val("mq18", 0, 3),
										_dlg("Sage Elowen", 163, "There is one more option — redirect the Tide into the deep earth. It won't be sealed, just... moved. It will return someday.", [
											_opt("Buy time.", [_start_q(), _get_exp(2000), _complete_q()])
										])
									])
								])
							]),
							_if_not("session-mq08-0", 0, "gt", [
								_dlg("Sage Elowen", 163, "The priestess might have helped... but she's gone. You can redirect the Tide into the deep earth. It won't seal, just delay.", [
									_opt("Redirect it.", [
										_set_val("mq18", 0, 3),
										_start_q(), _get_exp(2000), _complete_q()
									]),
									_opt("No. I'll bind myself.", [
										_set_val("mq18", 0, 1),
										_dlg("Sage Elowen", 163, "Your courage defines you. The seal holds.", [
											_opt("Do it.", [_start_q(), _get_exp(3000), _complete_q()])
										])
									])
								])
							])
						])
					])
				])
			])
		],
		"events": []
	})

	# -------------------------------------------------------------------
	# MQ19 — Echoes
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq19",
		"title": "Echoes",
		"summary": "Return to Aria. The Healer sees your brand has changed. The Elder finally speaks the truth.",
		"level": 22,
		"location": "hellgate",
		"target_location": "haven",
		"prerequisite": "mq18",
		"start_script": [
			_dlg("Sage Elowen", 163, "It's done. The Tide recedes. Go home. The healer in Aria will want to see you.", [
				_opt("Home.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "haven",
				"script": [
					_dlg("Healer Maren", 160, "Your brand... it's changed. It doesn't burn anymore, does it? It's silver now.", [
						_opt("What does that mean?", [
							_dlg("Elder", 147, "It means you survived what no one else could. Because you're not from here. Not originally. You came through the seal as a child — sent from the old kingdom before it fell. The brand was your passage.", [
								_opt("I'm from... the other side?", [
									_dlg("Elder", 147, "You were. Now you're from here. And here is safe because of you.", [
										_opt("Thank you.", [_get_exp(2000), _complete_q()])
									])
								])
							])
						])
					])
				]
			}
		]
	})

	# -------------------------------------------------------------------
	# MQ20 — The Tide Recedes (EPILOGUE)
	# -------------------------------------------------------------------
	quests.append({
		"id": "mq20",
		"title": "The Tide Recedes",
		"summary": "Visit 5 zones to see the aftermath of your choices. The world remembers.",
		"level": 22,
		"location": "haven",
		"target_location": "haven",
		"prerequisite": "mq19",
		"properties": [{"name": "Zones Visited", "type": "number", "index": 0}],
		"start_script": [
			_dlg("Elder", 147, "The land is healing. But every village tells a different story of what happened. Perhaps you should see for yourself what your choices wrought.", [
				_opt("I will.", [_start_q()])
			])
		],
		"events": [
			{
				"type": "zone_enter",
				"param": "wastes",
				"script": [
					_if_val("session-mq20-0", 5, "lt", [
						_dlg("", 0, "The wilds are green again. Traders pass through without fear. Children play near the road. The caravan wreckage has been cleared.", [
							_opt("Good.", [_inc(0)])
						])
					])
				]
			},
			{
				"type": "zone_enter",
				"param": "frostpass",
				"script": [
					_if_val("session-mq20-0", 5, "lt", [
						_dlg("", 0, "The black ice has melted. The soldiers' bodies were recovered and buried with honor. The frozen temple stands empty but clean.", [
							_opt("Rest now.", [_inc(0)])
						])
					])
				]
			},
			{
				"type": "zone_enter",
				"param": "ashheim",
				"script": [
					_if_val("session-mq20-0", 5, "lt", [
						_dlg("Warden Aldric", 148, "The garrison stands. Because of you. Whatever comes next, Heim remembers.", [
							_opt("Stay strong.", [_inc(0)])
						])
					])
				]
			},
			{
				"type": "zone_enter",
				"param": "cenneth",
				"script": [
					_if_val("session-mq20-0", 5, "lt", [
						_dlg("Sage Elowen", 163, "The ritual circle still hums with power. The fragments are spent, but the binding holds. You did well.", [
							_opt("We all did.", [_inc(0)])
						])
					])
				]
			},
			{
				"type": "zone_enter",
				"param": "thule",
				"script": [
					_if_val("session-mq20-0", 5, "lt", [
						_dlg("Commander Rhis", 149, "Thule rebuilds. The catacombs are sealed — properly this time. Your name is carved above the gate.", [
							_opt("I'm honored.", [_inc(0)])
						])
					])
				]
			},
			{
				"type": "quest",
				"param": "haven",
				"script": [
					_if_val("session-mq20-0", 4, "gt", [
						_dlg("Elder", 147, "You've seen the world you saved. Every village, every face — they owe their lives to you. The Hollow Tide is ended. Your story... is just beginning.", [
							_opt("Thank you.", [_get_exp(5000), _get_gold(5000), _complete_q()])
						])
					])
				]
			}
		]
	})

	return quests
