class_name QuestDefinition
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var summary: String = ""
@export var level: int = 1
@export var location: String = ""          # Zone where quest is offered
@export var target_location: String = ""   # Zone for turn-in
@export var giver_npc: String = ""         # NPC who offers/turns in this quest. Empty = any NPC in zone.
@export var prerequisite: String = ""          # Single quest ID that must be completed first
@export var prerequisite_list: Array[String] = []  # AND logic: ALL must be completed
@export var boss_dungeon: String = ""          # Dungeon biome prefix for quest boss override
@export var boss_enemy_path: String = ""       # EnemyDefinition .tres path for quest boss
@export var properties: Array = []  # [{name, type, index}]
@export var start_script: Array = []
@export var cancel_script: Array = []
@export var events: Array = []  # [{type, param, script}]
