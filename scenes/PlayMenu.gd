extends Node2D

var selected_something:bool = false
var cur_selected:int = 0

@onready var camera = $Camera2D

@onready var scroll = $ScrollWorkaround
@onready var bg = $ScrollWorkaround/PlayBg
@onready var checker_pattern = $CheckerPattern
@onready var button_stuff = $ButtonStuff
@onready var buttons = $ButtonStuff/Buttons
@onready var scroll2 = $ButtonStuff/ScrollWorkaround2
@onready var bottom = $ButtonStuff/ScrollWorkaround2/PlayBottom

func _ready():
	Audio.play_music("freakyMenu")
	Conductor.change_bpm(Audio.music.stream.bpm)
	
	var tween = get_tree().create_tween().set_parallel()
	
	for i in 3:
		var item = buttons.get_child(i) as AnimatedSprite2D
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(item, "modulate:a", 1.0, 1.3)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(camera, "zoom", Vector2.ONE, 1.2)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(bg, "position:y", 360.0, 1)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(bottom, "modulate:a", 1.0, 1)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(checker_pattern, "modulate:a", 1.0, 1.15)
	
	change_selection(0)

func _process(delta):
	button_stuff.scale = camera.zoom
	button_stuff.offset.x = (button_stuff.scale.x - 1.0) * -(Global.game_size.x * 0.5)
	button_stuff.offset.y = (button_stuff.scale.y - 1.0) * -(Global.game_size.y * 0.5)
	
	checker_pattern.position.x -= 0.03 * 60 * delta;
	checker_pattern.position.y -= 0.2 * 60 * delta;
	checker_pattern.position.x = wrapf(checker_pattern.position.x, -125.0, 0.0)
	checker_pattern.position.y = wrapf(checker_pattern.position.y, -88.0, 0.0)
	
	var cur_button = buttons.get_child(cur_selected)
	scroll.position.y = -cur_button.position.y * 0.03
	scroll2.position.y = 60 - cur_button.position.y * 0.1
	
	var x_lerp = 0.4 * 60 * delta
	var y_lerp = 0.07 * 60 * delta
	
	for i in buttons.get_child_count():
		var scale = 0.5 if cur_selected != i else 1.25
		
		var button = buttons.get_child(i) as AnimatedSprite2D
		button.scale.x = lerpf(button.scale.x, scale, x_lerp)
		button.scale.y = lerpf(button.scale.y, scale, y_lerp)
			
		button.position.x = lerpf(button.position.x, 640 + (i - cur_selected) * 370, y_lerp)
		button.position.y = Global.game_size.y - 290 * button.scale.y * 0.5
	
	if selected_something: return
	
	if Input.is_action_just_pressed("ui_cancel"):
		Audio.play_sound("cancelMenu")
		Global.switch_scene("res://scenes/MainMenu.tscn")
	
	if Input.is_action_just_pressed("ui_left"):
		change_selection(-1)
	elif Input.is_action_just_pressed("ui_right"):
		change_selection(1)
		
	if Input.is_action_just_pressed("ui_accept"):
		Audio.play_sound("confirmMenu")
		selected_something = true
		
		var button = buttons.get_child(cur_selected)
		var tween = get_tree().create_tween().set_parallel()
		
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(buttons, "position:y", -48000 + button.position.y, 2.5)
		
		for da_button in buttons.get_children():
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(da_button, "scale:y", 2000, 1.4)
			
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(bg, "position:y", -365, 1.6)
			
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(camera, "zoom", Vector2(12, 12), 0.8).set_delay(0.4)
			
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_QUART)
		tween.tween_property(bottom, "modulate:a", 0.0, 1.6).set_delay(0.3)
		
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_QUART)
		tween.tween_property(checker_pattern, "modulate:a", 0.0, 1.6).set_delay(0.3)
			
		await get_tree().create_timer(0.7).timeout
		
		var button_name:StringName = button.name
		match str(button_name):
			"Story":
				Global.switch_scene("res://scenes/StoryMenu.tscn")
			"Freeplay":
				Global.switch_scene("res://scenes/FreeplayMenu.tscn")

func change_selection(change:int = 0):
	cur_selected = wrapi(cur_selected + change, 0, buttons.get_child_count())
	
	var prefixes = ["week", "freeplay"];
	for i in buttons.get_child_count():
		var button:AnimatedSprite2D = buttons.get_child(i)
		button.play(prefixes[i] + (" select" if cur_selected == i else " idle"))
		
	Audio.play_sound("scrollMenu")
