extends Stage

func _ready():
	var nodes = [
		$"ParallaxBackground/Back1/AnimatedSprite",
		$"ParallaxBackground/0-75/AnimatedSprite",
		$"ParallaxBackground/0-85/AnimatedSprite",
		$"ParallaxBackground/1/AnimatedSprite",
		$"ParallaxBackground/1/AnimatedSprite2",
		$"ParallaxBackground/1/AnimatedSprite3"
	];
	for anim_sprite in nodes:
		anim_sprite.playing = true
		
	game.camera.ignore_rotation = false

func _process(delta):
	var angle = lerpf(-25, 25, fposmod(Conductor.position, Conductor.crochet * 4) / Conductor.crochet * 4)
	var rot = deg_to_rad(angle)
	game.camera.rotation_degrees = angle
	game.hud.rotation = -rot
