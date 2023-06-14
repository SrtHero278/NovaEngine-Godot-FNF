extends MusicBeatScene

var cur_icon:int = -1
var cur_selected:int = 0
var cur_difficulty:int = 1

var intended_score:int = 0
var lerp_score:float = 0.0

var song_meta:SongMetaData = SongMetaData.new()

@export var song_list:FreeplaySongList = FreeplaySongList.new()

@onready var checker_pattern = $CheckerPattern
@onready var bg:Sprite2D = $bg
@onready var songs:CanvasGroup = $Songs
@onready var song_template:FreeplayAlphabet = $__TemplateSong__

@onready var song_tracks:Node = $SongTracks

@onready var bottom:Sprite2D = $FreeBottom
@onready var score_text:Label = $FreeBottom/ScoreText
@onready var diff_sprite:AnimatedSprite2D = $FreeBottom/DiffSprite

@onready var disc:AnimatedSprite2D = $Disc
@onready var disc_icon:HealthIcon = $Disc/DiscIcon

@onready var gameplay_modifiers:Panel = $GameplayModifiers

@onready var playback_rate_slider:DisplaySliderOptionless = $"GameplayModifiers/Control/Playback Rate"
@onready var health_gain_mult_slider:DisplaySliderOptionless = $"GameplayModifiers/Control/Health Gain Mult"
@onready var health_loss_mult_slider:DisplaySliderOptionless = $"GameplayModifiers/Control/Health Loss Mult"

@onready var camera = $Camera2D

# info about chart loaded from playing song lol (kinda caching type beat ig)
var loaded_chart_info:Dictionary = {
	"name": null,
	"difficulty": null,
}

func _ready():
	Input.use_accumulated_input
	super._ready()
	disc.play("agoti")
	start_tween()
	Audio.play_music("freakyMenu")
	Conductor.change_bpm(Audio.music.stream.bpm)

	for i in song_list.songs.size():
		var meta:FreeplaySong = song_list.songs[i]
		
		var song:FreeplayAlphabet = song_template.duplicate()
		
		if meta.display_name == "dadbattle" and randf_range(0, 100) < 0.1:
			meta.display_name = "baddattle"
		
		song.text = meta.display_name if meta.display_name != null and len(meta.display_name) > 0 else meta.song
		song.position = Vector2(0, (70 * i) + 30)
		song.visible = true
		song.is_menu_item = true
		song.target_y = i
		song.is_template = false
		songs.add_child(song)
		
	change_selection()
	position_highscore()
	update_sliders()
	Conductor.beat_hit.connect(on_beat_hit)

func change_selection(change:int = 0):
	cur_selected = wrapi(cur_selected + change, 0, song_list.songs.size())
	
	for i in songs.get_child_count():
		var song:FreeplayAlphabet = songs.get_child(i)
		song.target_y = i - cur_selected
		song.modulate.a = 1.0 if cur_selected == i else 0.6
		
	Audio.play_sound("scrollMenu")
	change_difficulty()
	
	disc_icon.texture = song_list.songs[cur_selected].character_icon
	disc_icon.hframes = song_list.songs[cur_selected].icon_frames
		
var diff_move:float = 0
func change_difficulty(change:int = 0):
	var diff_amount:int = song_list.songs[cur_selected].difficulties.size()
	cur_difficulty = wrapi(cur_difficulty + change, 0, diff_amount)
	var diff_name:String = song_list.songs[cur_selected].difficulties[cur_difficulty].to_upper()
	
	intended_score = HighScore.get_score(song_list.songs[cur_selected].song,diff_name)
	diff_sprite.play(diff_name)
	
	diff_move = 1
	
	position_highscore()
	
func _input(e):
	if not e is InputEventMouseButton: return
	var event:InputEventMouseButton = e
	if not event.pressed: return
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			change_selection(-1)
			
		MOUSE_BUTTON_WHEEL_DOWN:
			change_selection(1)
	
func position_highscore():
	score_text.text = "PERSONAL BEST:"+str(floor(lerp_score))
	
	await get_tree().create_timer(0.001).timeout
	
var playing_song:bool = false
	
func _physics_process(delta):
	if not playing_song: return
	for t in song_tracks.get_children():
		var track:AudioStreamPlayer = t
		if not track.is_playing():
			playing_song = false
			get_tree().create_timer((song_meta.end_offset/1000) / Conductor.rate).timeout.connect(func(): Audio.play_music("freakyMenu"))
			break

func update_sliders():
	playback_rate_slider.value = Conductor.rate
	health_gain_mult_slider.value = Global.health_gain_mult
	health_loss_mult_slider.value = Global.health_loss_mult

func _process(delta):
	Conductor.rate = playback_rate_slider.value
	Global.health_gain_mult = health_gain_mult_slider.value
	Global.health_loss_mult = health_loss_mult_slider.value
	
	lerp_score = lerpf(lerp_score, intended_score, clampf(delta * 60 * 0.4, 0.0, 1.0))
	position_highscore()
	
	disc.rotation_degrees += 0.6 * 60 * delta
	checker_pattern.position.x += 0.27 * 60 * delta
	checker_pattern.position.y -= 0.63 * 60 * delta
	checker_pattern.position.x = wrapf(checker_pattern.position.x, -125.0, 0.0)
	checker_pattern.position.y = wrapf(checker_pattern.position.y, -88.0, 0.0)
	
	diff_move = clampf(diff_move - delta * 25, 0.0, 1.0);
	diff_sprite.position.y = lerpf(1, -29, diff_move)
	diff_sprite.modulate.a = 1 - diff_move
	
	if Input.is_action_just_pressed("switch_mod"):
		add_child(load("res://scenes/ModsMenu.tscn").instantiate())
	
	if Input.is_action_just_pressed("ui_up"):
		change_selection(-1)
		
	if Input.is_action_just_pressed("ui_down"):
		change_selection(1)
		
	if Input.is_action_just_pressed("ui_left"):
		change_difficulty(-1)
		
	if Input.is_action_just_pressed("ui_right"):
		change_difficulty(1)
		
	if Input.is_action_just_pressed("open_gameplay_modifiers"):
		gameplay_modifiers.visible = !gameplay_modifiers.visible
	
	if Input.is_action_just_pressed("space_bar"):
		Audio.stop_music()
		
		if SettingsAPI.get_setting("freeplay icon bumping"):
			cur_icon = cur_selected
			
			Global.current_difficulty = song_list.songs[cur_selected].difficulties[cur_difficulty]
			Global.SONG = Chart.load_chart(song_list.songs[cur_selected].song, Global.current_difficulty)
			
			loaded_chart_info = {
				"name": song_list.songs[cur_selected].song,
				"difficulty": Global.current_difficulty,
			}
		
		Conductor.change_bpm(Global.SONG.bpm)
		
		var meta_path:String = "res://assets/songs/%s/meta" % song_list.songs[cur_selected].song.to_lower()
		if ResourceLoader.exists(meta_path + ".tres"):
			song_meta = load(meta_path + ".tres")
			
		if ResourceLoader.exists(meta_path + ".res"):
			song_meta = load(meta_path + ".res")
			
		playing_song = true
		
		while song_tracks.get_child_count() > 0:
			var m = song_tracks.get_child(0)
			m.queue_free()
			song_tracks.remove_child(m)
			
		var music_path:String = "res://assets/songs/%s/audio/" % song_list.songs[cur_selected].song.to_lower()
		if DirAccess.dir_exists_absolute(music_path):
			var dir := DirAccess.open(music_path)
			for file in dir.get_files():
				var music:AudioStreamPlayer = AudioStreamPlayer.new()
				for f in Global.audio_formats:
					if file.ends_with(f + ".import"):
						music.stream = load(music_path + file.replace(".import",""))
						music.pitch_scale = Conductor.rate
						song_tracks.add_child(music)
		for music in song_tracks.get_children():
			music.play()
	elif Input.is_action_just_pressed("ui_accept"):
		Audio.play_sound("confirmMenu")
		enter_song_tween()
		
	if Input.is_action_just_pressed("ui_cancel"):
		Audio.play_sound("cancelMenu")
		Global.switch_scene("res://scenes/PlayMenu.tscn")
	
	if song_tracks.get_child_count() > 0:
		Conductor.position = song_tracks.get_child(0).get_playback_position() * 1000.0
	
	if cur_icon > -1:
		disc_icon.scale = lerp(disc_icon.scale, Vector2.ONE, delta * 9.0)

func on_beat_hit(beat:int) -> void:
	if cur_icon > -1:
		disc_icon.scale += Vector2(0.2, 0.2)

func start_tween():
	var tween = get_tree().create_tween().set_parallel()
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(bottom, "position:y", Global.game_size.y - bottom.texture.get_height() / 6, 0.5)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(disc, "scale:x", 1, 0.5)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(disc, "position:x", 130, 0.5)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(disc, "position:y", 635, 0.5)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(camera, "zoom", Vector2.ONE, 0.5)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property($ColorRect, "color:a", 0, 0.5)

func enter_song_tween():
	var tween = get_tree().create_tween().set_parallel()
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(score_text, "position:y", 750 - 677, 0.8)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(diff_sprite, "position:y", 750 - 677, 0.8)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(disc, "scale:x", 0, 0.8)
	
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property($ColorRect, "color:a", 1, 0.8).finished.connect(enter_song)
	
func enter_song():
	Global.queued_songs = []
	Global.is_story_mode = false
	
	Global.current_difficulty = song_list.songs[cur_selected].difficulties[cur_difficulty]
	
	if loaded_chart_info.difficulty != Global.current_difficulty or \
		loaded_chart_info.name != song_list.songs[cur_selected].song:
		Global.SONG = Chart.load_chart(song_list.songs[cur_selected].song, Global.current_difficulty)
	
	Global.switch_scene("res://scenes/gameplay/Gameplay.tscn")
