extends FunkinScript

@onready var special_anim:AnimatedSprite = $AnimatedSprite
@onready var flash:ColorRect = $ColorRect
var bg_glitch:AnimatedSprite

var game_shake:float = 0
var hud_shake:float = 0
var shake_duration:float = 0

func _ready_post():
	bg_glitch = game.stage.get_node("PB/Point3/BGGlitch")
	bg_glitch.modulate.a = 0
	
	var opponent_pos = game.stage.character_positions["opponent"].position
	special_anim.position.x = opponent_pos.x + 200
	special_anim.position.y = opponent_pos.y - 50
	special_anim.modulate.a = 0.1
	flash.color.a = 0

func _process_post(delta):
	if shake_duration <= 0:
		pass
		
	shake_duration -= delta
	
	if shake_duration <= 0:
		game.camera.offset.x = 0
		game.camera.offset.y = 0
	else:
		game.camera.offset.x = randf_range(-game_shake * 1280, game_shake * 1280)
		game.camera.offset.y = randf_range(-game_shake * 720, game_shake * 720)
		game.hud.offset.x += randf_range(-hud_shake * 1280, hud_shake * 1280)
		game.hud.offset.y += randf_range(-hud_shake * 720, hud_shake * 720)

func on_cpu_hit(note:Note):
	if note.alt_anim:
		if Conductor.cur_beat < 712:
			game_shake = 0.008
			hud_shake = 0.004
			shake_duration = 0.08
			
			game.health -= 0.016;
		elif Conductor.cur_beat < 728:
			game_shake = 0.012
			hud_shake = 0.01
			shake_duration = 0.06

func on_beat_hit(beat:int):
	match (beat):
		136:
			flash.color.a = 1
			create_tween().tween_property(flash, "color:a", 0.0, 0.4)
			
			bg_glitch.modulate.a = 0.8
		198:
			create_tween().tween_property(game.camera, "zoom", Vector2(0.9, 0.9), 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		231:
			special_anim.anim_player.play("scream")
			
			special_anim.modulate.a = 1
			game.opponent.modulate.a = 0
		232:
			special_anim.modulate.a = 0
			game.opponent.modulate.a = 1
			
			game.default_cam_zoom = 0.85
		256:
			game.default_cam_zoom = 0.7
		390:
			special_anim.modulate.a = 1
			game.opponent.modulate.a = 0
		392:
			special_anim.modulate.a = 0
			game.opponent.modulate.a = 1
			
			bg_glitch.modulate.a = 0
		420:
			create_tween().tween_property(game.camera, "zoom", Vector2(1, 1), 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		458:
			bg_glitch.modulate.a = 0.8
		468:
			create_tween().tween_property(game.camera, "zoom", Vector2(1, 1), 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		488:
			create_tween().tween_property(game.camera, "zoom", Vector2(1, 1), 0.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		520:
			bg_glitch.modulate.a = 0
		583:
			game.opponent.play_anim("windup", true)
			game.opponent.special_anim = true
		584:
			flash.color.a = 1
			create_tween().tween_property(flash, "color:a", 0.0, 0.4)
			
			special_anim.anim_player.play("s    u    c    c")
			
			special_anim.modulate.a = 1
			game.opponent.modulate.a = 0
			
			bg_glitch.modulate.a = 0.8
		680:
			flash.color.a = 1
			create_tween().tween_property(flash, "color:a", 0.0, 0.4)
			
			special_anim.anim_player.play("stunned")
		690:
			special_anim.modulate.a = 0
			game.opponent.modulate.a = 1
		696:
			bg_glitch.modulate.a = 0
			special_anim.anim_player.stop()
		712:
			create_tween().tween_property(game.stage.get_node("PB/Zero/CamTint"), "modulate:a", 0, 2.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		728:
			flash.color.a = 1
			create_tween().tween_property(flash, "color:a", 0.0, 0.4)
			
			special_anim.modulate.a = 1
			game.opponent.modulate.a = 0
			
			special_anim.anim_player.play("defeat")
			
			var node_paths = ["PB/Tenth/Obliv1", "PB/Point22/Obliv2", "PB/Point35/Obliv3", "PB/Point3/BGGlitch", "PB/Point45/Holo", "PB/Half/NeoBop"]
			for i in node_paths.size():
				if i >= 3:
					game.stage.get_node(node_paths[i]).modulate.a = 0
				else:
					game.stage.get_node(node_paths[i]).queue_free()
					
	if bg_glitch.modulate.a > 0 and game.cam_zooming and game.camera.zoom.x < 1.35 and beat < 600:
		var zoom_float = 0.010 + 0.015 * clamp(beat % 4, 0, 1)
		game.camera.zoom += Vector2(zoom_float, zoom_float)
		
	var zoom_check_1 = beat >= 456 and beat < 468 and game.cam_zooming and game.camera.zoom.x < 1.35
	var zoom_check_2 = beat >= 472 and beat < 488 and game.cam_zooming and game.camera.zoom.x < 1.35
	if zoom_check_1 or zoom_check_2:
		game.camera.zoom += Vector2(0.035, 0.035)
		game.hud.scale += Vector2(0.05, 0.05)
