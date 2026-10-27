extends Control
## Menú principal (versión esqueleto; se completa en la fase C).


func _ready() -> void:
	UI.background(self)
	var box := UI.vbox(16)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_child(UI.label("PyMancer", "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("La Academia del Grimorio", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	add_child(box)
