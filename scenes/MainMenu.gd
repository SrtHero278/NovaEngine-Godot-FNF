extends MusicBeatScene

@onready var button_anim:AnimationPlayer = $ButtonFlashing

@onready var menu_bg = $MenuBG
@onready var checker_pattern = $CheckerPattern

@onready var camera:Camera2D = $Camera2D
@onready var button_stuff = $ButtonStuff
@onready var buttons:Node2D = $ButtonStuff/Buttons

var cur_selected:int = 0
var selected_something:bool = false

var scroll_y:float = 0;

func _ready():
	super._ready()
	get_tree().paused = false
	Audio.play_music("freakyMenu")
	Conductor.change_bpm(Audio.music.stream.bpm)
	
	var tween = get_tree().create_tween().set_parallel()
	
	for i in 3:
		var item = buttons.get_child(i) as AnimatedSprite2D
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(item, "position:x", 517 * 0.25 + (i * 210) - 30, 1.3)
		
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(menu_bg, "rotation_degrees", 0, 1)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(camera, "zoom", Vector2.ONE, 1.1)
	
	change_selection()
	
func _process(delta):
	var lerp_val:float = clampf((delta * 2.5), 0.0, 1.0)
	menu_bg.position.y = lerpf(menu_bg.position.y, scroll_y + 360, lerp_val)
	
	button_stuff.scale = camera.zoom
	button_stuff.offset.x = (button_stuff.scale.x - 1.0) * -(Global.game_size.x * 0.5)
	button_stuff.offset.y = (button_stuff.scale.y - 1.0) * -(Global.game_size.y * 0.5)
	
	checker_pattern.position.x -= 27 * delta;
	checker_pattern.position.y -= 9.6 * delta;
	checker_pattern.position.x = wrapf(checker_pattern.position.x, -125.0, 0.0)
	checker_pattern.position.y = wrapf(checker_pattern.position.y, -88.0, 0.0)
	
	if selected_something: return
	
	if Input.is_action_just_pressed("ui_cancel"):
		Audio.play_sound("cancelMenu")
		Global.switch_scene("res://scenes/TitleScreen.tscn")
		
	if Input.is_action_just_pressed("switch_mod"):
		add_child(load("res://scenes/ModsMenu.tscn").instantiate())
	
	if Input.is_action_just_pressed("ui_up"):
		change_selection(-1)
		
	if Input.is_action_just_pressed("ui_down"):
		change_selection(1)
		
	if Input.is_action_just_pressed("ui_accept"):
		Audio.play_sound("confirmMenu")
		selected_something = true
		
		# button_anim.root_node = buttons.get_child(cur_selected).get_path()
		# button_anim.play("flash")
		
		var tween = get_tree().create_tween().set_parallel()
		
		for i in buttons.get_child_count():
			var button:AnimatedSprite2D = buttons.get_child(i)
			
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_BACK)
			tween.tween_property(button, "position:x", -600.0, 0.4)
			
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(menu_bg, "rotation_degrees", 45, 0.8)
			
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_EXPO)
		tween.tween_property(camera, "zoom", Vector2(5, 5), 0.8)
			
		var timer:SceneTreeTimer = get_tree().create_timer(0.7)
		timer.timeout.connect(func():
			var button:StringName = buttons.get_child(cur_selected).name
			match str(button):
				"Play":
					Global.switch_scene("res://scenes/PlayMenu.tscn")
				
				"Freeplay":
					Global.switch_scene("res://scenes/FreeplayMenu.tscn")
					
				"Options":
					Global.switch_scene("res://scenes/OptionsMenu.tscn")
					
				_: print("bro how the fuck did you select "+button+"???")
		)
		
func _input(e):
	if not e is InputEventMouseButton: return
	var event:InputEventMouseButton = e
	if not event.pressed: return
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			change_selection(-1)
			
		MOUSE_BUTTON_WHEEL_DOWN:
			change_selection(1)
	
func change_selection(change:int = 0):
	cur_selected = wrapi(cur_selected + change, 0, buttons.get_child_count())
	
	var prefixes = ["play", "support", "options"];
	for i in buttons.get_child_count():
		var button:AnimatedSprite2D = buttons.get_child(i)
		button.play(prefixes[i] + (" select" if cur_selected == i else " idle"))
		
	Audio.play_sound("scrollMenu")
	scroll_y = (-240 + buttons.get_child(cur_selected).position.y) * -0.1
