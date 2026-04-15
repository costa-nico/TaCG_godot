extends Node


# Called when the node enters the scene tree for the first time.
func get_center(rectangle):
	return rectangle.position + (rectangle.size*rectangle.scale / 2)