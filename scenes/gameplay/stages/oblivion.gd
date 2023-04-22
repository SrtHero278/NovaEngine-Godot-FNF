extends Stage

@onready var cam_tint:Sprite2D = $PB/Zero/CamTint
@onready var holo:Sprite2D = $PB/Point45/Holo

func _ready_post():
	$PB/Point3/BGGlitch.playing = true
	
	var holo_size = holo.texture.get_size()
	holo.position.x += holo_size.x / 2;
	holo.position.y += holo_size.y / 2;
	
	Conductor.beat_hit.connect(on_beat_hit)
	game.note_group.child_entered_tree.connect(note_spawn)

func note_spawn(note:Note):
	note.alt_anim = note.alt_anim && !note.must_press

func _process(delta):
	holo.rotation_degrees += delta * 12;
	
func on_countdown_tick(a, b):
	on_beat_hit(0)
	
func on_beat_hit(b):
	$PB/Half/NeoBop.playing = true
	$PB/One/SpaceStage.playing = true
	
func _exit_tree():
	Conductor.beat_hit.disconnect(on_beat_hit)
