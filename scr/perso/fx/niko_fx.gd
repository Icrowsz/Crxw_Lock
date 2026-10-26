class_name NikoFX
extends RefCounted
## Efeitos visuais do Niko: VERDE de radar e vigilância (torres, ondas de radar e bússolas).
## Tudo por código (nenhuma imagem): o ponto de radar e o anel são desenhados uma única vez em texturas
## brancas e a cor vem da partícula. Os efeitos "vivos" (torre, bússola, radar) são nós pequenos que se
## apagam sozinhos.
##
## Leve, como o do Barou:
##  - duas texturas e dois degradês compartilhados (criados uma vez e guardados no Engine);
##  - um CPUParticles2D "one_shot" por efeito (poucas partículas, vida curta);
##  - o radar do Niko só roda enquanto a Metavision está ligada.
##
## O que cada coisa é:
##  - kick_fx():     estilo do rastro/aura da bola nos passes do Niko (Tactical e Bomber Tact)
##  - tower():       a torre de vigia com o círculo de alcance. A Watchtower e as Safe Spots usam a mesma
##                   torre; as Safe Spots só a desenham menor (body_scale)
##  - mark():        a bússola verde translúcida que fica no aliado marcado por um passe do Niko
##                   (ele tem +% no próximo chute) até ele chutar
##  - make_radar():  o radarzinho que emana do Niko durante a Metavision (pulsos + varredura)
##  - ping()/blips(): uma onda de radar no chão e pontinhos de radar espalhados
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Niko) em "from".

const GREEN := Color(0.3, 1.0, 0.5)          # o verde da torre (o mesmo de sempre do Niko)
const LIGHT_GREEN := Color(0.75, 1.0, 0.8)
const DEEP_GREEN := Color(0.08, 0.45, 0.25)

const _KEY_RING := &"niko_ring_tex"
const _KEY_BLIP := &"niko_blip_tex"
const _KEY_PICK := &"niko_blip_pick"
const _KEY_FADE := &"niko_blip_fade"


# ---------- ESTILO DO PASSE (aura + partículas do KickFX) ----------

## Verde Blue Lock para o rastro dos passes do Niko
static func kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = GREEN
	fx.trail_width = 12.0
	fx.particle_color = LIGHT_GREEN
	fx.amount = 18
	fx.lifetime = 0.5
	fx.speed_min = 15.0
	fx.speed_max = 60.0
	fx.scale_min = 0.15
	fx.scale_max = 0.3
	fx.burst_amount = 10
	fx.burst_speed = 180.0
	return fx


# ---------- RECURSOS COMPARTILHADOS ----------

## Anel fininho (24x24), branco: a onda de radar das partículas
static func ring_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_RING):
		return Engine.get_meta(_KEY_RING) as ImageTexture
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(12.0, 12.0))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - absf(d - 9.5) / 1.5, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_RING, tex)
	return tex


## Pontinho de radar (cruzinha, 12x12), branco
static func blip_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_BLIP):
		return Engine.get_meta(_KEY_BLIP) as ImageTexture
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var dx: float = absf(float(x) + 0.5 - 6.0)
			var dy: float = absf(float(y) + 0.5 - 6.0)
			var arm: float = minf(dx, dy)   # distância ao eixo mais próximo: forma uma cruz
			var reach: float = maxf(dx, dy)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - arm / 1.3, 0.0, 1.0) * clampf((6.0 - reach) / 1.5, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_BLIP, tex)
	return tex


## Cada ponto nasce verde (60%) OU verde-claro (40%)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.6])
	g.colors = PackedColorArray([GREEN, LIGHT_GREEN])
	Engine.set_meta(_KEY_PICK, g)
	return g


static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _make(amount: int, lifetime: float, speed: float, size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = blip_texture()
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.gravity = Vector2.ZERO
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = 3000
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


static func _add_node(from: Node, n: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(n)


# ---------- EFEITOS ----------

## Pontinhos de radar espalhados em volta de um ponto
static func blips(from: Node, pos: Vector2, amount: int = 10) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.5, 150.0, 0.7, 1.3)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	_launch(from, p, pos)


## Onda de radar no chão: um anel achatado que se abre e some (ativações, torres, acertos de QTE)
static func ping(from: Node, pos: Vector2, radius: float = 60.0, seconds: float = 0.5) -> void:
	if not _ok(from):
		return
	var s := Ping.new()
	s.radius = radius
	s.life = seconds
	_add_node(from, s)
	s.global_position = pos


## Torre de vigia + círculo de alcance, em "center" (a Watchtower usa 1.0; as Safe Spots, uma torre menor)
static func tower(from: Node, center: Vector2, radius: float, body_scale: float = 1.0) -> Tower:
	var t := Tower.new()
	t.radius = radius
	t.body_scale = body_scale
	if _ok(from):
		_add_node(from, t)
		t.global_position = center
		t.appear()
	return t


## A bússola verde translúcida sobre um aliado marcado. Chame release() quando a marca acabar.
static func mark(target: Player) -> Mark:
	var m := Mark.new()
	m.target = target
	if _ok(target):
		_add_node(target, m)
	return m


## O radarzinho do Niko durante a Metavision. Vira filho dele e começa DESLIGADO.
static func make_radar(radius: float = 62.0) -> Radar:
	var r := Radar.new()
	r.radius = radius
	r.active = false
	return r


# ---------- NÓS DOS EFEITOS ----------

class Ping extends Node2D:
	var radius: float = 60.0
	var life: float = 0.5
	var _t: float = 0.0

	func _init() -> void:
		z_index = -3990   # no chão, acima do círculo das torres
		z_as_relative = false

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf(_t / life, 0.0, 1.0)
		var r: float = radius * (1.0 - pow(1.0 - k, 3.0))   # abre rápido e desacelera
		var a: float = 1.0 - k
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))   # achatado: é um anel no chão
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(GREEN, 0.9 * a), 3.0 * (1.0 - k) + 1.0)
		draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 36, Color(LIGHT_GREEN, 0.5 * a), 1.5)


## Círculo verde translúcido no chão (acima da grama, abaixo de jogadores e bola) + a torre em si
class Tower extends Node2D:
	var radius: float = 400.0
	var body_scale: float = 1.0
	var color: Color = Color(0.3, 1.0, 0.5)
	var _time: float = 0.0
	var _body: TowerBody
	var _fade: Tween

	func _ready() -> void:
		z_as_relative = false
		z_index = -4000   # o campo fica em -4096
		modulate.a = 0.0
		_body = TowerBody.new()
		_body.color = color
		_body.body_scale = body_scale
		add_child(_body)
		_body.z_as_relative = false

	func set_radius(r: float) -> void:
		radius = r
		queue_redraw()

	func appear() -> void:
		_body.z_index = int(global_position.y)   # mesma regra de profundidade dos jogadores (a posição já foi definida)
		_kill_fade()
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 1.0, 0.4)

	func disappear() -> void:
		_kill_fade()
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 0.0, 0.4)
		_fade.tween_callback(queue_free)

	func _kill_fade() -> void:
		if _fade and _fade.is_valid():
			_fade.kill()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(color, 0.7), 3.0)
		# Anel interno que pulsa devagar (a torre "vigiando")
		var pulse: float = fmod(_time * 0.35, 1.0)
		draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 96, Color(color, 0.35 * (1.0 - pulse)), 2.0)


## A torre em si, "em pé" (sobe na tela, igual às traves do campo)
class TowerBody extends Node2D:
	var color: Color = Color(0.3, 1.0, 0.5)
	var body_scale: float = 1.0

	func _draw() -> void:
		var fill := Color(color, 0.5)
		var edge := Color(color, 0.95)
		var h: float = 90.0
		var s := Vector2(body_scale, body_scale)
		# Sombra no chão
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s.x, s.y * 0.4))
		draw_circle(Vector2.ZERO, 28.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, s)
		# Pernas e travessas em X
		draw_line(Vector2(-22, 0), Vector2(-14, -h), edge, 3.0)
		draw_line(Vector2(22, 0), Vector2(14, -h), edge, 3.0)
		draw_line(Vector2(-22, 0), Vector2(14, -h), Color(edge, 0.5), 2.0)
		draw_line(Vector2(22, 0), Vector2(-14, -h), Color(edge, 0.5), 2.0)
		# Plataforma, cabine, telhado e a "janela"
		draw_rect(Rect2(-20, -h - 4, 40, 6), fill)
		draw_rect(Rect2(-16, -h - 30, 32, 26), fill)
		draw_rect(Rect2(-16, -h - 30, 32, 26), edge, false, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-22, -h - 30), Vector2(22, -h - 30), Vector2(0, -h - 50)]), Color(edge, 0.7))
		draw_circle(Vector2(0, -h - 17), 5.0, Color(1, 1, 1, 0.75))


## Bússola verde translúcida que flutua sobre o aliado marcado: anel, pontos cardeais e uma agulha que oscila
class Mark extends Node2D:
	var target: Player
	var _time: float = 0.0
	var _alpha: float = 0.0
	var _closing: bool = false

	func _init() -> void:
		z_as_relative = false
		z_index = 2990

	func release() -> void:
		_closing = true

	func _process(delta: float) -> void:
		if not is_instance_valid(target):
			queue_free()
			return
		_time += delta
		if _closing:
			_alpha -= delta / 0.3
			if _alpha <= 0.0:
				queue_free()
				return
		else:
			_alpha = minf(_alpha + delta / 0.25, 1.0)
		global_position = target.global_position + Vector2(0.0, -target.height - target.placeholder_radius - 34.0 + sin(_time * 2.2) * 2.0)
		queue_redraw()

	func _draw() -> void:
		var a: float = _alpha
		var r: float = 13.0
		draw_circle(Vector2.ZERO, r, Color(DEEP_GREEN, 0.28 * a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(GREEN, 0.7 * a), 1.8)
		draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 20, Color(GREEN, 0.28 * a), 1.0)
		for i in 4:   # os quatro pontos cardeais (o norte é mais comprido)
			var d: Vector2 = Vector2.from_angle(-PI * 0.5 + PI * 0.5 * float(i))
			draw_line(d * (r - (5.0 if i == 0 else 3.0)), d * (r + 2.0), Color(LIGHT_GREEN, 0.85 * a), 1.6)
		# Agulha: um losango que balança em volta do norte
		var ang: float = -PI * 0.5 + sin(_time * 1.7) * 0.5
		var tip: Vector2 = Vector2.from_angle(ang) * (r * 0.72)
		var side: Vector2 = Vector2.from_angle(ang + PI * 0.5) * 2.4
		draw_colored_polygon(PackedVector2Array([tip, side, -tip * 0.55, -side]), Color(LIGHT_GREEN, 0.8 * a))
		draw_circle(Vector2.ZERO, 1.6, Color(GREEN, 0.95 * a))


## O radarzinho do Niko: ondas que saem dele pelo chão e uma varredura girando por dentro
class Radar extends Node2D:
	var radius: float = 62.0
	var active: bool = false:
		set(value):
			active = value
			visible = value
			set_process(value)
	var _time: float = 0.0

	func _init() -> void:
		show_behind_parent = true   # atrás do Niko: o radar fica no chão em volta dos pés
		visible = false
		set_process(false)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))   # achatado: é um radar no chão
		draw_circle(Vector2.ZERO, radius, Color(GREEN, 0.07))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(GREEN, 0.55), 2.0)
		draw_arc(Vector2.ZERO, radius * 0.5, 0.0, TAU, 32, Color(GREEN, 0.25), 1.0)
		# Duas ondas saindo do centro
		for i in 2:
			var k: float = fposmod(_time * 0.7 + float(i) * 0.5, 1.0)
			draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 40, Color(LIGHT_GREEN, 0.5 * (1.0 - k)), 1.8)
		# Varredura: a linha gira e deixa um rastro que apaga
		var sweep: float = _time * 2.4
		for s in 8:
			var a0: float = sweep - 0.09 * float(s)
			var fade: float = 1.0 - float(s) / 8.0
			draw_line(Vector2.ZERO, Vector2.from_angle(a0) * radius, Color(GREEN, 0.5 * fade * fade), 3.0 if s == 0 else 2.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(sweep) * radius, Color(LIGHT_GREEN, 0.9), 1.8)
