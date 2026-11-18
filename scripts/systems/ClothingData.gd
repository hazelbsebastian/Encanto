extends Node
## ClothingData (autoload)
## Static catalogue of wardrobe items and the Bayong random-reward pool.
## Designed to be easy to extend with more items later.

# Each item: id, name, category (top/bottom/accessory), price, tint (Color used
# to modulate the matching player sprite layer; accessories use icon_path).
const ITEMS := {
	"basic_polo": {"name": "Basic White Polo", "category": "top", "price": 0, "tint": Color(1, 1, 1)},
	"improved_polo": {"name": "Improved Traditional Polo", "category": "top", "price": 500, "tint": Color(0.75, 0.86, 1.0)},
	"barong": {"name": "Barong-inspired Top", "category": "top", "price": 1000, "tint": Color(1.0, 0.92, 0.6)},
	"special_top": {"name": "Special Filipino Outfit (Top)", "category": "top", "price": 1500, "tint": Color(1.0, 0.55, 0.5)},

	"basic_pants": {"name": "Basic Farmer Pants", "category": "bottom", "price": 0, "tint": Color(1, 1, 1)},
	"traditional_pants": {"name": "Traditional Pants", "category": "bottom", "price": 500, "tint": Color(0.6, 0.75, 0.55)},
	"upgraded_pants": {"name": "Upgraded Farmer Pants", "category": "bottom", "price": 750, "tint": Color(0.55, 0.6, 0.85)},
	"special_bottom": {"name": "Special Filipino Outfit (Bottom)", "category": "bottom", "price": 1200, "tint": Color(0.25, 0.22, 0.22)},

	"none": {"name": "No Accessory", "category": "accessory", "price": 0, "icon": ""},
	"salakot": {"name": "Salakot", "category": "accessory", "price": 300, "icon": "res://assets/ui/salakot_icon.png"},
	"kerchief": {"name": "Traditional Kerchief", "category": "accessory", "price": 400, "icon": "res://assets/ui/salakot_icon.png"},
}

const CATEGORIES := ["top", "bottom", "accessory"]

# Bayong random reward pool - easy to expand: just append more entries here.
const BAYONG_POOL := [
	{"type": "money", "amount": 100},
	{"type": "money", "amount": 250},
	{"type": "money", "amount": 500},
	{"type": "clothing", "id": "salakot"},
	{"type": "clothing", "id": "barong"},
	{"type": "clothing", "id": "traditional_pants"},
	{"type": "clothing", "id": "improved_polo"},
	{"type": "clothing", "id": "kerchief"},
]

func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

func items_in_category(category: String) -> Array:
	var out: Array = []
	for id in ITEMS.keys():
		if ITEMS[id]["category"] == category:
			out.append(id)
	return out

func random_bayong_reward() -> Dictionary:
	return BAYONG_POOL[randi() % BAYONG_POOL.size()]
