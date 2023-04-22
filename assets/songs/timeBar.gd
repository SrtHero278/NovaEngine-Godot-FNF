extends FunkinScript

var hud:CanvasLayer
var time_bar_bg:ColorRect
var time_bar:ProgressBar

func _ready_post():
	hud = game.get_node("HUD")
	time_bar_bg = hud.get_node("TimeBar")
	time_bar = time_bar_bg.get_node("ProgressBar")
	
	var time_color = game.PLAYER_HEALTH_COLOR.bg_color if game.SONG.sections[Conductor.cur_section] != null and game.SONG.sections[Conductor.cur_section].is_player else game.OPPONENT_HEALTH_COLOR.bg_color
	time_color.v = clamp(time_color.v, 0.35, 1)
	time_bar.modulate = time_color
	time_bar.max_value = game.inst.stream.get_length()

func _process(delta):
	time_bar.value = Conductor.position / 1000

func on_beat_hit(cur_beat:int):
	if game.cam_switching:
		var time_color = game.PLAYER_HEALTH_COLOR.bg_color if game.SONG.sections[Conductor.cur_section] != null and game.SONG.sections[Conductor.cur_section].is_player else game.OPPONENT_HEALTH_COLOR.bg_color
		time_color.v = clamp(time_color.v, 0.35, 1)
		game.create_tween().tween_property(time_bar, "modulate", time_color, Conductor.crochet / 4000)
