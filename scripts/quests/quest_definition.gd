class_name QuestDefinition
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var summary: String = ""
@export var level: int = 1
@export var location: String = ""          # Zone where quest is offered
@export var target_location: String = ""   # Zone for turn-in
@export var properties: Array = []  # [{name, type, index}]
@export var start_script: Array = []
@export var cancel_script: Array = []
@export var events: Array = []  # [{type, param, script}]
