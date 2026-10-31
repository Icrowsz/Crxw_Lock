class_name OrbitalFX
extends RefCounted
## Efeitos da Reação Química ORBITAL RESONANCE (Kurona + Isagi), todos desenhados por código (nenhuma imagem):
##  - kick_fx():     o estilo do chute Domination (aura azul do Isagi com respingos de água rosa do Kurona);
##  - kick_burst():  no chute: estouro de água rosa e quebra-cabeças azuis;
##  - dominate():    acompanha a bola: a SILHUETA DE UM TUBARÃO azul nada atrás dela, quebra-cabeças azuis caem
##                   pelo caminho e ondas de água rosa abrem na bola. Se a bola ENTRAR NO GOL, tudo explode em
##                   uma ÁGUA ROSA e QUEBRA-CABEÇAS (um estouro grande e curto).
## O Isagi ainda solta os efeitos dele (as peças de quebra-cabeça do próprio _launch_shot_fx).

const BLUE := Color(0.22, 0.5, 1.0)
const BLUE_DARK := Color(0.07, 0.17, 0.5)
const BLUE_LIGHT := Color(0.7, 0.86, 1.0)
const PINK := Color(0.93, 0.42, 0.66)           # o rosa opaco do Kurona
const PINK_LIGHT := Color(1.0, 0.76, 0.88)
const PINK_DEEP := Color(0.62, 0.17, 0.4)

## Acima de jogadores e bola (que usam z_index = y como profundidade)
const FX_Z: int = 3000

const _KEY_PIECES := &"orbital_piece_polys"
const _KEY_MESHES := &"orbital_piece_meshes"


# ---------- ESTILO DO CHUTE ----------

static func kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = BLUE
	fx.trail_width = 24.0
	fx.particle_color = PINK_LIGHT
	fx.amount = 40
	fx.lifetime = 0.65
	fx.speed_min = 40.0
	fx.speed_max = 150.0
	fx.gravity = Vector2(0.0, 40.0)   # a água cai um pouco
	fx.spin = 300.0
	fx.scale_min = 0.2
	fx.scale_max = 0.45
	fx.burst_amount = 30
	fx.burst_speed = 330.0
	return fx


# ---------- PEÇAS DE QUEBRA-CABEÇA ----------

## Contorno de uma peça de quebra-cabeça de lado "s": knobs = para cada borda (cima, direita, baixo, esquerda),
## 1 = encaixe para fora e -1 = para dentro. Centrada em (0, 0).
static func puzzle_polygon(s: float, knobs: Array) -> PackedVector2Array:
	var h: float = s * 0.5
	var corners: Array[Vector2] = [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	var r: float = s * 0.15
	var pts := PackedVector2Array()
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var u: Vector2 = (b - a).normalized()
		var n := Vector2(u.y, -u.x) * float(knobs[i])   # para fora do quadrado quando knobs[i] = 1
		var mid: Vector2 = (a + b) * 0.5
		var center: Vector2 = mid + n * r * 0.9
		pts.append(a)
		pts.append(mid - u * r * 1.5)
		var steps: int = 14
		var from_a: float = PI + asin(0.9)    # pescoço do lado de "a"...
		var to_a: float = -asin(0.9)          # ...até o pescoço do lado de "b", passando por cima
		for k in range(steps + 1):
			var phi: float = lerpf(from_a, to_a, float(k) / float(steps))
			pts.append(center + (u * cos(phi) + n * sin(phi)) * r)
		pts.append(mid + u * r * 1.5)
	return pts


## Algumas formas de peça já prontas (calculadas uma vez)
static func _pieces() -> Array:
	if Engine.has_meta(_KEY_PIECES):
		return Engine.get_meta(_KEY_PIECES) as Array
	var combos: Array = [[1, -1, 1, -1], [-1, 1, -1, 1], [1, 1, -1, -1], [-1, -1, 1, 1], [1, -1, -1, 1]]
	var list: Array = []
	for c in combos:
		list.append(puzzle_polygon(1.0, c))   # tamanho 1: depois é só escalar
	Engine.set_meta(_KEY_PIECES, list)
	return list


## Malha (triângulos JÁ calculados) de cada peça. Desenhar com draw_mesh é bem mais barato do que mandar o
## polígono inteiro para ser triangulado a cada quadro (era isso que travava a reação).
static func _meshes() -> Array:
	if Engine.has_meta(_KEY_MESHES):
		return Engine.get_meta(_KEY_MESHES) as Array
	var list: Array = []
	for poly: PackedVector2Array in _pieces():
		var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		if idx.is_empty():
			list.append(null)   # polígono que não triangula: o desenho cai no draw_colored_polygon
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = poly
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		list.append(mesh)
	Engine.set_meta(_KEY_MESHES, list)
	return list


## Desenha uma peça de quebra-cabeça (preenchida + contorno claro) num CanvasItem. Só dentro do _draw dele.
static func draw_piece(canvas: CanvasItem, shape: int, pos: Vector2, rot: float, size: float,
		fill: Color, outline: Color) -> void:
	var mesh = _meshes()[shape]
	if mesh == null:
		canvas.draw_set_transform(pos, rot, Vector2(size, size))
		canvas.draw_colored_polygon(_pieces()[shape], fill)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# O contorno é a mesma peça um pouco maior e mais clara por baixo (sem polilinha antialiased por quadro)
	canvas.draw_mesh(mesh, null, Transform2D(rot, Vector2(size, size) * 1.14, 0.0, pos), outline)
	canvas.draw_mesh(mesh, null, Transform2D(rot, Vector2(size, size), 0.0, pos), fill)


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


static func _add(from: Node, n: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(n)


# ---------- EFEITOS ----------

## O estouro do chute: água rosa e peças azuis saindo da bola, com uma onda de água
static func kick_burst(from: Node, pos: Vector2, dir: Vector2) -> void:
	if not _ok(from):
		return
	var b := Splash.new()
	b.setup(24, 14, 0.7, 1.0, dir)
	_add(from, b)
	b.global_position = pos
	ripple(from, pos, 90.0)


## Onda de água rosa que abre e some
static func ripple(from: Node, pos: Vector2, radius: float = 60.0) -> void:
	if not _ok(from):
		return
	var r := Ripple.new()
	r.radius = radius
	_add(from, r)
	r.global_position = pos


## Acompanha a bola do chute Domination (tubarão, quebra-cabeças, ondas) e explode se ela entrar no gol
static func dominate(from: Node, ball: Ball) -> void:
	if not _ok(from) or ball == null:
		return
	var d := Dominate.new()
	d.target = ball
	_add(from, d)


# ---------- NÓS DOS EFEITOS ----------

## A silhueta do tubarão (de perfil, virado para +x) em coordenadas de "size" 1 = ~120 px de comprimento
class SharkShape:
	static func points(wag: float) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(62, 0), Vector2(46, -9), Vector2(24, -14), Vector2(8, -15), Vector2(-2, -34), Vector2(-14, -14),
			Vector2(-38, -8 + wag * 0.3), Vector2(-56, -24 + wag), Vector2(-50, -2 + wag * 0.8), Vector2(-58, 18 + wag),
			Vector2(-38, 7 + wag * 0.3), Vector2(-12, 10), Vector2(-4, 12), Vector2(2, 30), Vector2(14, 11),
			Vector2(36, 9), Vector2(52, 5)])


class Ripple extends Node2D:
	var radius: float = 60.0
	var life: float = 0.5
	var _t: float = 0.0

	func _init() -> void:
		z_as_relative = false
		z_index = OrbitalFX.FX_Z - 2

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf(_t / life, 0.0, 1.0)
		var r: float = radius * (1.0 - pow(1.0 - k, 3.0))
		var a: float = 1.0 - k
		# elipse achatada (a água no chão), dupla: uma maior e outra menor logo atrás
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(OrbitalFX.PINK, 0.85 * a), 5.0 * (1.0 - k) + 1.5)
		draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 32, Color(OrbitalFX.PINK_LIGHT, 0.7 * a), 3.0 * (1.0 - k) + 1.0)


## Estouro de gotas de água rosa e peças azuis. No gol: grande; no chute: menor.
class Splash extends Node2D:
	var drops: Array = []     # {p, v, size, life}
	var pieces: Array = []    # {p, v, rot, spin, size, shape, life}
	var _t: float = 0.0
	var _life: float = 1.0

	func _init() -> void:
		z_as_relative = false
		z_index = OrbitalFX.FX_Z

	## drop_count gotas, piece_count peças; power escala a velocidade; "dir" dá uma direção preferida (ZERO = todas)
	func setup(drop_count: int, piece_count: int, life: float, power: float, dir: Vector2 = Vector2.ZERO) -> void:
		_life = life + 0.35
		var base: float = dir.angle() if dir.length() > 0.01 else 0.0
		var cone: float = 1.3 if dir.length() > 0.01 else PI
		for i in drop_count:
			var a: float = base + randf_range(-cone, cone)
			drops.append({"p": Vector2.ZERO, "v": Vector2.from_angle(a) * randf_range(90.0, 380.0) * power,
				"size": randf_range(2.5, 6.5), "life": randf_range(life * 0.6, life)})
		for i in piece_count:
			var a2: float = base + randf_range(-cone, cone)
			pieces.append({"p": Vector2.ZERO, "v": Vector2.from_angle(a2) * randf_range(70.0, 300.0) * power,
				"rot": randf() * TAU, "spin": randf_range(-9.0, 9.0), "size": randf_range(14.0, 26.0),
				"shape": randi() % 5, "life": randf_range(life * 0.7, life + 0.2)})

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _life:
			queue_free()
			return
		for d in drops:
			d["v"] = (d["v"] as Vector2) + Vector2(0.0, 520.0) * delta   # a água cai
			d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
		for pc in pieces:
			pc["v"] = (pc["v"] as Vector2) * (1.0 - 2.2 * delta) + Vector2(0.0, 160.0) * delta
			pc["p"] = (pc["p"] as Vector2) + (pc["v"] as Vector2) * delta
			pc["rot"] = float(pc["rot"]) + float(pc["spin"]) * delta
		queue_redraw()

	func _draw() -> void:
		for d in drops:
			var k: float = clampf(_t / float(d["life"]), 0.0, 1.0)
			if k >= 1.0:
				continue
			var a: float = 1.0 - k
			draw_circle(d["p"], float(d["size"]) * (1.0 - k * 0.4), Color(OrbitalFX.PINK, 0.9 * a))
			draw_circle((d["p"] as Vector2) + Vector2(-1.0, -1.5), float(d["size"]) * 0.4, Color(OrbitalFX.PINK_LIGHT, 0.9 * a))
		for pc in pieces:
			var k2: float = clampf(_t / float(pc["life"]), 0.0, 1.0)
			if k2 >= 1.0:
				continue
			var a2: float = 1.0 - k2
			OrbitalFX.draw_piece(self, int(pc["shape"]), pc["p"], float(pc["rot"]), float(pc["size"]),
				Color(OrbitalFX.BLUE, 0.9 * a2), Color(OrbitalFX.BLUE_LIGHT, 0.95 * a2))


## Segue a bola: tubarão azul atrás dela, peças caindo e ondas rosa. Se for gol, explode.
## As peças e ondas do caminho são desenhadas AQUI mesmo (listas pequenas), sem criar um nó novo por peça:
## antes eram dezenas de nós redesenhando polígonos todo quadro.
class Dominate extends Node2D:
	const SHARK_SCALE: float = 2.5     # tamanho do tubarão (1.0 = ~120 px de comprimento; antes era 1.45)
	const MAX_BITS: int = 14
	const MAX_WAVES: int = 4

	var target: Ball
	var life: float = 6.0
	var _t: float = 0.0
	var _touches: int = 0
	var _piece_acc: float = 0.0
	var _ripple_acc: float = 0.0
	var _alpha: float = 0.0
	var _heading: float = 0.0
	var _field: Field
	var _ended: bool = false
	var _bits: Array = []    # peças que caem atrás da bola: {p (mundo), v, rot, spin, size, shape, t, life}
	var _waves: Array = []   # ondas de água: {p (mundo), t}

	func _ready() -> void:
		top_level = true
		z_as_relative = false
		z_index = OrbitalFX.FX_Z - 1
		if not is_instance_valid(target):
			queue_free()
			return
		_touches = target.interaction_count
		_heading = target.velocity.angle() if target.velocity.length() > 5.0 else 0.0
		_field = get_tree().get_first_node_in_group("field") as Field
		if _field != null:
			_field.goal_scored.connect(_on_goal)

	func _exit_tree() -> void:
		if _field != null and is_instance_valid(_field) and _field.goal_scored.is_connected(_on_goal):
			_field.goal_scored.disconnect(_on_goal)

	## A bola entrou: o tubarão estoura em água rosa e quebra-cabeças
	func _on_goal(_team: int) -> void:
		if _ended or not is_instance_valid(target):
			return
		_ended = true
		var pos: Vector2 = target.global_position
		var boom := Splash.new()
		boom.setup(42, 20, 1.0, 1.5)
		get_parent().add_child(boom)
		boom.global_position = pos
		OrbitalFX.ripple(self, pos, 190.0)
		OrbitalFX.ripple(self, pos, 120.0)
		queue_free()

	func _process(delta: float) -> void:
		if _ended:
			return
		_t += delta
		# Alguém tocou na bola (defesa, desvio) ou o tempo acabou: o tubarão some devagar
		var done: bool = not is_instance_valid(target) or _t >= life or target.interaction_count != _touches
		_alpha = move_toward(_alpha, 0.0 if done else 1.0, delta * (3.0 if done else 6.0))
		_update_trail(delta)
		if done and _alpha <= 0.0 and _bits.is_empty() and _waves.is_empty():
			queue_free()
			return
		if not is_instance_valid(target):
			queue_redraw()
			return
		var v: Vector2 = target.velocity
		if v.length() > 20.0:
			_heading = lerp_angle(_heading, v.angle(), minf(1.0, delta * 10.0))
		global_position = target.global_position
		if not done and v.length() > 40.0:
			_piece_acc += delta
			_ripple_acc += delta
			if _piece_acc >= 0.06 and _bits.size() < MAX_BITS:   # uma peça que cai atrás da bola
				_piece_acc = 0.0
				_bits.append({
					"p": target.global_position + Vector2.from_angle(_heading + PI) * randf_range(14.0, 40.0),
					"v": Vector2.from_angle(_heading + PI + randf_range(-1.3, 1.3)) * randf_range(25.0, 100.0),
					"rot": randf() * TAU, "spin": randf_range(-9.0, 9.0), "size": randf_range(14.0, 26.0),
					"shape": randi() % 5, "t": 0.0, "life": randf_range(0.45, 0.75)})
			if _ripple_acc >= 0.25 and _waves.size() < MAX_WAVES:   # uma onda de água na bola
				_ripple_acc = 0.0
				_waves.append({"p": target.global_position, "t": 0.0})
		queue_redraw()

	## Move as peças e envelhece as ondas (e tira as que acabaram)
	func _update_trail(delta: float) -> void:
		for i in range(_bits.size() - 1, -1, -1):
			var b: Dictionary = _bits[i]
			b["t"] = float(b["t"]) + delta
			if float(b["t"]) >= float(b["life"]):
				_bits.remove_at(i)
				continue
			b["v"] = (b["v"] as Vector2) * (1.0 - 2.2 * delta) + Vector2(0.0, 160.0) * delta
			b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * delta
			b["rot"] = float(b["rot"]) + float(b["spin"]) * delta
		for i in range(_waves.size() - 1, -1, -1):
			var w: Dictionary = _waves[i]
			w["t"] = float(w["t"]) + delta
			if float(w["t"]) >= 0.5:
				_waves.remove_at(i)

	func _draw() -> void:
		# Ondas de água rosa no chão (elipse achatada), por baixo de tudo
		for w: Dictionary in _waves:
			var k: float = clampf(float(w["t"]) / 0.5, 0.0, 1.0)
			var r: float = 55.0 * (1.0 - pow(1.0 - k, 3.0))
			var a: float = 1.0 - k
			draw_set_transform((w["p"] as Vector2) - global_position, 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(OrbitalFX.PINK, 0.85 * a), 4.0 * (1.0 - k) + 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# O tubarão nada logo atrás da bola, com o focinho perto dela (de perfil; nunca de cabeça para baixo)
		if _alpha > 0.01:
			var flip: float = -1.0 if cos(_heading) < 0.0 else 1.0
			var wag: float = sin(_t * 12.0) * 6.0
			var s: float = SHARK_SCALE
			draw_set_transform(Vector2.from_angle(_heading) * -34.0 * (s / 1.45), _heading, Vector2(s, s * flip))
			var body: PackedVector2Array = OrbitalFX.SharkShape.points(wag)
			draw_colored_polygon(body, Color(OrbitalFX.BLUE, 0.55 * _alpha))
			draw_polyline(body + PackedVector2Array([body[0]]), Color(OrbitalFX.BLUE_LIGHT, 0.9 * _alpha), 1.6)
			# detalhes: barriga mais clara, guelras, olho e a boca
			draw_polyline(PackedVector2Array([Vector2(30, 4), Vector2(8, 9), Vector2(-20, 7)]), Color(OrbitalFX.BLUE_LIGHT, 0.45 * _alpha), 1.6)
			for g in 3:
				draw_line(Vector2(24.0 - g * 5.0, -5.0), Vector2(22.0 - g * 5.0, 3.0), Color(OrbitalFX.BLUE_DARK, 0.75 * _alpha), 1.3)
			# Olho frio e fileira de dentes: mais ameaçador
			draw_circle(Vector2(46, -3), 2.6, Color(1, 1, 1, 0.95 * _alpha))
			draw_circle(Vector2(46.6, -3), 1.1, Color(OrbitalFX.BLUE_DARK, _alpha))
			draw_line(Vector2(60, 3), Vector2(42, 6), Color(OrbitalFX.BLUE_DARK, 0.85 * _alpha), 1.4)
			for t in 6:
				var tx: float = 57.0 - float(t) * 3.4
				var ty: float = 3.6 + (57.0 - tx) * 0.16
				draw_colored_polygon(PackedVector2Array([Vector2(tx, ty), Vector2(tx - 2.6, ty + 0.6), Vector2(tx - 1.2, ty + 5.0)]),
					Color(1, 1, 1, 0.92 * _alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Quebra-cabeças azuis que caem atrás da bola
		for b: Dictionary in _bits:
			var kb: float = clampf(float(b["t"]) / float(b["life"]), 0.0, 1.0)
			var ab: float = 1.0 - kb
			OrbitalFX.draw_piece(self, int(b["shape"]), (b["p"] as Vector2) - global_position, float(b["rot"]),
				float(b["size"]), Color(OrbitalFX.BLUE, 0.9 * ab), Color(OrbitalFX.BLUE_LIGHT, 0.95 * ab))
