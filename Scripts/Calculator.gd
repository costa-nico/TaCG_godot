extends Node

# Called when the node enters the scene tree for the first time.
func get_center(control_node: Control) -> Vector2:
	var rect = control_node.get_global_rect()
	return rect.position + (rect.size / 2.0)


func get_pos_center_to_center(control_node: Control, target_node: Control) -> Vector2:
	var target_center = get_center(target_node)
	var rect = control_node.get_global_rect()
	return target_center - (rect.size  / 2.0)

func get_pos_center_to_pos(control_node: Control, target_pos: Vector2) -> Vector2:
	var rect = control_node.get_global_rect()
	return target_pos - (rect.size  / 2.0)
