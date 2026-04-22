# ClothingConfig.gd
# ─────────────────────────────────────────────────────────────
# AutoLoad this as "ClothingConfig".
# TO ADD A NEW CLOTHING TYPE: just drop a new key into TYPES.
# Nothing else needs to change.
# ─────────────────────────────────────────────────────────────
extends Node

const TYPES := {

	"tshirt": {

		"display_name":        "T-Shirt",
		"seam_marker_group":   "seam_point",   
		"seam_radius":          0.15,
		"finished_scene":      "res://scenes/clothes/shirt_finished.tscn",
	},
}

func get_config(clothing_type: String) -> Dictionary:
	if TYPES.has(clothing_type):
		return TYPES[clothing_type]
	push_warning("ClothingConfig: unknown type '%s'" % clothing_type)
	return {}
	
