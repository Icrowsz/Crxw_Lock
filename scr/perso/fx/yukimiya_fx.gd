class_name YukimiyaFX
extends RefCounted

const COLOR_PURPLE := Color(0.6, 0.15, 0.85)
const COLOR_PURPLE_LIGHT := Color(0.85, 0.5, 1.0)

static var _tex_geo: Array[ImageTexture] = []

## Texturas geométricas ocas (Círculo, Quadrado, Triângulo)
static func _get_geo_tex(index: int) -> ImageTexture:
	if _tex_geo.size() > index:
		return _tex_geo[index]
	
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var p = Vector2(x, y)
			var center = Vector2(16, 16)
			var keep = false
			if index == 0: # Círculo vazado
				var d = p.distance_to(center)
				if d < 14 and d > 10: keep = true
			elif index == 1: # Quadrado vazado
				if (x > 4 and x < 10 and y > 4 and y < 28) or (x > 22 and x < 28 and y > 4 and y < 28) or \
				   (y > 4 and y < 10 and x > 4 and x < 28) or (y > 22 and y < 28 and x > 4 and x < 28):
					keep = true
			elif index == 2: # Triângulo vazado
				if y > 6 and y < 26:
					var half_w = (y - 6) * 0.7
					if abs(x - 16) < half_w and abs(x - 16) > half_w - 5:
						keep = true
			if keep:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	
	var tex := ImageTexture.create_from_image(img)
	_tex_geo.append(tex)
	return tex

## Partículas geométricas roxas (sem gravidade, flutuam lentamente)
static func _make_geo_particles(amount: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var r := randi() % 3
	p.texture = _get_geo_tex(r)
	p.color = COLOR_PURPLE if randf() < 0.7 else COLOR_PURPLE_LIGHT
	p.amount = amount
	p.lifetime = 1.2 # Vida mais longa para flutuarem
	p.local_coords = false
	p.direction = Vector2.ZERO
	p.spread = 360.0
	p.initial_velocity_min = 5.0 # Quase parados
	p.initial_velocity_max = 25.0
	p.damping_min = 5.0
	p.damping_max = 10.0
	p.gravity = Vector2.ZERO # <-- GRAVIDADE REMOVIDA
	p.angle_max = 360.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	p.z_index = 3000
	p.z_as_relative = false
	return p

# ---------- API PÚBLICA ----------

## Explosão de formas geométricas
static func burst(from: Node, pos: Vector2, strong: bool = false) -> void:
	if from == null or not from.is_inside_tree(): return
	var tree := from.get_tree()
	var scene := tree.current_scene if tree.current_scene else from

	var geo := _make_geo_particles(20 if strong else 10)
	scene.add_child(geo)
	geo.global_position = pos
	geo.one_shot = true
	geo.explosiveness = 1.0
	geo.emitting = true
	tree.create_timer(geo.lifetime + 0.5).timeout.connect(geo.queue_free)

## Inicia um rastro de fogo no chão para os dashes
static func begin_trail(from: Node) -> Trail:
	var t := Trail.new()
	var field := from.get_tree().get_first_node_in_group("field")
	if field: field.add_child(t)
	else: from.get_tree().current_scene.add_child(t)
	return t

## Cria o rastro do chute na bola (mesmo traço do dash + formas geométricas flutuando)
static func trail_ball(ball: Ball, seconds: float = 1.0) -> void:
	if ball == null or not ball.is_inside_tree(): return
	var tree := ball.get_tree()
	var scene := tree.current_scene if tree.current_scene else ball
	
	var trail := BallTrail.new()
	trail.target = ball
	trail.duration = seconds
	scene.add_child(trail)

# ---------- CLASSES DE RASTRO ----------

## Rastro dos dashes (linha estática no campo)
class Trail extends Node2D:
	var points: PackedVector2Array = []
	var life: float = 0.6

	func _ready() -> void:
		top_level = true
		global_position = Vector2.ZERO
		z_index = -4000
		z_as_relative = false

	func add(pos: Vector2) -> void:
		if points.is_empty() or points[points.size()-1].distance_to(pos) > 5.0:
			points.append(pos)
			queue_redraw()

	func finish() -> void:
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, life)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		if points.size() < 2: return
		for i in range(points.size() - 1):
			var w = 20.0 * (float(i) / points.size() + 0.5)
			draw_line(points[i], points[i+1], Color(0.9, 0.2, 0.0, 0.8), w)
			draw_line(points[i], points[i+1], Color(1.0, 0.7, 0.0, 0.9), w * 0.5)

## Rastro que segue a bola durante o chute (mesmo traço do dash + geometrias soltas)
class BallTrail extends Node2D:
	var target: Node2D
	var duration: float
	var time_left: float
	var points: Array = [] # Guarda dicionários: {"pos": Vector2, "life": float}
	var geo_timer: float = 0.0
	
	const POINT_LIFE: float = 1.2 # Quanto tempo cada pedaço do rastro demora pra sumir

	func _ready() -> void:
		top_level = true
		z_index = -4000
		z_as_relative = false
		time_left = duration

	func _process(delta: float) -> void:
		if not is_instance_valid(target):
			queue_free()
			return
			
		time_left -= delta
		
		# Enquanto o tempo não acabou, segue a bola e adiciona pontos
		if time_left > 0:
			var pos = target.global_position
			if target is Ball:
				pos += Vector2(0, -target.height)
				
			if points.is_empty() or points[-1]["pos"].distance_to(pos) > 8.0:
				points.append({"pos": pos, "life": POINT_LIFE})
				
			# Solta formas geométricas pelo caminho
			geo_timer -= delta
			if geo_timer <= 0:
				geo_timer = 0.08
				var p := YukimiyaFX._make_geo_particles(1)
				get_tree().current_scene.add_child(p)
				p.global_position = pos
				p.one_shot = true
				p.explosiveness = 1.0
				p.emitting = true
				get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)

		# Faz todos os pontos envelhecerem e remove os que já sumiram
		for i in range(points.size() - 1, -1, -1):
			points[i]["life"] -= delta
			if points[i]["life"] <= 0:
				points.remove_at(i)
		
		# Se o tempo acabou e não tem mais nenhum ponto vivo, se autodestrói
		if points.is_empty() and time_left <= 0:
			queue_free()
			return
			
		queue_redraw()

	func _draw() -> void:
		if points.size() < 2: return
		
		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i+1]
			
			# A opacidade (alpha) vai de 1.0 a 0.0 conforme o ponto envelhece
			var alpha = p1["life"] / POINT_LIFE
			
			# A largura do traço também diminui conforme ele envelhece
			var w = 24.0 * alpha + 4.0
			
			var c1 = Color(0.9, 0.2, 0.0, 0.8 * alpha)
			var c2 = Color(1.0, 0.7, 0.0, 0.9 * alpha)
			
			draw_line(p1["pos"], p2["pos"], c1, w)
			draw_line(p1["pos"], p2["pos"], c2, w * 0.5)
