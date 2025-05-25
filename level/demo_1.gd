extends Node

const APPLE_REQUIRED := 5
const BEER_REQUIRED := 5
const FISH_REQUIRED := 5
const FISH_BONE_REQUIRED := 5
const POP_CORN_REQUIRED := 5
const ET_REQUIRED := 1

var item_required_counts := {
	"apple": APPLE_REQUIRED,
	"beer": BEER_REQUIRED,
	"fish": FISH_REQUIRED,
	"fish_bone": FISH_BONE_REQUIRED,
	"pop_corn": POP_CORN_REQUIRED,
	"et": ET_REQUIRED
}

var items := {
	1: "apple",
	2: "beer",
	3: "fish",
	4: "fish_bone",
	5: "pop_corn",
	6: "et"
}

var item_counts := {
	"apple": 0,
	"beer": 0,
	"fish": 0,
	"fish_bone": 0,
	"pop_corn": 0,
	"et": 0
}

func _ready():
	update_item_ui()

func _on_item_dropped(item_type: String) -> void:
	if items.values().has(item_type):
		update_item_count.rpc(item_type)

@rpc("call_local")
func update_item_count(item_type: String) -> void:
	item_counts[item_type] += 1
	update_item_ui()

func update_item_ui() -> void:
	# Update the UI with the current item counts
	for item_id in items.keys():
		var count_label = get_node("HUD/HUD/Item" + str(item_id) + "/Label")
		if count_label:
			count_label.text = str(item_counts[items[item_id]]) + "/" + str(item_required_counts[items[item_id]])
