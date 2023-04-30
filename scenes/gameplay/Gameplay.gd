extends MusicBeatScene
class_name Gameplay

var template_notes:Dictionary = {
	"default": preload("res://scenes/gameplay/notes/Default.tscn").instantiate(),
}
var OPPONENT_HEALTH_COLOR:StyleBoxFlat = preload("res://assets/styles/healthbar/opponent.tres")
var PLAYER_HEALTH_COLOR:StyleBoxFlat = preload("res://assets/styles/healthbar/player.tres")

var SONG:Chart = Global.SONG
var note_data_array:Array[SectionNote] = []

var starting_song:bool = true
var ending_song:bool = false
var in_cutscene = false

var scroll_speed:float = 2.7

var health:float = 1.0:
	set(v):
		health = clampf(v, 0.0, max_health)
		
var max_health:float = 2.0

var score:int = 0
var misses:int = 0
var combo:int = 0

var accuracy_pressed_notes:int = 0.0
var accuracy_total_hit:float = 0.0

var cam_bumping:bool = true
var cam_bumping_interval:int = 4
var cam_zooming:bool = true
var cam_switching:bool = true

var icon_bumping:bool = true
var icon_bumping_interval:int = 1
var icon_zooming:bool = true

var stage:Stage
var opponent:Character
var spectator:Character
var player:Character

var cpu_strums:StrumLine
var player_strums:StrumLine

var default_cam_zoom:float = 1.05
	
var accuracy:float:
	get:
		return accuracy_total_hit / accuracy_pressed_notes if \
				accuracy_total_hit != 0.0 and accuracy_pressed_notes != 0.0 else 0.0
		
var ui_skin:UISkin

@onready var camera:Camera2D = $Camera2D
@onready var hud:CanvasLayer = $HUD

@onready var strumlines:Node2D = $HUD/StrumLines

@onready var note_group:Node2D = $HUD/Notes
@onready var combo_group:Node2D = $Ratings

@onready var rating_template:VelocitySprite = $Ratings/RatingTemplate
@onready var combo_template:VelocitySprite = $Ratings/ComboTemplate

@onready var health_bar_bg:ColorRect = $HUD/HealthBar
@onready var health_bar:ProgressBar = $HUD/HealthBar/ProgressBar

@onready var cpu_icon:Sprite2D = $HUD/HealthBar/ProgressBar/CPUIcon
@onready var player_icon:Sprite2D = $HUD/HealthBar/ProgressBar/PlayerIcon
@onready var score_text:Label = $HUD/HealthBar/ScoreText

@onready var inst:AudioStreamPlayer = $Inst
@onready var voices:AudioStreamPlayer = $Voices

@onready var countdown_sprite:Sprite2D = $HUD/CountdownSprite

@onready var countdown_prepare_sound:AudioStreamPlayer = $CountdownSounds/Prepare
@onready var countdown_ready_sound:AudioStreamPlayer = $CountdownSounds/Ready
@onready var countdown_set_sound:AudioStreamPlayer = $CountdownSounds/Set
@onready var countdown_go_sound:AudioStreamPlayer = $CountdownSounds/Go

@onready var ms_display:Label = $HUD/MSDisplay
@onready var script_group:ScriptGroup = $ScriptGroup

var countdown_ticks:int = 3;

const ICON_DELTA_MULTIPLIER:float = 60 * 0.25
const ZOOM_DELTA_MULTIPLIER:float = 60 * 0.05

signal paused

func _ready() -> void:
	super._ready()
	get_tree().paused = false
	
	Audio.stop_music()
	
	Ranking.judgements = Ranking.default_judgements.duplicate(true)
	Ranking.ranks = Ranking.default_ranks.duplicate(true)
	
	if Global.SONG == null:
		Global.SONG = Chart.load_chart("tutorial", "hard")
		SONG = Global.SONG
		
	scroll_speed = SONG.scroll_speed
	if SettingsAPI.get_setting("scroll speed") > 0:
		match SettingsAPI.get_setting("scroll speed type").to_lower():
			"multiplier":
				scroll_speed *= SettingsAPI.get_setting("scroll speed")
			"constant":
				scroll_speed = SettingsAPI.get_setting("scroll speed")
	
	ui_skin = Global.ui_skins[SONG.ui_skin]
		
	inst.stream = load("res://assets/songs/"+SONG.name.to_lower()+"/Inst.ogg")
	inst.pitch_scale = Conductor.rate
	inst.finished.connect(end_song)
	
	voices.stream = load("res://assets/songs/"+SONG.name.to_lower()+"/Voices.ogg")
	voices.pitch_scale = Conductor.rate
		
	Conductor.map_bpm_changes(SONG)
	Conductor.change_bpm(SONG.bpm)
	Conductor.position = Conductor.crochet * -5
		
	for section in SONG.sections:
		for note in section.notes:
			# i can't use fucking duplicate
			# it fucks up!!!
			var n = SectionNote.new()
			n.time = note.time
			n.direction = note.direction
			n.length = note.length
			n.type = note.type
			n.alt_anim = note.alt_anim
			n.player_section = section.is_player
			
			var note_type_path:String = "res://scenes/gameplay/notes/"+note.type+".tscn"
			if not note.type in template_notes and ResourceLoader.exists(note_type_path):
				template_notes[note.type] = load(note_type_path).instantiate()
			
			note_data_array.append(n)
			
	note_data_array.sort_custom(func(a, b): return a.time < b.time)
	
	health = max_health * 0.5
	
	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	health_bar.value = health
	
	update_score_text()
	
	cpu_strums = load("res://scenes/gameplay/strumlines/"+str(SONG.key_count)+"K.tscn").instantiate()
	cpu_strums.note_skin = ui_skin
	strumlines.add_child(cpu_strums)
	
	player_strums = load("res://scenes/gameplay/strumlines/"+str(SONG.key_count)+"K.tscn").instantiate()
	player_strums.note_skin = ui_skin
	strumlines.add_child(player_strums)
	
	# load song scripts (put in assets/songs/SONGNAME)
	var script_path:String = "res://assets/songs/"+SONG.name.to_lower()+"/"
	var file_list:PackedStringArray = Global.list_files_in_dir(script_path)
	for item in file_list:
		if item.ends_with(".tscn") or item.ends_with(".tscn.remap"):
			var script:FunkinScript = FunkinScript.create(script_path+item.replace(".remap", ""), self)
			script_group.add_script(script)
	
	# load global scripts (put in assets/songs)
	var init_path:String = "res://assets/songs/"
	file_list = Global.list_files_in_dir(init_path)
	for item in file_list:
		if item.ends_with(".tscn") or item.ends_with(".tscn.remap"):
			var script:FunkinScript = FunkinScript.create(init_path+item.replace(".remap", ""), self)
			script_group.add_script(script)
	
	var strum_y:float = Global.game_size.y - 100.0 if SettingsAPI.get_setting("downscroll") else 100.0
	cpu_strums.position = Vector2((Global.game_size.x * 0.5) - (320.0 if not SettingsAPI.get_setting("centered notefield") else 10000.0), strum_y)
	player_strums.position = Vector2((Global.game_size.x * 0.5) + (320.0 if not SettingsAPI.get_setting("centered notefield") else 0.0), strum_y)
	
	var stage_path:String = "res://scenes/gameplay/stages/"+SONG.stage+".tscn"
	if ResourceLoader.exists(stage_path):
		stage = load(stage_path).instantiate()
	else:
		stage = load("res://scenes/gameplay/stages/stage.tscn").instantiate()
		
	default_cam_zoom = stage.default_cam_zoom
	camera.zoom = Vector2(default_cam_zoom, default_cam_zoom)
	camera.position_smoothing_speed *= Conductor.rate
	
	add_child(stage)
	
	var spectator_path:String = "res://scenes/gameplay/characters/"+SONG.spectator+".tscn"
	if ResourceLoader.exists(spectator_path):
		spectator = load(spectator_path).instantiate()
	else:
		spectator = load("res://scenes/gameplay/characters/bf.tscn").instantiate()
		
	spectator.position = stage.character_positions["spectator"].position
	add_child(spectator)
	
	var opponent_path:String = "res://scenes/gameplay/characters/"+SONG.opponent+".tscn"
	if ResourceLoader.exists(opponent_path):
		opponent = load(opponent_path).instantiate()
	else:
		opponent = load("res://scenes/gameplay/characters/bf.tscn").instantiate()
		
	opponent.position = stage.character_positions["opponent"].position
	add_child(opponent)
	
	if SONG.opponent == SONG.spectator:
		opponent.position = spectator.position
		
		spectator.queue_free()
		spectator = null
	
	var player_path:String = "res://scenes/gameplay/characters/"+SONG.player+".tscn"
	if ResourceLoader.exists(player_path):
		player = load(player_path).instantiate()
	else:
		player = load("res://scenes/gameplay/characters/bf.tscn").instantiate()
		
	player._is_true_player = true
	player.position = stage.character_positions["player"].position
	add_child(player)
	
	cpu_icon.texture = opponent.health_icon
	cpu_icon.hframes = opponent.health_icon_frames
	
	player_icon.texture = player.health_icon
	player_icon.hframes = player.health_icon_frames
	
	OPPONENT_HEALTH_COLOR.bg_color = opponent.health_color
	PLAYER_HEALTH_COLOR.bg_color = player.health_color
	
	if SettingsAPI.get_setting("downscroll"):
		health_bar_bg.position.y = 60
	
	if SettingsAPI.get_setting("judgement camera").to_lower() == "hud":
		remove_child(combo_group)
		hud.add_child(combo_group)
		
	combo_group.move_to_front()
	update_camera()
	
	for i in player_strums.get_child_count():
		pressed.append(false)
		
	SettingsAPI.setup_binds()
	
	position_icons()
	start_countdown()
	
	stage.callv("_ready_post", [])
	script_group.call_func("_ready_post", [])
	print(template_notes)
	
func start_cutscene(postfix:String = "-start"):
	var cutscene_path = "res://scenes/gameplay/cutscenes/" + SONG.name.to_lower() + postfix + ".tscn"
	if ResourceLoader.exists(cutscene_path):
		in_cutscene = true
		hud.add_child(load(cutscene_path).instantiate())
		get_tree().paused = true
		return true
		
	return false
		
# yo thanks srt for doing it for me i think i was boutta
# forgor anyway :skoil: ~swordcube
func start_countdown():
	start_cutscene()
	countdown_sprite.scale = Vector2(ui_skin.countdown_scale, ui_skin.countdown_scale)
	countdown_sprite.texture_filter = TEXTURE_FILTER_LINEAR if ui_skin.antialiasing else TEXTURE_FILTER_NEAREST
	
	countdown_prepare_sound.stream = ui_skin.prepare_sound
	countdown_ready_sound.stream = ui_skin.ready_sound
	countdown_set_sound.stream = ui_skin.set_sound
	countdown_go_sound.stream = ui_skin.go_sound
	get_tree().create_timer((Conductor.crochet / 1000) / Conductor.rate, false).timeout.connect(countdown_tick)
	
	stage.callv("on_start_countdown", [])
	script_group.call_func("on_start_countdown", [])

var countdown_tween:Tween

func countdown_tick():
	character_bop()
	
	if countdown_tween != null:
		countdown_tween.stop()
		
	if countdown_ticks < 3:
		countdown_tween = create_tween()
	
	match countdown_ticks:
		3:
			countdown_prepare_sound.play()
		2:
			countdown_ready_sound.play()
	
			countdown_sprite.texture = ui_skin.ready_texture
			countdown_tween.tween_property(countdown_sprite, "modulate:a", 0.0, (Conductor.crochet / 1000) / Conductor.rate)
			countdown_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		1:
			countdown_set_sound.play()
			
			countdown_sprite.modulate.a = 1.0
			countdown_sprite.texture = ui_skin.set_texture
			countdown_tween.tween_property(countdown_sprite, "modulate:a", 0.0, (Conductor.crochet / 1000) / Conductor.rate)
			countdown_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		0:
			countdown_go_sound.play()
			
			countdown_sprite.modulate.a = 1.0
			countdown_sprite.texture = ui_skin.go_texture
			countdown_tween.tween_property(countdown_sprite, "modulate:a", 0.0, (Conductor.crochet / 1000) / Conductor.rate)
			countdown_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
			
	stage.callv("on_countdown_tick", [countdown_ticks, countdown_tween])
	script_group.call_func("on_countdown_tick", [countdown_ticks, countdown_tween])
	
	countdown_ticks -= 1
	if countdown_ticks >= 0:
		get_tree().create_timer((Conductor.crochet / 1000) / Conductor.rate, false).timeout.connect(countdown_tick)

func start_song():
	character_bop()
	
	starting_song = false
	Conductor.position = 0.0
	
	inst.play()
	voices.play()
	
	stage.callv("on_start_song", [])
	script_group.call_func("on_start_song", [])
	
func end_song():
	if not ending_song:
		ending_song = true
		if start_cutscene("-end"):
			return
	
	stage.callv("on_end_song", [])
	var ret:Variant = script_group.call_func("on_end_song", [])
	if ret == false: return
	if score > HighScore.get_score(SONG.name,Global.current_difficulty):
		HighScore.set_score(SONG.name,Global.current_difficulty,score)
	
	if Global.queued_songs.size() > 0:
		Global.SONG = Chart.load_chart(Global.queued_songs[0], Global.current_difficulty)
		Global.queued_songs.remove_at(0)
		Global.switch_scene("res://scenes/gameplay/Gameplay.tscn")
	else:
		Global.switch_scene("res://scenes/FreeplayMenu.tscn" if !Global.is_story_mode else "res://scenes/StoryMenu.tscn")
	
func beat_hit(beat:int):
	script_group.call_func("on_beat_hit", [beat])
	
	if icon_bumping and icon_bumping_interval > 0 and beat % icon_bumping_interval == 0:
		cpu_icon.scale += Vector2(0.2, 0.2)
		player_icon.scale += Vector2(0.2, 0.2)
		position_icons()
	
	if cam_bumping and cam_bumping_interval > 0 and beat % 4 == 0:
		camera.zoom += Vector2(0.015, 0.015)
		hud.scale += Vector2(0.03, 0.03)
		position_hud()
		
	character_bop()
	
	script_group.call_func("on_beat_hit_post", [beat])
	
func step_hit(step:int):
	script_group.call_func("on_step_hit", [step])
	
	if not ending_song and ((not Conductor.is_sound_synced(inst)) or (voices.stream != null and (not Conductor.is_sound_synced(voices)) and voices.get_playback_position() < voices.stream.get_length())):
		resync_vocals()
		
	script_group.call_func("on_step_hit_post", [step])

func section_hit(section:int):
	if not range(SONG.sections.size()).has(section): return
	
	script_group.call_func("on_section_hit", [section])

	if cam_switching:
		update_camera(section)
		
	if SONG.sections[section].change_bpm:
		Conductor.change_bpm(SONG.sections[section].bpm)

	script_group.call_func("on_section_hit_post", [section])

func character_bop():
	if opponent != null and opponent.dance_on_beat and not opponent.last_anim.begins_with("sing"):
		opponent.dance()
		
	if spectator != null and spectator.dance_on_beat and not spectator.last_anim.begins_with("sing"):
		spectator.dance()
		
	if player != null and player.dance_on_beat and not player.last_anim.begins_with("sing"):
		player.dance()
		
	script_group.call_func("on_character_bop", [])
	
func update_camera(sec:int = 0):
	if not range(SONG.sections.size()).has(sec): return
	
	var cur_sec:Section = SONG.sections[sec]
	if cur_sec != null and cur_sec.is_player:
		camera.position = player.get_camera_pos()
	else:
		camera.position = opponent.get_camera_pos()
		
	script_group.call_func("on_update_camera", [])
	
func position_hud():
	hud.offset.x = (hud.scale.x - 1.0) * -(Global.game_size.x * 0.5)
	hud.offset.y = (hud.scale.y - 1.0) * -(Global.game_size.y * 0.5)
		
func resync_vocals():
	if ending_song: return
	
	inst.stop()
	voices.stop()
	
	inst.play(Conductor.position / 1000.0)
	voices.play(Conductor.position / 1000.0)
	
	inst.seek(Conductor.position / 1000.0)
	voices.seek(Conductor.position / 1000.0)
	
	script_group.call_func("on_resync_vocals", [])

func key_from_event(event:InputEventKey):
	var data:int = -1
	for i in player_strums.controls.size():
		if event.is_action_pressed(player_strums.controls[i]) or event.is_action_released(player_strums.controls[i]):
			data = i
			break
			
	return data
	
var pressed:Array[bool] = []
	
func _input(event):
	if event is InputEventKey:
		var key_event:InputEventKey = event
		var data:int = key_from_event(key_event)
		
		if data > -1:
			pressed[data] = event.is_pressed()
		
		if data == -1 or not Input.is_action_just_pressed(player_strums.controls[data]):
			return
		
		var receptor:Receptor = player_strums.get_child(data)
		receptor.play_anim("pressed")
		
		var possible_notes:Array[Note] = []
		for note in note_group.get_children().filter(func(note:Note):
			return (note.direction == data and !note.too_late and note.can_be_hit and note.must_press and not note.was_good_hit)	
		): possible_notes.append(note)
		
		possible_notes.sort_custom(sort_hit_notes)
		
		var dont_hit:Array[bool] = []
		for i in player_strums.get_child_count():
			dont_hit.append(false)
			
		if possible_notes.size() > 0:
			for note in possible_notes:
				if not dont_hit[data] and note.direction == data:
					dont_hit[data] = true
					
				receptor.play_anim("confirm")
				good_note_hit(note)
				
				# fuck you stacked notes
				# they can go kiss my juicy ass
				if possible_notes.size() > 1:
					for i in possible_notes.size():
						if i == 0: continue
						var bad_note:Note = possible_notes[i]
						if absf(bad_note.time - note.time) <= 5 and note.direction == data:
							bad_note.queue_free()
					
				break
		else:
			if not SettingsAPI.get_setting("ghost tapping"):
				fake_miss(data)
				if SettingsAPI.get_setting("miss sounds"):
					Audio.play_sound("missnote"+str(randi_range(1, 3)), randf_range(0.1, 0.3))
					
			script_group.call_func("on_ghost_tap", [data])
			
func fake_miss(direction:int = -1):
	health -= 0.0475
	misses += 1
	score -= 10
	combo = 0
	accuracy_pressed_notes += 1
	voices.volume_db = -80
	update_score_text()
	
	if direction < 0: return
	
	var sing_anim:String = "sing"+player_strums.get_child(direction).direction.to_upper()
	player.play_anim(sing_anim+"miss", true)
	player.hold_timer = 0.0
		
func sort_hit_notes(a:Note, b:Note):
	if not a.should_hit and b.should_hit: return 1
	elif a.should_hit and not b.should_hit: return -1
	
	return a.time < b.time

func pop_up_score(judgement:Judgement) -> void:
	var pop_up_score_tweener:Tween = create_tween().set_parallel()
	
	accuracy_pressed_notes += 1
	accuracy_total_hit += judgement.accuracy_gain
	score += judgement.score
	combo += 1
	
	display_judgement(judgement, pop_up_score_tweener)
	display_combo(pop_up_score_tweener)
	
	script_group.call_func("on_pop_up_score", [combo])
	
func display_judgement(judgement:Judgement, tween:Tween):	
	var rating_spr:VelocitySprite = rating_template.duplicate()
	rating_spr.texture = load(ui_skin.rating_texture_path+judgement.name+".png")
	rating_spr.visible = true
	rating_spr.scale = Vector2(ui_skin.rating_scale, ui_skin.rating_scale)
	rating_spr.texture_filter = TEXTURE_FILTER_LINEAR if ui_skin.rating_antialiasing else TEXTURE_FILTER_NEAREST
	
	rating_spr.acceleration.y = 550
	rating_spr.velocity.y = -randi_range(140, 175)
	rating_spr.velocity.x = -randi_range(0, 10)
	combo_group.add_child(rating_spr)
	
	tween.tween_property(rating_spr, "modulate:a", 0.0, 0.2) \
			.set_delay(Conductor.crochet * 0.001).finished.connect(func(): rating_spr.queue_free())
	
func display_combo(tween:Tween):
	var separated_score:String = Global.add_zeros(str(combo), 3)
	for i in len(separated_score):
		var num_score:VelocitySprite = combo_template.duplicate()
		num_score.texture = load(ui_skin.combo_texture_path+"num"+separated_score.substr(i, 1)+".png")
		num_score.position = Vector2((43 * i) - 90, 80)
		num_score.visible = true
		num_score.scale = Vector2(ui_skin.combo_scale, ui_skin.combo_scale)
		num_score.texture_filter = TEXTURE_FILTER_LINEAR if ui_skin.combo_antialiasing else TEXTURE_FILTER_NEAREST
		
		num_score.acceleration.y = randi_range(200, 300)
		num_score.velocity.y = -randi_range(140, 160)
		num_score.velocity.x = randi_range(-5, 5)
		combo_group.add_child(num_score)
		
		tween.tween_property(num_score, "modulate:a", 0.0, 0.2) \
			.set_delay(Conductor.crochet * 0.002).finished.connect(func(): num_score.queue_free())
		
var ms_tween:Tween
		
func good_note_hit(note:Note):
	if note.was_good_hit: return
	
	
	voices.volume_db = 0
	
	var note_diff:float = (note.time - Conductor.position) / Conductor.rate
	var judgement:Judgement = Ranking.judgement_from_time(note_diff)
	
	if SettingsAPI.get_setting("show ms on note hit"):
		var downscroll_mult:int = 1 if SettingsAPI.get_setting("downscroll") else -1
		ms_display.modulate = judgement.color
		ms_display.text = str(note_diff).pad_decimals(2)+"ms"
		ms_display.position.x = player_strums.position.x - (ms_display.size.x * 0.5)
		ms_display.position.y = player_strums.position.y - (ms_display.size.y * 0.5) - (110.0 * downscroll_mult)
		ms_display.visible = true
		
		if ms_tween != null:
			ms_tween.stop()
		
		ms_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		ms_tween.tween_property(ms_display, "position:y", ms_display.position.y + 10.0, 0.3)
		ms_tween.tween_property(ms_display, "modulate:a", 0.0, 0.3).set_delay(0.5)
		script_group.call_func("on_show_ms", [])
		
	if judgement.do_splash and SettingsAPI.get_setting("note splashes"):
		var receptor:Receptor = player_strums.get_child(note.direction)
		receptor.splash.frame = 0
		var anim:String = "note impact "+str(randi_range(1, 2))+" "+Global.note_directions[note.direction]
		receptor.splash.play(anim)
		receptor.splash.visible = true
		script_group.call_func("on_spawn_note_splash", [receptor.splash])
	
	if note.should_hit:
		pop_up_score(judgement)	
	else:
		combo = 0
		accuracy_pressed_notes += 1
		
	update_score_text()
	
	note.was_good_hit = true
	
	var sing_anim:String = "sing"+player_strums.get_child(note.direction).direction.to_upper()
	if note.alt_anim:
		sing_anim += "-alt"
	player.play_anim(sing_anim, true)
	player.hold_timer = 0.0
	
	health += 0.023*note.health_gain_mult
	
	if note.length <= 0:
		note._player_hit()
		note._note_hit(true)
		script_group.call_func("on_note_hit", [note])
		script_group.call_func("on_player_hit", [note])
		note.queue_free()
	else:
		note.anim_sprite.visible = false
		note.length += note_diff
		note._player_hit()
		note._note_hit(true)
		script_group.call_func("on_note_hit", [note])
		script_group.call_func("on_player_hit", [note])

func position_icons():
	var icon_offset:int = 26
	var percent:float = (health_bar.value / health_bar.max_value) * 100
	
	var cpu_icon_width:float = (cpu_icon.texture.get_width() / cpu_icon.hframes) * cpu_icon.scale.x

	player_icon.position.x = (health_bar.size.x * ((100 - percent) * 0.01)) - icon_offset
	cpu_icon.position.x = (health_bar.size.x * ((100 - percent) * 0.01)) - (cpu_icon_width - icon_offset)
	script_group.call_func("on_position_icons", [])

func update_score_text():
	score_text.text = "Score: "+str(score)+" - Misses: "+str(misses)+" - Accuracy: "+str(snapped(accuracy * 100.0, 0.01))+"% ["+Ranking.rank_from_accuracy(accuracy * 100.0).name+"]"
	script_group.call_func("on_update_score_text", [])

func game_over():
	Global.death_character = player.death_character
	Global.death_camera_zoom = camera.zoom
	Global.death_camera_pos = camera.position
	Global.death_char_pos = player.position
	
	Global.death_music = player.death_music
	Global.death_sound = player.death_sound
	Global.retry_sound = player.retry_sound
	
	get_tree().change_scene_to_file("res://scenes/gameplay/GameOver.tscn")
	
func _process(delta:float) -> void:
	if in_cutscene:
		get_tree().paused = true
	else:
		get_tree().paused = false
	
	if not pressed.has(true) and player.last_anim.begins_with("sing") and player.hold_timer >= Conductor.step_crochet * player.sing_duration * 0.0011:
		player.hold_timer = 0.0
		player.dance()
		
	if health <= 0:
		game_over()
	
	var percent:float = (health / max_health) * 100.0
	health_bar.max_value = max_health
	health_bar.value = health
	
	cpu_icon.health = 100.0 - percent
	player_icon.health = percent
	
	if icon_zooming:
		var icon_speed:float = clampf((delta * ICON_DELTA_MULTIPLIER) * Conductor.rate, 0.0, 1.0)
		cpu_icon.scale = lerp(cpu_icon.scale, Vector2.ONE, icon_speed)
		player_icon.scale = lerp(player_icon.scale, Vector2.ONE, icon_speed)
		position_icons()
	
	if cam_zooming:
		var camera_speed:float = clampf((delta * ZOOM_DELTA_MULTIPLIER) * Conductor.rate, 0.0, 1.0)
		camera.zoom = lerp(camera.zoom, Vector2(default_cam_zoom, default_cam_zoom), camera_speed)
		hud.scale = lerp(hud.scale, Vector2.ONE, camera_speed)
		position_hud()
	
	if not ending_song:
		Conductor.position += (delta * 1000.0) * Conductor.rate
		if Conductor.position >= 0.0 and starting_song:
			start_song()
	
	for note in note_data_array:
		if note.time > Conductor.position + (2500 / (scroll_speed / Conductor.rate)): break
		
		var key_count:int = 4
		var is_player_note:bool = note.player_section
		
		if note.direction > key_count - 1:
			is_player_note = !note.player_section
			
		var instance_type:String = note.type
		if not note.type in template_notes:
			print("type not found " + instance_type)
			instance_type = "default"
			
		var new_note:Note = template_notes[instance_type].duplicate()
		new_note.position = Vector2(-9999, -9999)
		new_note.time = note.time
		new_note.direction = note.direction % key_count
		new_note.length = note.length * 0.85
		new_note.strumline = player_strums if is_player_note else cpu_strums
		new_note.must_press = is_player_note
		new_note.note_skin = ui_skin
		
		if not new_note.alt_anim:
			new_note.alt_anim = note.alt_anim or (note.type == "Alt Animation")
		
		note_group.add_child(new_note)
		script_group.call_func("on_note_spawn", [new_note])
		
		note_data_array.erase(note)
	
	for sprite in combo_group.get_children():
		VelocitySprite._process_sprite(sprite, delta)
	
	if Input.is_action_just_pressed("ui_pause") and not Global.transitioning:
		emit_signal("paused")
		add_child(load("res://scenes/gameplay/PauseMenu.tscn").instantiate())
	
	stage.callv("_process_post", [delta])
	script_group.call_func("_process_post", [delta])

func _exit_tree():
	script_group.call_func("on_destroy", [])
	script_group.call_func("on_exit_tree", [])
	script_group.queue_free()
