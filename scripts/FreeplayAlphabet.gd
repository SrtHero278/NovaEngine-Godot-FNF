@tool
@icon("res://editor/icons/alphabet.png")

extends Alphabet
class_name FreeplayAlphabet

@export var is_template:bool = false

func _process(delta):
	if not is_template and not Engine.is_editor_hint():
		var scaled_y = target_y * 1.3
		
		position.y = lerpf(position.y, (scaled_y * 65) + (Global.game_size.y * 0.39), 0.16 * 60 * delta);
		var x_mult = -0.8 if scaled_y < 0 else 0.8
		position.x = lerpf(position.x, exp(scaled_y * x_mult) * 70 + (Global.game_size.x * 0.1), 0.16 * 60 * delta);
		
		visible = not (position.y < -(size.y + 20) or position.y > Global.game_size.y + 20)
