extends Node
 
signal order_received(order_data)
signal garment_cut(garment_type)
signal garment_sewn(garment_type)
 
enum GameState {
	FREE_ROAM,
	CUTTING,
	SEWING,
	DELIVERING
}
 
var current_state: GameState = GameState.FREE_ROAM
var current_order: Dictionary = {}
var cut_pieces: Array = []
var is_piece_cut: bool = false
 
 
func receive_order(garment_type: String):
	current_order = {
		"type": garment_type,
		"status": "pending_cut"
	}
	cut_pieces.clear()
	is_piece_cut = false
	emit_signal("order_received", current_order)
	print("New order: Make a ", garment_type)
 
 
func complete_cutting():
	is_piece_cut = true
	current_order["status"] = "pending_sew"
	emit_signal("garment_cut", current_order["type"])
 
 
func complete_sewing():
	current_order["status"] = "complete"
	emit_signal("garment_sewn", current_order["type"])
	current_state = GameState.FREE_ROAM
