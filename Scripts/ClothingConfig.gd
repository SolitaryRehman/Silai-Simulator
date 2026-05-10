extends Node

# lookup table of every clothing type the game knows how to make
const TYPES := {
	"tshirt": {
		"display_name":        "T-Shirt",
		# group name that seam Marker3Ds must belong to for detection to work
		"seam_marker_group":   "seam_point",
		# how close a seam marker needs to be to the needle tip to count as sewn
		"seam_radius":          0.04,
		# the completed garment scene that pops in after all seams are done
		"finished_scene":      "res://scenes/clothes/shirt_finished.tscn",
	},
}

func get_config(clothing_type: String) -> Dictionary:
	if TYPES.has(clothing_type):
		return TYPES[clothing_type]
	# warn loudly instead of silently returning empty so bad type strings are caught early
	push_warning("ClothingConfig: unknown type '%s'" % clothing_type)
	return {}
