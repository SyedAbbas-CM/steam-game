class_name BulletModifier
extends Resource

enum ModType { HOMING, PIERCE }

@export var type: ModType
@export var strength: float = 1.0
