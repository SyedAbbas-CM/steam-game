class_name ObjSpriteIndex
extends RefCounted

## Sprite index reference for lofi_obj.png
## 128x128 image, 8x8 pixel tiles, 16 columns x 16 rows = 256 sprites
## Usage: ObjSpriteIndex.ARROW_RIGHT, ObjSpriteIndex.FIREBALL, etc.

# Row 0: Shields, armor, gems
const SHIELD_WOOD = 0
const SHIELD_IRON = 1
const SHIELD_GOLD = 2
const SHIELD_MAGIC = 3
const HELMET_IRON = 4
const HELMET_GOLD = 5
const ARMOR_CHAIN = 6
const ARMOR_PLATE = 7
const GEM_RED = 8
const GEM_GREEN = 9
const GEM_BLUE = 10
const GEM_PURPLE = 11
const GEM_YELLOW = 12
const GEM_WHITE = 13
const RING_GOLD = 14
const RING_SILVER = 15

# Row 1: Potions, keys, items
const POTION_RED = 16
const POTION_BLUE = 17
const POTION_GREEN = 18
const POTION_YELLOW = 19
const POTION_PURPLE = 20
const POTION_WHITE = 21
const KEY_GOLD = 22
const KEY_SILVER = 23
const COIN_GOLD = 24
const COIN_SILVER = 25
const SCROLL_1 = 26
const SCROLL_2 = 27
const BOOK_RED = 28
const BOOK_BLUE = 29
const BAG_BROWN = 30
const CHEST_WOOD = 31

# Row 2: Swords, blades, daggers
const SWORD_SHORT = 32
const SWORD_LONG = 33
const SWORD_BROAD = 34
const SWORD_MAGIC = 35
const DAGGER = 36
const DAGGER_CURVED = 37
const BLADE_DARK = 38
const BLADE_FLAME = 39
const AXE_SMALL = 40
const AXE_BATTLE = 41
const HAMMER = 42
const MACE = 43
const SPEAR = 44
const HALBERD = 45
const CLUB = 46
const FLAIL = 47

# Row 3: Ranged weapons, staves, wands
const BOW_SHORT = 48
const BOW_LONG = 49
const BOW_MAGIC = 50
const CROSSBOW = 51
const STAFF_WOOD = 52
const STAFF_MAGIC = 53
const STAFF_DARK = 54
const STAFF_CRYSTAL = 55
const WAND_BASIC = 56
const WAND_FIRE = 57
const WAND_ICE = 58
const WAND_DARK = 59
const SLING = 60
const THROWING_STAR = 61
const BOOMERANG = 62
const WHIP = 63

# Row 4: Food, crafting, misc items
const APPLE = 64
const BREAD = 65
const MEAT = 66
const FISH = 67
const MUSHROOM = 68
const HERB_GREEN = 69
const HERB_RED = 70
const FEATHER = 71
const BONE = 72
const SKULL = 73
const CANDLE = 74
const TORCH = 75
const ROPE = 76
const HOOK = 77
const PICK = 78
const SHOVEL = 79

# Row 5: Materials, tools, special items
const ORE_IRON = 80
const ORE_GOLD = 81
const ORE_CRYSTAL = 82
const WOOD_LOG = 83
const CLOTH = 84
const LEATHER = 85
const SCALE = 86
const FUR = 87
const AMULET_1 = 88
const AMULET_2 = 89
const AMULET_3 = 90
const CROWN = 91
const TIARA = 92
const CAPE = 93
const BOOTS = 94
const GLOVES = 95

# Row 6: Projectiles and effects (arrows, bolts)
const ARROW_RIGHT = 96
const ARROW_UP = 97
const ARROW_DIAGONAL = 98
const BOLT_BLUE = 99
const BOLT_RED = 100
const BOLT_GREEN = 101
const BOLT_YELLOW = 102
const BOLT_WHITE = 103
const FIREBALL = 104
const ICEBALL = 105
const POISON_BALL = 106
const LIGHTNING_BOLT = 107
const HOLY_ORB = 108
const DARK_ORB = 109
const ENERGY_BALL = 110
const MAGIC_MISSILE = 111

# Row 7: More projectiles and particles
const SPARK_YELLOW = 112
const SPARK_RED = 113
const SPARK_BLUE = 114
const SPARK_GREEN = 115
const SPARK_WHITE = 116
const STAR_4POINT = 117
const STAR_6POINT = 118
const STAR_BURST = 119
const SLASH_1 = 120
const SLASH_2 = 121
const SLASH_3 = 122
const IMPACT_1 = 123
const IMPACT_2 = 124
const EXPLOSION_1 = 125
const EXPLOSION_2 = 126
const SMOKE_PUFF = 127

# Row 8-9: Status icons and UI elements
const HEART_FULL = 128
const HEART_HALF = 129
const HEART_EMPTY = 130
const MANA_FULL = 131
const MANA_EMPTY = 132
const ICON_SWORD = 133
const ICON_SHIELD = 134
const ICON_MAGIC = 135
const ICON_POISON = 136
const ICON_FIRE = 137
const ICON_ICE = 138
const ICON_THUNDER = 139
const ICON_HOLY = 140
const ICON_DARK = 141
const ICON_HEAL = 142
const ICON_BUFF = 143

const ARROW_UP_SMALL = 144
const ARROW_DOWN_SMALL = 145
const ARROW_LEFT_SMALL = 146
const ARROW_RIGHT_SMALL = 147
const CHECK = 148
const CROSS = 149
const EXCLAIM = 150
const QUESTION = 151
const PLUS = 152
const MINUS = 153
const SKULL_ICON = 154
const EYE = 155
const LOCK = 156
const UNLOCK = 157
const MUSIC = 158
const BELL = 159

# Rows 10-15: More effects, decorations, particles
const SPARKLE_1 = 160
const SPARKLE_2 = 161
const SPARKLE_3 = 162
const SPARKLE_4 = 163
const GLOW_WHITE = 164
const GLOW_RED = 165
const GLOW_BLUE = 166
const GLOW_GREEN = 167
const GLOW_YELLOW = 168
const GLOW_PURPLE = 169
const BUBBLE = 170
const DROP_WATER = 171
const DROP_BLOOD = 172
const DROP_POISON = 173
const FLAME_SMALL = 174
const FLAME_LARGE = 175

## Helper to get the atlas region for a given sprite index
static func get_region(index: int) -> Rect2:
	var col = index % 16
	var row = index / 16
	return Rect2(col * 8, row * 8, 8, 8)

## Mapping of weapon name keywords to bullet sprite indices
static func get_bullet_sprite_for_weapon(weapon_name: String) -> int:
	var lower := weapon_name.to_lower()
	# Bows → arrows
	if "bow" in lower or "crossbow" in lower:
		return ARROW_RIGHT
	# Staves, wands, books → magic missiles
	if "staff" in lower or "wand" in lower or "book" in lower or "rod" in lower:
		return MAGIC_MISSILE
	# Fire weapons → fireballs
	if "fire" in lower or "flame" in lower or "lava" in lower or "inferno" in lower:
		return FIREBALL
	# Ice weapons → ice bolts
	if "ice" in lower or "frost" in lower or "frostgrave" in lower or "cold" in lower:
		return ICEBALL
	# Poison weapons
	if "poison" in lower or "venom" in lower or "toxic" in lower:
		return POISON_BALL
	# Lightning weapons
	if "lightning" in lower or "thunder" in lower or "storm" in lower or "shock" in lower:
		return LIGHTNING_BOLT
	# Holy weapons
	if "holy" in lower or "divine" in lower or "sacred" in lower or "blessed" in lower:
		return HOLY_ORB
	# Dark weapons
	if "dark" in lower or "shadow" in lower or "death" in lower or "void" in lower:
		return DARK_ORB
	# Swords, blades, daggers → energy slash
	if "sword" in lower or "blade" in lower or "dagger" in lower or "shiv" in lower or "knife" in lower:
		return SLASH_1
	# Axes, hammers, maces → impact
	if "axe" in lower or "hammer" in lower or "mace" in lower or "club" in lower:
		return IMPACT_1
	# Spears → bolt
	if "spear" in lower or "lance" in lower or "javelin" in lower or "pike" in lower:
		return BOLT_YELLOW
	# Claws → slash
	if "claw" in lower or "fang" in lower or "talon" in lower:
		return SLASH_2
	# Throwing → star
	if "throwing" in lower or "shuriken" in lower or "star" in lower:
		return THROWING_STAR
	# Default: energy ball
	return ENERGY_BALL

## Weapon range based on weapon type
static func get_range_for_weapon(weapon_name: String) -> float:
	var lower = weapon_name.to_lower()
	# Bows/crossbows → long range
	if "bow" in lower or "crossbow" in lower:
		return 5.0
	# Staves/wands/books → medium-long range
	if "staff" in lower or "wand" in lower or "book" in lower or "rod" in lower:
		return 4.0
	# Swords/blades → medium range
	if "sword" in lower or "blade" in lower:
		return 2.5
	# Daggers/shivs → short range
	if "dagger" in lower or "shiv" in lower or "knife" in lower:
		return 1.5
	# Axes/hammers → medium range
	if "axe" in lower or "hammer" in lower or "mace" in lower or "club" in lower:
		return 2.0
	# Spears → medium-long
	if "spear" in lower or "lance" in lower or "javelin" in lower:
		return 3.5
	# Claws → very short
	if "claw" in lower or "fang" in lower:
		return 1.2
	# Default
	return 3.0
