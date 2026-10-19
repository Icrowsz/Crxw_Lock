class_name RinFX
extends RefCounted
## Efeitos visuais do Rin: uma MASSA COM ESPINHOS verde-água e preta. Tudo por código (nenhuma imagem).
##
##  - make_aura(): a massa com espinhos e olhos nas costas do Destroyer Mode (filha do Rin)
##  - clash(): pulso do confronto físico (Center of Gravity / Mangle You) e da ativação do Destroyer Mode
##  - spikes_on(): espinhos que surgem e perfuram o inimigo derrubado
##  - puppeteer_hand(): mão de marionetista com os fios sobrevoando o aliado do Puppets
##
## Leve, no mesmo estilo do isagi_fx.gd: uma textura e dois degradês compartilhados (guardados no Engine), um
## CPUParticles2D "one_shot" por efeito e nós que se apagam sozinhos. A única coisa que roda por quadro é a aura
## (só enquanto o Destroyer Mode está ligado, e redesenhando a 20 vezes por segundo) e as mãos/espinhos que estão na
## tela. Quem chama passa um nó que já esteja na árvore em "from".

const TEAL := Color(0.176, 0.661, 0.569)         # verde-água (a cor do kick_fx do Rin)
const TEAL_LIGHT := Color(0.314, 0.909, 0.625)
const TEAL_DEEP := Color(0.08, 0.30, 0.30)
const BLACK := Color(0.015, 0.05, 0.05)

const _KEY_TEX := &"rin_shard_tex"
const _KEY_PICK := &"rin_shard_pick"
const _KEY_FADE := &"rin_shard_fade"


# ---------- RECURSOS COMPARTILHADOS ----------

## O estilhaço (um espinho apontando para cima), branco, 32x32
static func shard_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_TEX):
		return Engine.get_meta(_KEY_TEX) as ImageTexture
	var tri := PackedVector2Array([Vector2(16.0, 1.5), Vector2(21.5, 30.5), Vector2(10.5, 30.5)])
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var hits: int = 0
			for sy in 3:   # 3x3 amostras por pixel: borda suave
				for sx in 3:
					if Geometry2D.is_point_in_polygon(Vector2(float(x) + (float(sx) + 0.5) / 3.0, float(y) + (float(sy) + 0.5) / 3.0), tri):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 9.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_TEX, tex)
	return tex


## Cada estilhaço nasce preto OU verde-água (sorteio: degrau no meio do degradê)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5])
	g.colors = PackedColorArray([BLACK, TEAL])
	Engine.set_meta(_KEY_PICK, g)
	return g


## Fica inteiro e some no final da vida
static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _make(amount: int, lifetime: float, speed: float, size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = shard_texture()
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false          # os estilhaços ficam no campo e não acompanham quem os soltou
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.1     # freiam rápido, como cacos jogados
	p.damping_max = speed * 1.6
	p.gravity = Vector2(0.0, 40.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = 3000   # acima de tudo (jogadores e bola usam z_index = y como profundidade)
	p.z_as_relative = false
	return p


static func _launch(from: Node, p: CPUParticles2D, pos: Vector2) -> void:
	var tree: SceneTree = from.get_tree()
	var scene: Node = tree.current_scene
	(scene if scene != null else from).add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	tree.create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


static func _ease_out_back(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


## UM espinho: triângulo preto com a borda verde-água (o desenho-base de todos os efeitos do Rin).
## "c" é o nó que está desenhando agora (chame de dentro do _draw dele).
static func _spike(c: CanvasItem, base: Vector2, dir: Vector2, length: float, width: float, alpha: float = 1.0) -> void:
	if length <= 0.5 or alpha <= 0.01:
		return
	var side: Vector2 = dir.orthogonal() * width * 0.5
	var tip: Vector2 = base + dir * length
	c.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(BLACK, alpha))
	c.draw_line(base - side, tip, Color(TEAL, alpha), 1.6)
	c.draw_line(base + side, tip, Color(TEAL_DEEP, alpha), 1.2)


# ---------- EFEITOS ----------

## Explosão de estilhaços em volta de um ponto do campo. strong = mais estilhaços, maiores e mais longe.
static func burst(from: Node, pos: Vector2, amount: int = 12, strong: bool = false) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.75 if strong else 0.6, 190.0 if strong else 130.0,
		0.5 if strong else 0.35, 0.9 if strong else 0.65)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 16.0 if strong else 10.0
	_launch(from, p, pos)


## Pulso do confronto físico: estilhaços + um anel preto/verde-água com espinhos que se abre. Com a e b no mesmo
## ponto (ativação do Destroyer Mode) o efeito é maior.
static func clash(from: Node, a: Vector2, b: Vector2) -> void:
	if not _ok(from):
		return
	var mid: Vector2 = (a + b) * 0.5
	var strong: bool = a.distance_to(b) < 1.0
	burst(from, mid, 22 if strong else 14, strong)
	var shock := Shock.new()
	shock.strong = strong
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(shock)
	shock.global_position = mid


## Espinhos que surgem do chão e perfuram o inimigo derrubado (Center of Gravity, Mangle You, Crash Shot).
## small = versão menor (Destruction: o inimigo é atordoado, não derrubado).
static func spikes_on(enemy: Node2D, small: bool = false) -> void:
	if not _ok(enemy):
		return
	var s := Spikes.new()
	s.count = 4 if small else 8
	s.scale_mult = 0.75 if small else 1.0
	var r = enemy.get("placeholder_radius")
	s.radius = (float(r) if r != null else 18.0) * 0.9
	enemy.add_child(s)
	burst(enemy, enemy.global_position, 8 if small else 12, false)


## Mão de marionetista que sobrevoa o aliado do Puppets, com os fios presos nele
static func puppeteer_hand(target: Node2D, seconds: float = 2.0) -> void:
	if not _ok(target):
		return
	var hand := PuppetHand.new()
	hand.life = seconds
	target.add_child(hand)


## A massa com espinhos e olhos nas costas do Destroyer Mode. Vira filha do Rin e começa DESLIGADA;
## quem a criou liga e desliga com set_active(). fx_scale / fx_offset ajustam o tamanho e a posição.
static func make_aura(unit: float = 18.0) -> Aura:
	var a := Aura.new()
	a.unit = unit
	a.z_index = -1   # atrás do Rin
	a.set_active(false)
	return a


# ---------- NÓS DOS EFEITOS ----------

## Anel de choque do confronto: preto com borda verde-água e espinhos que saem dele
class Shock extends Node2D:
	var strong: bool = false
	var t: float = 0.0:
		set(v):
			t = v
			queue_redraw()

	func _ready() -> void:
		z_index = 3000
		z_as_relative = false
		var tw: Tween = create_tween()
		tw.tween_property(self, "t", 1.0, 0.5 if strong else 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var r: float = lerpf(10.0, 72.0 if strong else 50.0, t)
		var a: float = 1.0 - t
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(RinFX.BLACK, a * 0.9), 5.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(RinFX.TEAL, a), 2.5)
		var n: int = 12 if strong else 8
		for i in n:
			var dir: Vector2 = Vector2.from_angle(TAU * float(i) / float(n) + 0.3)
			RinFX._spike(self, dir * r, dir, lerpf(4.0, 20.0, sin(PI * t)), 5.0, a)


## Espinhos que nascem em volta/através do inimigo caído: crescem com um tranco, ficam e recolhem
class Spikes extends Node2D:
	const GROW: float = 0.22
	const HOLD: float = 1.1
	const FADE: float = 0.4
	var count: int = 8
	var scale_mult: float = 1.0
	var radius: float = 18.0
	var _items: Array[Dictionary] = []
	var _age: float = 0.0

	func _ready() -> void:
		z_index = 4   # por cima do inimigo: os espinhos o atravessam
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in count:
			var at: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, radius) * Vector2(1.0, 0.6)
			_items.append({
				"base": at,
				"dir": Vector2.UP.rotated(deg_to_rad(rng.randf_range(-38.0, 38.0))),
				"len": rng.randf_range(24.0, 46.0) * scale_mult,
				"w": rng.randf_range(7.0, 11.0) * scale_mult,
				"delay": float(i) * 0.025,
			})

	func _process(delta: float) -> void:
		_age += delta
		if _age > GROW + HOLD + FADE + 0.2:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade: float = clampf((GROW + HOLD + FADE - _age) / FADE, 0.0, 1.0)
		for it in _items:
			var grow: float = RinFX._ease_out_back(clampf((_age - float(it["delay"])) / GROW, 0.0, 1.0))
			var base: Vector2 = it["base"]
			var w: float = float(it["w"])
			# Mancha escura (a "massa") na base de cada espinho
			draw_circle(base, w * 0.9 * grow, Color(RinFX.BLACK, 0.9 * fade))
			draw_arc(base, w * 0.9 * grow, 0.0, TAU, 12, Color(RinFX.TEAL, fade), 1.5)
			RinFX._spike(self, base, it["dir"], float(it["len"]) * grow * lerpf(0.5, 1.0, fade), w, fade)


## Mão de marionetista: antebraço descendo do alto, mão segurando uma barra de controle e 5 fios
## verde-água até a cabeça, as mãos e os pés do aliado. Balança de leve, aparece e some suave.
class PuppetHand extends Node2D:
	var life: float = 2.0
	var _age: float = 0.0
	var _ally: Node2D
	var _radius: float = 18.0

	func _ready() -> void:
		_ally = get_parent() as Node2D
		var r = _ally.get("placeholder_radius")
		_radius = float(r) if r != null else 18.0
		z_index = 12
		modulate.a = 0.0
		_follow()

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		modulate.a = minf(minf(_age / 0.25, 1.0), clampf((life - _age) / 0.35, 0.0, 1.0))
		_follow()
		queue_redraw()

	func _follow() -> void:
		var h = _ally.get("height")
		var lift: float = float(h) if h != null else 0.0
		position = Vector2(sin(_age * 1.7) * 6.0, -(lift + _radius + 64.0 + sin(_age * 2.3) * 4.0))

	func _draw() -> void:
		var drop: float = -position.y   # distância até o centro do aliado (a barra é a origem deste nó)
		# Fios: da barra até cabeça, pés e mãos do aliado
		var ends: Array[Vector2] = [
			Vector2(-22.0, 2.0), Vector2(-11.0, 2.0), Vector2(0.0, 2.0), Vector2(11.0, 2.0), Vector2(22.0, 2.0)]
		var targets: Array[Vector2] = [
			Vector2(-_radius * 1.1, drop), Vector2(-_radius * 0.5, drop + _radius * 0.8),
			Vector2(0.0, drop - _radius), Vector2(_radius * 0.5, drop + _radius * 0.8), Vector2(_radius * 1.1, drop)]
		for i in 5:
			var wobble: float = sin(_age * 7.0 + float(i) * 1.3) * 2.5   # a mão "puxa" os fios
			var a: Vector2 = ends[i]
			var b: Vector2 = targets[i] + Vector2(wobble, 0.0)
			var ctrl: Vector2 = (a + b) * 0.5 + Vector2(sin(_age * 3.0 + float(i)) * 4.0, 0.0)
			var pts := PackedVector2Array()
			for s in 7:
				var t: float = float(s) / 6.0
				pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
			draw_polyline(pts, Color(RinFX.TEAL, 0.85), 1.3)
			draw_circle(b, 2.0, Color(RinFX.TEAL_LIGHT, 0.9))   # o fio preso no aliado
		# Barra de controle
		draw_rect(Rect2(-27.0, -2.0, 54.0, 6.0), RinFX.BLACK)
		draw_rect(Rect2(-27.0, -2.0, 54.0, 6.0), RinFX.TEAL, false, 1.3)
		for e in ends:
			draw_circle(e, 1.8, RinFX.TEAL_LIGHT)
		# Antebraço (do alto) e palma
		var arm := PackedVector2Array([Vector2(-7.0, -58.0), Vector2(7.0, -58.0), Vector2(10.0, -22.0), Vector2(-10.0, -22.0)])
		draw_colored_polygon(arm, RinFX.BLACK)
		draw_polyline(PackedVector2Array([arm[0], arm[3], arm[2], arm[1]]), RinFX.TEAL, 1.5)
		var palm := PackedVector2Array([Vector2(-12.0, -24.0), Vector2(12.0, -24.0), Vector2(11.0, -12.0), Vector2(-11.0, -12.0)])
		draw_colored_polygon(palm, RinFX.BLACK)
		draw_polyline(PackedVector2Array([palm[0], palm[1], palm[2], palm[3], palm[0]]), RinFX.TEAL, 1.5)
		# Dedos segurando a barra, mexendo
		for i in 5:
			var x: float = -9.0 + float(i) * 4.5
			var knuckle := Vector2(x * 1.1, -8.0)
			var tip := Vector2(x * 1.05 + sin(_age * 7.0 + float(i)) * 1.5, 0.5)
			draw_line(Vector2(x, -12.0), knuckle, RinFX.TEAL, 6.0)
			draw_line(knuckle, tip, RinFX.TEAL, 6.0)
			draw_line(Vector2(x, -12.0), knuckle, RinFX.BLACK, 3.6)
			draw_line(knuckle, tip, RinFX.BLACK, 3.6)


## A massa preta com espinhos verde-água e olhos nas costas do Rin (Destroyer Mode). Redesenha a 20 vezes por
## segundo e só roda enquanto está ligada.
class Aura extends Node2D:
	const SPIKES: int = 14
	const BLOB_POINTS: int = 28
	var unit: float = 18.0
	var fx_scale: float = 1.0
	var fx_offset: Vector2 = Vector2.ZERO
	var _t: float = 0.0
	var _acc: float = 0.0

	func set_active(on: bool) -> void:
		visible = on
		set_process(on)
		if on:
			queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _acc >= 0.05:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var u: float = unit * fx_scale
		var c: Vector2 = fx_offset + Vector2(0.0, -u * 0.1)
		# A massa: contorno que "respira"
		var blob := PackedVector2Array()
		for i in BLOB_POINTS:
			var a: float = TAU * float(i) / float(BLOB_POINTS)
			var r: float = u * 1.35 * (1.0 + 0.10 * sin(_t * 1.6 + float(i) * 0.9) + 0.06 * sin(_t * 2.7 + float(i) * 2.1))
			blob.append(c + Vector2.from_angle(a) * r)
		draw_colored_polygon(blob, Color(RinFX.BLACK, 0.88))
		var rim := blob.duplicate()
		rim.append(blob[0])
		draw_polyline(rim, Color(RinFX.TEAL, 0.8), 2.0)
		# Os espinhos saindo da massa, crescendo e encolhendo fora de fase
		for i in SPIKES:
			var ang: float = TAU * float(i) / float(SPIKES) + 0.12 * sin(_t * 0.8 + float(i))
			var dir: Vector2 = Vector2.from_angle(ang)
			var length: float = u * (0.85 + 0.55 * absf(sin(_t * 1.3 + float(i) * 1.7)))
			RinFX._spike(self, c + dir * u * 1.2, dir, length, u * 0.42, 0.95)
		# Os olhos nas costas (piscam de tempos em tempos)
		var eyes: Array[Vector2] = [Vector2(-0.6, -0.45), Vector2(0.0, -0.8), Vector2(0.6, -0.45)]
		for k in eyes.size():
			var cycle: float = fposmod(_t + float(k) * 1.3, 3.4)
			var open: float = 0.15 if cycle > 3.25 else 1.0
			_eye(c + eyes[k] * u, u * 0.26, open)

	func _eye(at: Vector2, size: float, open: float) -> void:
		var pts := PackedVector2Array()
		for s in 9:   # amêndoa
			var x: float = lerpf(-1.0, 1.0, float(s) / 8.0)
			pts.append(at + Vector2(x * size, -size * 0.5 * open * (1.0 - x * x)))
		for s in range(7, 0, -1):
			var x: float = lerpf(-1.0, 1.0, float(s) / 8.0)
			pts.append(at + Vector2(x * size, size * 0.5 * open * (1.0 - x * x)))
		draw_colored_polygon(pts, RinFX.TEAL_LIGHT)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, RinFX.BLACK, 1.2)
		if open > 0.5:   # pupila vertical
			draw_line(at + Vector2(0.0, -size * 0.4), at + Vector2(0.0, size * 0.4), RinFX.BLACK, maxf(1.5, size * 0.22))
