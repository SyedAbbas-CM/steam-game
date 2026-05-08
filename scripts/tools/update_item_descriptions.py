#!/usr/bin/env python3
"""Rewrite each item .tres description with richer flavor + tactical text.

The inventory tooltip already prints stat modifiers, weapon type, [SPACE]/[SHIFT]
abilities, sockets and tags separately — so the *description* should focus on
flavor: what the weapon feels like, how it's wielded, what makes it different.

Format produced (single line, semicolon-joined):
  "<Article> <rarity_word><name_theme><flavor_adj> <kind>; <tactical_hint>."
With "Grants <Spell> while equipped." appended for spell-granting items.
"""
import os
import re

ITEMS_DIR = os.path.join(os.path.dirname(__file__), "../../resources/items/loy")

# ---------------------------------------------------------------------------
# Per weapon-type flavor pools.
#  - "adj"  : style/quality adjectives picked by name hash
#  - "kind" : how the weapon should be referred to in prose
#  - "tips" : tactical / lore hints; one is appended each time
# ---------------------------------------------------------------------------
WEAPON_FLAVOR = {
    "sword": {
        "adj":  ["keen-edged", "balanced", "well-forged", "tempered", "sharp", "duelist's"],
        "kind": "blade",
        "tips": [
            "Quick to parry, quicker to riposte",
            "Sings through unarmored foes",
            "Equally at home cleaving and thrusting",
            "Favoured by knights and travelling sellswords alike",
        ],
    },
    "dagger": {
        "adj":  ["razor-sharp", "swift", "lightweight", "serrated", "deadly", "needle-pointed"],
        "kind": "dagger",
        "tips": [
            "Strikes faster than the eye can follow",
            "Slips between plates and through joints",
            "Best drawn from the shadows or in tight quarters",
            "Few wear armour that stops a determined cut",
        ],
    },
    "axe": {
        "adj":  ["brutal", "heavy-bladed", "war-worn", "cleaving", "broad-bladed"],
        "kind": "axe",
        "tips": [
            "Splits shields as readily as skulls",
            "Leans into momentum — every swing carries weight",
            "Hooks rims and tears them aside",
            "Forged for raiders who prefer noise to subtlety",
        ],
    },
    "club": {
        "adj":  ["weighted", "bone-breaking", "studded", "knotted", "crude", "heavy"],
        "kind": "club",
        "tips": [
            "Cracks armour even when the edge cannot",
            "Trades finesse for sheer concussion",
            "Crushes plate; breaks bones beneath chain",
            "A simple weapon — and that is its strength",
        ],
    },
    "hammer": {
        "adj":  ["thunderous", "heavy", "crushing", "earth-shaking", "mighty"],
        "kind": "warhammer",
        "tips": [
            "Each swing lands like a falling timber",
            "Designed to dent helm and rib alike",
            "Slow, deliberate, and unanswerable",
            "The favourite tool of mountain-folk smiths-turned-warriors",
        ],
    },
    "spear": {
        "adj":  ["long-reaching", "balanced", "sharp-tipped", "steady", "piercing"],
        "kind": "spear",
        "tips": [
            "Range is its first virtue, precision its second",
            "Holds enemies at the edge of your reach",
            "Disciplined formations live and die by it",
            "Best used in step-thrust patterns — never as a club",
        ],
    },
    "flail": {
        "adj":  ["chain-linked", "swinging", "brutal", "unpredictable", "whirling"],
        "kind": "flail",
        "tips": [
            "Bypasses shields by flowing around them",
            "Rewards rhythm; punishes hesitation",
            "Once swinging, it must keep swinging",
            "Hard to learn, terrifying to face",
        ],
    },
    "throwing": {
        "adj":  ["aerodynamic", "lightweight", "precise", "balanced", "well-weighted"],
        "kind": "throwing weapon",
        "tips": [
            "A volley before the foe closes the gap",
            "Carry many; expect to leave most behind",
            "Strikes hardest when thrown with the wrist, not the arm",
            "Silent compared to a bow — useful in quiet work",
        ],
    },
    "bow": {
        "adj":  ["flexible", "long-range", "accurate", "sturdy", "well-strung"],
        "kind": "bow",
        "tips": [
            "Reach is everything; never let foes close",
            "Drawn properly, every shot speaks for itself",
            "A patient archer is worth ten frantic ones",
            "The string sings; the arrow does the killing",
        ],
    },
    "short_bow": {
        "adj":  ["compact", "quick-draw", "lightweight", "agile", "handy"],
        "kind": "short bow",
        "tips": [
            "Loses range in trade for speed of fire",
            "Easy to draw on the run or from horseback",
            "Made for skirmish and ambush, not siege",
            "Pairs well with a backup blade for close work",
        ],
    },
    "crossbow": {
        "adj":  ["mechanical", "heavy-bolt", "armor-piercing", "precision-tooled", "geared"],
        "kind": "crossbow",
        "tips": [
            "One bolt, decisively placed",
            "Slow to reload — choose the shot that counts",
            "Punches through plate that arrows would skitter off",
            "Trades a bow's grace for raw mechanical force",
        ],
    },
    "staff": {
        "adj":  ["arcane", "channeling", "rune-carved", "resonating", "enchanted"],
        "kind": "staff",
        "tips": [
            "A focus for those who shape the unseen",
            "Bleeds magic with every gesture",
            "Long enough to ward, true enough to strike",
            "Carries its own faint light in dark places",
        ],
    },
    "wand": {
        "adj":  ["crackling", "focused", "sparking", "volatile", "rune-tipped"],
        "kind": "wand",
        "tips": [
            "Concentrates raw magic into a single point",
            "Quicker to cast than any staff or tome",
            "Demands a steady hand — backlash is unforgiving",
            "Small enough to hide in a sleeve",
        ],
    },
    "tome": {
        "adj":  ["ancient", "knowledge-bound", "inscribed", "glowing", "leather-bound"],
        "kind": "tome",
        "tips": [
            "Words inside it remember being read",
            "Each spell costs a page, then a pulse of will",
            "Best wielded by the patient and the curious",
            "Some pages turn themselves when no one looks",
        ],
    },
    "javelin": {
        "adj":  ["barbed", "long-shafted", "weighted", "armor-piercing", "skirmisher's"],
        "kind": "javelin",
        "tips": [
            "Throw, then close — never the other way around",
            "A volley to thin the line before the press",
            "Heavy enough to punch shields aside",
            "Carry three; they go where they are most needed",
        ],
    },
    "sling": {
        "adj":  ["woven", "elastic", "rapid-fire", "supple", "shepherd's"],
        "kind": "sling",
        "tips": [
            "Cheap stones, expensive consequences",
            "Forgotten by armies; never by farmers",
            "Whirls before it strikes — telegraph is the trade-off",
            "A child's toy until it cracks a helm",
        ],
    },
    "halberd": {
        "adj":  ["imposing", "long-hafted", "guardian's", "sweeping", "versatile"],
        "kind": "halberd",
        "tips": [
            "Thrust like a spear, hew like an axe, hook like a flail",
            "Built to dismount horsemen and crack columns",
            "Holds the line by being its own line",
            "Not a weapon for tight halls",
        ],
    },
    "greatsword": {
        "adj":  ["massive", "two-handed", "devastating", "ridge-spined", "titanic"],
        "kind": "greatsword",
        "tips": [
            "Sweeps clear arcs of space around the wielder",
            "Demands strength; rewards reach",
            "Few weapons cleave a man and his shield in one stroke",
            "Heavy enough to break charges, fine enough to thrust",
        ],
    },
    "great_axe": {
        "adj":  ["enormous", "skull-splitting", "double-bladed", "executioner's", "rending"],
        "kind": "great axe",
        "tips": [
            "Built for one terrible swing at a time",
            "Hews through gambeson, mail, and oak alike",
            "Best held high, brought down with the hips",
            "Few foes stand after meeting one",
        ],
    },
    "whip": {
        "adj":  ["lashing", "coiled", "stinging", "supple", "knotted"],
        "kind": "whip",
        "tips": [
            "Strikes where shields cannot guard",
            "More punishment than killing weapon — until it isn't",
            "Coils around limbs and weapons alike",
            "Wins fights by drawing them out",
        ],
    },
    "scythe": {
        "adj":  ["reaping", "curved", "death-touched", "harvesting", "grim"],
        "kind": "scythe",
        "tips": [
            "Cuts in arcs no straight blade can match",
            "A farmer's tool turned grim by intent",
            "Hooks legs as readily as it severs them",
            "Carries the weight of every harvest before it",
        ],
    },
    "claws": {
        "adj":  ["rending", "savage", "razor-tipped", "feral", "vicious"],
        "kind": "set of claws",
        "tips": [
            "Turns fists into a wolf's jaws",
            "Made for those who would rather grapple than parry",
            "Strikes faster than any forged blade",
            "Worn by those with nothing else to lose",
        ],
    },
    "sceptre": {
        "adj":  ["regal", "power-infused", "ornate", "commanding", "blessed"],
        "kind": "sceptre",
        "tips": [
            "More symbol than weapon — but a heavy one",
            "Channels authority and magic in equal measure",
            "Carried by those who lead from the front",
            "Strikes ring with each word spoken behind it",
        ],
    },
}

# Themed name modifiers — adjust adjectives + tip when name contains a keyword.
NAME_THEMES = [
    ("frost",     "frost-rimed",   "Cold seeps from its surface and into the wound"),
    ("ice",       "ice-bound",     "Wounds it makes are slow to warm again"),
    ("flame",     "flame-kissed",  "Edges shimmer with a heat that does not fade"),
    ("fire",      "fire-forged",   "Glows faintly in the dark, as if remembering the forge"),
    ("ember",     "ember-veined",  "Lines of orange light pulse along its length"),
    ("bone",      "bone-carved",   "Shaped from something that was once alive"),
    ("skull",     "skull-graven",  "A skull's hollow grin marks the maker's pride"),
    ("undead",    "death-bound",   "Cold and quiet — and never quite still"),
    ("holy",      "consecrated",   "Hums faintly near unholy creatures"),
    ("blessed",   "blessed",       "Light catches it strangely, almost gently"),
    ("cursed",    "cursed",        "Whispers travel along its length when no one is listening"),
    ("dark",      "shadow-touched","Drinks light into itself rather than reflecting it"),
    ("shadow",    "shadow-touched","Hard to keep an eye on, even in plain sight"),
    ("demon",     "demon-marked",  "Bears sigils that ache to read aloud"),
    ("infernal",  "infernal",      "Smells of brimstone, faintly, even after rain"),
    ("storm",     "storm-charged", "Hairs rise on the arm that holds it"),
    ("thunder",   "thunder-cast",  "Each strike rolls like a distant peal"),
    ("lightning", "lightning-etched","Tiny arcs leap to nearby metal"),
    ("gold",      "gilded",        "Worth more for its shine than its bite, some say"),
    ("silver",    "silvered",      "Bright enough to be seen at night, sharp enough to matter"),
    ("iron",      "iron-cast",     "Plain, dependable, and likely to outlast its owner"),
    ("steel",     "tempered-steel","Honest steel, well-folded and well-kept"),
    ("ancient",   "age-worn",      "Older than any name still spoken near it"),
    ("dragon",    "dragon-marked", "Scales etched along its grip mean nothing kind"),
    ("venom",     "venom-laced",   "A wound here closes slowly, if at all"),
    ("poison",    "poisoned",      "A faint film slicks the edge"),
    ("blood",     "blood-drinking","Rumour has it the metal runs warmer in a fight"),
    ("rune",      "rune-graven",   "Carvings catch the eye and refuse to be read"),
    ("witch",     "witch-touched", "Even a steady hand twitches when first held"),
    ("orc",       "orc-forged",    "Crude work, brutally effective"),
    ("goblin",    "goblin-tinker", "Small, crooked, and uncomfortably sharp"),
    ("dwarf",     "dwarf-forged",  "Heavy in the way only honest dwarven work is"),
    ("elf",       "elf-wrought",   "Lighter than it looks, slow to dull"),
    ("royal",     "royal",         "Marks of a court that no longer answers letters"),
    ("legendary", "storied",       "Bards still sing parts of its history wrong"),
    ("legend",    "storied",       "A name in a few books and several arguments"),
]

ARMOR_FLAVOR = {
    "HELM": {
        "adj":  ["protective", "sturdy", "reinforced", "battle-tested", "ornate", "visored", "plumed"],
        "kind": "helm",
        "tips": [
            "Keeps glancing blows from finding the eye",
            "A good helm is rarely remembered — a bad one only once",
            "Adds weight, but the kind a head can grow used to",
            "Trades a little hearing for a lot of skull",
        ],
    },
    "BODY": {
        "adj":  ["sturdy", "well-crafted", "reinforced", "layered", "battle-worn", "padded"],
        "kind": "armour",
        "tips": [
            "Built to take the hit, then stand to take another",
            "Heavier than it looks, lighter than it lives up to",
            "Stops what a tunic only suggests",
            "Wear it in until it remembers your shape",
        ],
    },
    "SHIELD": {
        "adj":  ["banded", "battered", "reinforced", "guardian's", "unyielding", "studded"],
        "kind": "shield",
        "tips": [
            "Half the fight is reading what the other side will do — the rest is this",
            "Turns a sword's edge into wasted breath",
            "Trades reach for survival, every time",
            "A line in the dirt you can carry with you",
        ],
    },
    "BOOTS": {
        "adj":  ["sure-footed", "comfortable", "reinforced", "supple", "waxed"],
        "kind": "boots",
        "tips": [
            "Quiet on stone, sure on snow",
            "Soles that remember the road",
            "Cold feet end fights early — these end nothing",
            "Worn long enough to fight in barefoot ease",
        ],
    },
    "GLOVES": {
        "adj":  ["dexterous", "reinforced", "supple", "gripping", "studded"],
        "kind": "gloves",
        "tips": [
            "Saves fingers without trading away grip",
            "Lets a blade live longer in the hand",
            "Knuckles plated where the work demands",
            "The kind of gloves no one asks about until they're missing",
        ],
    },
    "RING": {
        "adj":  ["enchanted", "gleaming", "inscribed", "ancient", "mystical", "engraved"],
        "kind": "ring",
        "tips": [
            "Small, quiet, and hard to part with",
            "A circle never closes if it has work to do",
            "Easier to lose than to find",
            "Magic, the kind that hides in the corner of a hand",
        ],
    },
    "CLOAK": {
        "adj":  ["flowing", "shadow-cut", "weathered", "concealing", "lined"],
        "kind": "cloak",
        "tips": [
            "Hides the shape long enough to shape the fight",
            "Keeps rain off and onlookers off the trail",
            "Easy to leave behind if it ever betrays you",
            "Worn long, drawn deep — a quieter kind of armour",
        ],
    },
}

CONSUMABLE_FLAVOR = {
    "heal_hp": [
        "Tastes worse than the wound; works faster",
        "A traveller's friend, a chirurgeon's compromise",
        "Bottled in better days, priced for these ones",
        "Drink in a single pull — the second sip is always wasted",
    ],
    "heal_mp": [
        "Cool and bitter; the head clears within a breath",
        "Brewed for those who tire of forgetting their own spells",
        "Tastes faintly of starlight and old ink",
        "A little goes far; a lot goes badly",
    ],
}

SLOT_MAP = {
    "0": "WEAPON_MELEE", "1": "WEAPON_RANGED", "2": "WEAPON_MAGIC",
    "3": "HELM", "4": "BODY", "5": "SHIELD", "6": "BOOTS",
    "7": "GLOVES", "8": "RING", "9": "CLOAK", "10": "CONSUMABLE",
    "11": "MATERIAL", "12": "AMMO",
}

RARITY_WORDS = ["", "fine ", "exceptional ", "legendary "]


def parse_tres(path):
    with open(path, 'r') as f:
        content = f.read()
    data = {"content": content}
    for field in [
        "item_name", "description", "weapon_type", "slot_type", "rarity",
        "buy_price", "heal_hp", "heal_mp", "use_effect",
        "grants_spell", "ability_id"
    ]:
        m = re.search(rf'^{field}\s*=\s*"?([^"\n]*)"?\s*$', content, re.MULTILINE)
        data[field] = m.group(1).strip('"') if m else ""
    return data


def pick(seq, key):
    """Stable pick from `seq` based on a string `key`."""
    if not seq:
        return ""
    return seq[hash(key) % len(seq)]


def name_theme(name_lc, base_adj):
    """Return (adjective, themed_tip_or_empty) for a themed name; else (base_adj, '')."""
    for key, adj, tip in NAME_THEMES:
        if key in name_lc:
            return adj, tip
    return base_adj, ""


def article_for(text):
    return "An" if text and text[0].lower() in "aeiou" else "A"


def generate_description(data):
    name = data.get("item_name", "Unknown") or "Unknown"
    name_lc = name.lower()
    wtype = data.get("weapon_type", "") or ""
    slot = data.get("slot_type", "") or "0"
    rarity = int(data.get("rarity") or "0")
    rarity_word = RARITY_WORDS[min(rarity, 3)]
    heal_hp = int(data.get("heal_hp") or "0")
    heal_mp = int(data.get("heal_mp") or "0")
    use_effect = data.get("use_effect", "") or ""
    grants_spell = data.get("grants_spell", "") or ""
    slot_name = SLOT_MAP.get(slot, slot)

    # Consumables
    if slot_name == "CONSUMABLE":
        parts = []
        if heal_hp > 0 and heal_mp > 0:
            parts.append(f"Restores {heal_hp} HP and {heal_mp} MP")
            parts.append(pick(CONSUMABLE_FLAVOR["heal_hp"], name))
        elif heal_hp > 0:
            parts.append(f"Restores {heal_hp} HP")
            parts.append(pick(CONSUMABLE_FLAVOR["heal_hp"], name))
        elif heal_mp > 0:
            parts.append(f"Restores {heal_mp} MP")
            parts.append(pick(CONSUMABLE_FLAVOR["heal_mp"], name))
        elif use_effect:
            parts.append(f"Use: {use_effect.replace('_', ' ').title()}")
        else:
            return ""
        return ". ".join(parts) + "."

    if slot_name == "MATERIAL" or slot_name == "AMMO":
        return ""  # leave existing or empty

    # Weapons
    if wtype and wtype in WEAPON_FLAVOR:
        flavor = WEAPON_FLAVOR[wtype]
        base_adj = pick(flavor["adj"], name)
        adj, themed_tip = name_theme(name_lc, base_adj)
        kind = flavor["kind"]
        tip = themed_tip or pick(flavor["tips"], name)
        article = article_for(rarity_word + adj)
        sentence = f"{article} {rarity_word}{adj} {kind}; {tip}."
        if grants_spell:
            spell_name = grants_spell.replace("_", " ").title()
            sentence += f" Grants {spell_name} while equipped."
        return sentence

    # Armour / accessories
    if slot_name in ARMOR_FLAVOR:
        flavor = ARMOR_FLAVOR[slot_name]
        base_adj = pick(flavor["adj"], name)
        adj, themed_tip = name_theme(name_lc, base_adj)
        kind = flavor["kind"]
        tip = themed_tip or pick(flavor["tips"], name)
        article = article_for(rarity_word + adj)
        sentence = f"{article} {rarity_word}{adj} {kind}; {tip}."
        if grants_spell:
            spell_name = grants_spell.replace("_", " ").title()
            sentence += f" Grants {spell_name} while equipped."
        return sentence

    return ""


def update_file(path):
    data = parse_tres(path)
    if not data.get("item_name"):
        return False
    new_desc = generate_description(data)
    if not new_desc:
        return False
    # .tres values can't contain raw " — escape only that.
    safe_desc = new_desc.replace('\\', '\\\\').replace('"', '\\"')
    content = data["content"]
    if re.search(r'^description\s*=\s*"', content, re.MULTILINE):
        new_content = re.sub(
            r'^description\s*=\s*"[^"]*"',
            f'description = "{safe_desc}"',
            content,
            count=1,
            flags=re.MULTILINE,
        )
    else:
        new_content = re.sub(
            r'^(item_name\s*=\s*"[^"]*")',
            rf'\1\ndescription = "{safe_desc}"',
            content,
            count=1,
            flags=re.MULTILINE,
        )
    if new_content != content:
        with open(path, "w") as f:
            f.write(new_content)
        return True
    return False


def main():
    items_dir = os.path.abspath(ITEMS_DIR)
    count = 0
    for fname in sorted(os.listdir(items_dir)):
        if not fname.endswith(".tres"):
            continue
        path = os.path.join(items_dir, fname)
        if update_file(path):
            count += 1
    print(f"Updated {count} item descriptions")


if __name__ == "__main__":
    main()
