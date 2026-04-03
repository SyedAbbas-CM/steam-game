extends Control

## Custom draw node for the world map graph visualization.
## Delegates all drawing and input to the parent WorldMapScreen.

var map_screen = null

func _draw() -> void:
	if not map_screen:
		return
	map_screen._draw_graph(self)

func _gui_input(event: InputEvent) -> void:
	if not map_screen:
		return
	map_screen._on_graph_input(event, self)
