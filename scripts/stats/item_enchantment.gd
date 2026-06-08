class_name ItemEnchantment
extends Resource

enum EnchantType { FIRE, ICE, POISON, LIGHTNING, HOLY, DARK, VAMPIRIC, EXPLOSIVE, BULWARK, MYSTIC, WRAITH }

# Passive enchants (BULWARK / MYSTIC / WRAITH) — provide perk-style effects via gear.
# Map enchant type -> passive effect name expected by player.gd.
const PASSIVE_EFFECTS = {
	EnchantType.BULWARK: "bastion",
	EnchantType.MYSTIC: "mystic_shield",
	EnchantType.WRAITH: "wraithwalk",
	EnchantType.VAMPIRIC: "lifesteal",  # on-hit + perk both heal
}

@export var type: EnchantType = EnchantType.FIRE
@export var tier: int = 1  # 1-3
@export var bonus_damage: float = 0.0
@export var proc_chance: float = 0.0  # 0-100, % chance for on-hit effect

static func create(etype: EnchantType, etier: int) -> ItemEnchantment:
	var e = ItemEnchantment.new()
	e.type = etype
	e.tier = clampi(etier, 1, 3)
	match e.tier:
		1:
			e.bonus_damage = 1.0
			e.proc_chance = 15.0
		2:
			e.bonus_damage = 3.0
			e.proc_chance = 25.0
		3:
			e.bonus_damage = 6.0
			e.proc_chance = 40.0
	return e

func get_prefix() -> String:
	match type:
		EnchantType.FIRE: return "Flaming"
		EnchantType.ICE: return "Frozen"
		EnchantType.POISON: return "Toxic"
		EnchantType.LIGHTNING: return "Shocking"
		EnchantType.HOLY: return "Holy"
		EnchantType.DARK: return "Dark"
		EnchantType.VAMPIRIC: return "Vampiric"
		EnchantType.EXPLOSIVE: return "Explosive"
		EnchantType.BULWARK: return "Bulwark"
		EnchantType.MYSTIC: return "Mystic"
		EnchantType.WRAITH: return "Wraith"
	return ""

func get_color() -> Color:
	match type:
		EnchantType.FIRE: return Color(1.0, 0.4, 0.1)
		EnchantType.ICE: return Color(0.3, 0.7, 1.0)
		EnchantType.POISON: return Color(0.3, 0.9, 0.2)
		EnchantType.LIGHTNING: return Color(1.0, 1.0, 0.3)
		EnchantType.HOLY: return Color(1.0, 1.0, 0.8)
		EnchantType.DARK: return Color(0.5, 0.2, 0.8)
		EnchantType.VAMPIRIC: return Color(0.8, 0.1, 0.3)
		EnchantType.EXPLOSIVE: return Color(1.0, 0.6, 0.0)
		EnchantType.BULWARK: return Color(0.85, 0.75, 0.4)
		EnchantType.MYSTIC: return Color(0.3, 0.6, 1.0)
		EnchantType.WRAITH: return Color(0.5, 0.2, 0.7)
	return Color.WHITE

func get_enchant_cost() -> int:
	match tier:
		1: return 100
		2: return 500
		3: return 2000
	return 100
