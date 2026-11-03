class_name FieldAtmosphere
extends Node
## CLIMA e HORÁRIO do campo: só visual, não muda nenhuma regra nem a jogabilidade.
##
##   Horário: Dia, Entardecer, Noite
##   Clima:   Limpo, Chuva, Neblina, Neve
##
## As mudanças são SUTIS e acontecem NO CAMPO (nada de filtro forte por cima da câmera):
##   - Entardecer: um brilho de sol alaranjado num canto e três raios de sol cruzando o gramado.
##   - Noite: o mundo escurece só um pouco (azulado) e 4 refletores nos cantos acendem manchas de luz no gramado
##            (com um facho fraquinho cada); sobra só uma vinheta azul-escura leve nas bordas da tela.
##   - Chuva: gotinhas curtas (visíveis, mas discretas), poucas poças d'água que REFLETEM jogadores e bola que passam por
##            elas, e ondinhas nas poças e no chão.
##   - Neve: pouca neve espalhada pelo campo (algumas manchas e pontinhos, mais perto das bordas) e poucos flocos caindo.
##   - Neblina: poucos bancos de névoa baixos e bem suaves, passando devagar pelo gramado.
##
## A escolha fica em variáveis estáticas, então vale da tela de formação até o fim da partida
## (e se mantém se você voltar ao menu e jogar de novo). Quem escolhe é o FormationExtras
## (formation_extras.gd), na tela de formação; o modo treino também pode usar
## FieldAtmosphere.set_time() / set_weather().
##
## Como funciona:
##   - um CanvasModulate tinge o MUNDO bem de leve (campo, jogadores, bola);
##   - um nó dentro do FIELD (filho dele, um passo acima do desenho do gramado e abaixo dos jogadores) desenha luzes,
##     poças, neve, ondinhas e névoa em coordenadas do campo (centro = 0,0; tamanho = Field.pitch_size);
##   - uma camada de tela (CanvasLayer 3, abaixo de todos os HUDs) só desenha a vinheta leve da noite e as
##     gotinhas/flocos esparsos.
## O MatchManager não precisa saber de nada: GameMode.apply_to() chama FieldAtmosphere.ensure().
##
## Leve: tudo que é fixo (luzes, poças, neve) é desenhado UMA vez por mudança de clima/horário; só as ondinhas da chuva
## redesenham (20x por segundo, no máximo 24 anéis), a névoa move 6 sprites e o reflexo de uma poça só existe (e só
## redesenha) enquanto alguém está sobre ela.

enum TimeOfDay { DAY, DUSK, NIGHT }
enum Weather { CLEAR, RAIN, FOG, SNOW }

const TIME_NAMES: Array[String] = ["Dia", "Entardecer", "Noite"]
const WEATHER_NAMES: Array[String] = ["Limpo", "Chuva", "Neblina", "Neve"]

static var time_of_day: int = TimeOfDay.DAY
static var weather: int = Weather.CLEAR

static var _radial_tex: GradientTexture2D

var _tint: CanvasModulate
var _layer: CanvasLayer
var _fx: _Sky
var _world: _World


## Cria (uma vez) o efeito na cena e já aplica a escolha atual. Devolve o nó.
static func ensure(from: Node) -> FieldAtmosphere:
	var tree: SceneTree = from.get_tree()
	if tree == null:
		return null
	var found := tree.get_first_node_in_group("field_atmosphere") as FieldAtmosphere
	if found != null:
		return found
	var node := FieldAtmosphere.new()
	node.name = "FieldAtmosphere"
	node.add_to_group("field_atmosphere")
	from.add_child(node)
	return node


static func set_time(value: int, from: Node = null) -> void:
	time_of_day = clampi(value, 0, TIME_NAMES.size() - 1)
	_refresh_all(from)


static func set_weather(value: int, from: Node = null) -> void:
	weather = clampi(value, 0, WEATHER_NAMES.size() - 1)
	_refresh_all(from)


static func _refresh_all(from: Node) -> void:
	var tree: SceneTree = from.get_tree() if from != null else Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("field_atmosphere"):
		(n as FieldAtmosphere).refresh()


## Cor com que o MUNDO é tingido (também usada para pré-visualizar no campo da tela de formação). Bem suave.
static func world_color(t: int = -1, w: int = -1) -> Color:
	var tt: int = time_of_day if t < 0 else t
	var ww: int = weather if w < 0 else w
	var c: Color = Color.WHITE
	match tt:
		TimeOfDay.DUSK:
			c = Color(1.0, 0.92, 0.82)
		TimeOfDay.NIGHT:
			c = Color(0.68, 0.74, 0.92)
	match ww:
		Weather.RAIN:
			c = c * Color(0.94, 0.96, 0.99)
		Weather.FOG:
			c = c * Color(0.97, 0.98, 0.99)
		Weather.SNOW:
			c = c * Color(0.97, 0.98, 1.0)
	return c


## Camada que escurece o campo da tela de formação (alpha 0 = sem efeito). Só uma sugestão leve do horário.
static func pitch_tint(t: int = -1, w: int = -1) -> Color:
	var tt: int = time_of_day if t < 0 else t
	var ww: int = weather if w < 0 else w
	var c := Color(0, 0, 0, 0)
	match tt:
		TimeOfDay.DUSK:
			c = Color(1.0, 0.55, 0.25, 0.10)
		TimeOfDay.NIGHT:
			c = Color(0.03, 0.06, 0.25, 0.22)
	if ww == Weather.RAIN:
		c = Color(c.r * 0.8, c.g * 0.8, c.b * 0.9 + 0.03, minf(c.a + 0.04, 0.5))
	return c


## Textura de brilho redondo (branca no centro, transparente na borda): base das manchas de luz e das névoas
static func _radial() -> GradientTexture2D:
	if _radial_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_radial_tex = t
	return _radial_tex


## Desenha (dentro do _draw de `c`) um brilho redondo
static func _glow(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	c.draw_texture_rect(_radial(), Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), false, color)


## Contorno irregular (arredondado) em volta de um centro: poças e manchas de neve
static func _blob(center: Vector2, rx: float, ry: float, wobble: float, rng: RandomNumberGenerator, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a: float = TAU * float(i) / float(points)
		var f: float = 1.0 + rng.randf_range(-wobble, wobble)
		pts.append(center + Vector2(cos(a) * rx * f, sin(a) * ry * f))
	return pts


## Retângulo ESPELHADO (na vertical, em volta da linha do chão `ground_y`) de um sprite (Sprite2D / AnimatedSprite2D), em
## coordenadas do mundo. O tamanho em y é negativo: o draw_texture_rect desenha virado de cabeça para baixo.
static func _mirror_rect(s: Node2D, tex: Texture2D, ground_y: float) -> Rect2:
	var ts: Vector2 = tex.get_size()
	var gs: Vector2 = s.global_scale.abs()
	var size: Vector2 = ts * gs
	var off: Vector2 = s.get("offset") as Vector2
	var top_left: Vector2 = s.global_position + (off - (ts * 0.5 if bool(s.get("centered")) else Vector2.ZERO)) * gs
	var mirror_bottom: float = 2.0 * ground_y - top_left.y   # a borda de cima vira a de baixo
	if bool(s.get("flip_h")):
		return Rect2(Vector2(top_left.x + size.x, mirror_bottom), Vector2(-size.x, -size.y))
	return Rect2(Vector2(top_left.x, mirror_bottom), Vector2(size.x, -size.y))


func _ready() -> void:
	add_to_group("field_atmosphere")
	_tint = CanvasModulate.new()
	add_child(_tint)
	_layer = CanvasLayer.new()
	_layer.layer = 3   # acima do mundo, abaixo dos HUDs (8 a 12)
	add_child(_layer)
	_fx = _Sky.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fx)
	refresh()
	_attach_world.call_deferred()


## Pendura os efeitos do campo DENTRO do Field (espera ele existir: tenta por alguns quadros)
func _attach_world() -> void:
	for _try in 60:
		if _world != null and is_instance_valid(_world):
			return
		var f := get_tree().get_first_node_in_group("field") as Field
		if f != null and f.pitch_size.x > 1.0:
			_world = _World.new()
			f.add_child(_world)
			_world.setup(f.pitch_size)
			_world.apply(time_of_day, weather)
			return
		await get_tree().process_frame


func refresh() -> void:
	if _tint == null:
		return
	_tint.color = world_color()
	_fx.time_of_day = time_of_day
	_fx.weather = weather
	_fx.reset()
	if _world != null and is_instance_valid(_world):
		_world.apply(time_of_day, weather)


# ---------- EFEITOS NO CAMPO ----------

## Contêiner dentro do Field: um passo acima do desenho do gramado (z relativo +1) e abaixo dos jogadores.
## Se alguma coisa aparecer por cima dos jogadores ou por baixo do gramado, mude o z_index aqui.
class _World extends Node2D:
	var pitch: Vector2 = Vector2(1600.0, 900.0)
	var _ground: _Ground
	var _mist: _Mist
	var _ripples: _Ripples
	var _light: _Light
	var _reflections: _Puddles

	func _init() -> void:
		name = "AtmosphereWorld"
		z_index = 1

	func setup(p: Vector2) -> void:
		pitch = p
		_ground = _Ground.new()
		_mist = _Mist.new()
		_ripples = _Ripples.new()
		_light = _Light.new()
		_reflections = _Puddles.new()
		for n: Node in [_ground, _reflections, _mist, _ripples, _light]:   # a luz (aditiva) por último, em cima
			add_child(n)

	func apply(t: int, w: int) -> void:
		_ground.apply(pitch, w)
		_reflections.apply(w, _ground.puddle_polys, _ground.puddle_centers, _ground.puddle_radii)
		_mist.apply(pitch, w)
		_ripples.apply(pitch, w, _ground.puddle_centers, _ground.puddle_radii)
		_light.apply(pitch, t)


## Poças d'água (chuva) e neve espalhada (neve): fixas, desenhadas uma vez
class _Ground extends Node2D:
	var pitch: Vector2 = Vector2.ONE
	var weather: int = 0
	var puddle_centers: PackedVector2Array = PackedVector2Array()
	var puddle_radii: PackedFloat32Array = PackedFloat32Array()
	var puddle_polys: Array[PackedVector2Array] = []
	var _snow: Array[PackedVector2Array] = []
	var _snow_alpha: Array[float] = []
	var _dots: PackedVector2Array = PackedVector2Array()
	var _dot_r: PackedFloat32Array = PackedFloat32Array()

	func apply(p: Vector2, w: int) -> void:
		pitch = p
		weather = w
		puddle_polys.clear()
		puddle_centers.clear()
		puddle_radii.resize(0)
		_snow.clear()
		_snow_alpha.clear()
		_dots.clear()
		_dot_r.resize(0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260502   # sempre o mesmo desenho (não muda a cada refresh)
		var hx: float = pitch.x * 0.5
		var hy: float = pitch.y * 0.5
		if weather == FieldAtmosphere.Weather.RAIN:
			for i in 4:   # poucas poças, um pouco maiores
				var c := Vector2(rng.randf_range(-hx * 0.8, hx * 0.8), rng.randf_range(-hy * 0.75, hy * 0.75))
				var rx: float = rng.randf_range(58.0, 115.0)
				puddle_polys.append(FieldAtmosphere._blob(c, rx, rx * rng.randf_range(0.38, 0.5), 0.18, rng, 16))
				puddle_centers.append(c)
				puddle_radii.append(rx)
		elif weather == FieldAtmosphere.Weather.SNOW:
			for i in 14:   # pouca neve espalhada
				var c := Vector2(rng.randf_range(-hx, hx), rng.randf_range(-hy, hy))
				if rng.randf() < 0.6:   # mais neve perto das bordas do que no meio do campo
					c.y = signf(c.y) * hy * rng.randf_range(0.78, 1.0)
				var rx: float = rng.randf_range(16.0, 58.0)
				_snow.append(FieldAtmosphere._blob(c, rx, rx * rng.randf_range(0.4, 0.6), 0.25, rng, 12))
				_snow_alpha.append(rng.randf_range(0.45, 0.62))
			for i in 45:
				_dots.append(Vector2(rng.randf_range(-hx, hx), rng.randf_range(-hy, hy)))
				_dot_r.append(rng.randf_range(0.8, 2.2))
		visible = weather == FieldAtmosphere.Weather.RAIN or weather == FieldAtmosphere.Weather.SNOW
		queue_redraw()

	func _draw() -> void:
		for pts: PackedVector2Array in puddle_polys:
			var c: Vector2 = Vector2.ZERO
			for p: Vector2 in pts:
				c += p
			c /= float(pts.size())
			draw_colored_polygon(pts, Color(0.16, 0.26, 0.42, 0.28))   # a água, um tom azulado escuro
			var shine := PackedVector2Array()
			for p: Vector2 in pts:   # reflexo: a mesma poça menor, deslocada para cima
				shine.append(c + (p - c) * 0.55 + Vector2(-3.0, -2.0))
			draw_colored_polygon(shine, Color(0.75, 0.88, 1.0, 0.12))
			var rim: PackedVector2Array = pts.duplicate()
			rim.append(pts[0])
			draw_polyline(rim, Color(0.8, 0.9, 1.0, 0.22), 1.2)
		for i in _snow.size():
			var pts: PackedVector2Array = _snow[i]
			var shadow := PackedVector2Array()
			for p: Vector2 in pts:
				shadow.append(p + Vector2(2.0, 3.0))
			draw_colored_polygon(shadow, Color(0.55, 0.65, 0.85, 0.16))   # sombrinha azulada embaixo
			draw_colored_polygon(pts, Color(0.97, 0.98, 1.0, _snow_alpha[i]))
		for i in _dots.size():
			draw_circle(_dots[i], _dot_r[i], Color(1, 1, 1, 0.5))


## Reflexo nas poças: enquanto jogador, goleiro ou bola estão em cima de uma poça (ou logo acima dela), a imagem deles aparece
## espelhada na água, recortada no formato da poça. Poça vazia = nada ligado (nem desenhado).
class _Puddles extends Node2D:
	var _list: Array[_Puddle] = []
	var _acc: float = 0.0

	func apply(w: int, polys: Array[PackedVector2Array], centers: PackedVector2Array, radii: PackedFloat32Array) -> void:
		for c in get_children():
			c.queue_free()
		_list.clear()
		var rain: bool = w == FieldAtmosphere.Weather.RAIN
		set_process(rain)
		if not rain:
			return
		for i in polys.size():
			var p := _Puddle.new()
			p.setup(polys[i], centers[i], radii[i])
			add_child(p)
			_list.append(p)

	func _process(delta: float) -> void:
		_acc += delta
		if _acc < 0.05:   # 20x por segundo
			return
		_acc = 0.0
		var ents: Array[Dictionary] = _gather()
		for p: _Puddle in _list:
			p.show_reflections(ents)

	## Imagem espelhada de quem está em campo: {pos (pés), tex, rect (já espelhado), r, color}
	func _gather() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for n in get_tree().get_nodes_in_group("players"):
			var pl := n as Player
			if pl == null or not pl.visible:
				continue
			var s: Node2D = null
			var tex: Texture2D = null
			if pl._has_art and pl.animated_sprite != null:
				s = pl.animated_sprite
				tex = pl.animated_sprite.sprite_frames.get_frame_texture(pl.animated_sprite.animation, pl.animated_sprite.frame)
			elif pl.tint_sprite != null and pl.tint_sprite.texture != null:
				s = pl.tint_sprite
				tex = pl.tint_sprite.texture
			var e := {"pos": pl.global_position, "tex": tex, "r": pl.placeholder_radius, "color": TeamStyle.color_of(pl.team)}
			if tex != null:
				e["rect"] = FieldAtmosphere._mirror_rect(s, tex, pl.global_position.y)
			else:   # sem imagem: um círculo na cor do time
				e["pos2"] = pl.global_position + Vector2(0.0, pl.placeholder_radius * 0.6 + pl.height)
			out.append(e)
		for n in get_tree().get_nodes_in_group("goalkeepers"):
			var g := n as Goalkeeper
			if g == null or g.art_texture == null:
				continue
			var h: float = g.art_height
			var w: float = h * g.art_texture.get_size().x / maxf(g.art_texture.get_size().y, 1.0)
			var gp: Vector2 = g.global_position
			var flip: bool = (g._dir() < 0) != g.art_faces_right
			var top: float = gp.y + h + g.height   # o topo da cabeça espelhado
			var rect := Rect2(Vector2(gp.x + (w * 0.5 if flip else -w * 0.5), top), Vector2(-w if flip else w, -h))
			out.append({"pos": gp, "tex": g.art_texture, "rect": rect, "r": g.body_radius, "color": Color.WHITE})
		var ball := get_tree().get_first_node_in_group("ball") as Ball
		if ball != null and ball.sprite != null and ball.sprite.texture != null:
			out.append({"pos": ball.global_position, "tex": ball.sprite.texture,
				"rect": FieldAtmosphere._mirror_rect(ball.sprite, ball.sprite.texture, ball.global_position.y),
				"r": ball.ball_radius, "color": Color.WHITE})
		return out


## Uma poça: máscara (o desenho dela recorta os filhos) + o nó que desenha o reflexo
class _Puddle extends Node2D:
	var poly: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = Vector2.ZERO
	var rx: float = 50.0
	var _reflect: _Reflect

	func setup(pts: PackedVector2Array, c: Vector2, r: float) -> void:
		poly = pts
		center = c
		rx = r
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY   # o que os filhos desenham só aparece dentro do formato da poça
		visible = false   # desligada (e sem custo) até alguém passar por cima
		_reflect = _Reflect.new()
		add_child(_reflect)

	func _draw() -> void:
		draw_colored_polygon(poly, Color.WHITE)   # só a máscara (a água em si é desenhada pelo _Ground)

	func show_reflections(ents: Array[Dictionary]) -> void:
		var here: Array[Dictionary] = []
		for e: Dictionary in ents:   # em cima da poça (um pouco acima também: o reflexo cai para baixo dos pés)
			var d: Vector2 = ((e["pos"] as Vector2) - center) / Vector2(rx * 1.1, rx * 0.65)
			if d.length_squared() <= 1.0:
				here.append(e)
		if here.is_empty():
			if visible:
				visible = false
				_reflect.ents.clear()
			return
		visible = true
		_reflect.ents = here
		_reflect.queue_redraw()


## Desenha as imagens espelhadas (em coordenadas do mundo), azuladas e translúcidas
class _Reflect extends Node2D:
	var ents: Array[Dictionary] = []

	func _init() -> void:
		modulate = Color(0.75, 0.86, 1.0, 0.45)

	func _draw() -> void:
		draw_set_transform_matrix(get_global_transform().affine_inverse())   # desenha direto em coordenadas do mundo
		for e: Dictionary in ents:
			if e["tex"] != null:
				draw_texture_rect(e["tex"] as Texture2D, e["rect"] as Rect2, false)
			else:
				draw_circle(e["pos2"] as Vector2, float(e["r"]), Color(e["color"] as Color, 0.8))


## Ondinhas da chuva (anéis achatados que abrem e somem), mais frequentes nas poças
class _Ripples extends Node2D:
	const MAX_RIPPLES: int = 24
	const SPAWN_PER_SEC: float = 9.0

	var pitch: Vector2 = Vector2.ONE
	var _centers: PackedVector2Array = PackedVector2Array()
	var _radii: PackedFloat32Array = PackedFloat32Array()
	var _rip: Array[Dictionary] = []   # {pos, age, life, max_r}
	var _spawn: float = 0.0
	var _redraw: float = 0.0
	var _rng := RandomNumberGenerator.new()

	func _init() -> void:
		_rng.randomize()

	func apply(p: Vector2, w: int, centers: PackedVector2Array, radii: PackedFloat32Array) -> void:
		pitch = p
		_centers = centers
		_radii = radii
		_rip.clear()
		var rain: bool = w == FieldAtmosphere.Weather.RAIN
		visible = rain
		set_process(rain)
		queue_redraw()

	func _process(delta: float) -> void:
		var dt: float = minf(delta, 0.05)
		_spawn += dt * SPAWN_PER_SEC
		while _spawn >= 1.0:
			_spawn -= 1.0
			if _rip.size() < MAX_RIPPLES:
				_rip.append({"pos": _random_spot(), "age": 0.0, "life": _rng.randf_range(0.7, 1.1), "max_r": _rng.randf_range(9.0, 16.0)})
		for i in range(_rip.size() - 1, -1, -1):
			_rip[i]["age"] = float(_rip[i]["age"]) + dt
			if float(_rip[i]["age"]) >= float(_rip[i]["life"]):
				_rip.remove_at(i)
		_redraw += dt
		if _redraw >= 0.05:   # 20 quadros por segundo bastam
			_redraw = 0.0
			queue_redraw()

	## 55% das ondinhas caem dentro de uma poça; o resto, em qualquer ponto do gramado
	func _random_spot() -> Vector2:
		if _centers.size() > 0 and _rng.randf() < 0.55:
			var i: int = _rng.randi() % _centers.size()
			var r: float = _radii[i]
			return _centers[i] + Vector2(_rng.randf_range(-r, r) * 0.7, _rng.randf_range(-r, r) * 0.25)
		return Vector2(_rng.randf_range(-pitch.x * 0.5, pitch.x * 0.5), _rng.randf_range(-pitch.y * 0.5, pitch.y * 0.5))

	func _draw() -> void:
		for r: Dictionary in _rip:
			var k: float = float(r["age"]) / float(r["life"])
			var radius: float = float(r["max_r"]) * (1.0 - pow(1.0 - k, 2.0))   # abre rápido e desacelera
			var a: float = 0.6 * (1.0 - k)
			draw_set_transform(r["pos"] as Vector2, 0.0, Vector2(1.0, 0.5))   # achatado: visto de cima em perspectiva
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 18, Color(0.85, 0.93, 1.0, a), 1.2)
			draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 14, Color(0.85, 0.93, 1.0, a * 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Bancos de névoa baixos e suaves que passam devagar pelo gramado (6 sprites; só movem, não redesenham)
class _Mist extends Node2D:
	var pitch: Vector2 = Vector2.ONE
	var _speeds: Array[float] = []

	func apply(p: Vector2, w: int) -> void:
		pitch = p
		for c in get_children():
			c.queue_free()
		_speeds.clear()
		var fog: bool = w == FieldAtmosphere.Weather.FOG
		visible = fog
		set_process(fog)
		if not fog:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = 90210
		for i in 6:
			var s := Sprite2D.new()
			s.texture = FieldAtmosphere._radial()
			var width: float = pitch.x * rng.randf_range(0.28, 0.45)
			s.scale = Vector2(width / 128.0, width * 0.42 / 128.0)   # banco comprido e baixo
			s.modulate = Color(0.88, 0.92, 0.96, rng.randf_range(0.10, 0.16))
			s.position = Vector2(rng.randf_range(-pitch.x * 0.5, pitch.x * 0.5), rng.randf_range(-pitch.y * 0.45, pitch.y * 0.45))
			add_child(s)
			_speeds.append(rng.randf_range(5.0, 12.0) * (1.0 if rng.randf() < 0.5 else -1.0))

	func _process(delta: float) -> void:
		var limit: float = pitch.x * 0.5
		var i: int = 0
		for c in get_children():
			var s := c as Sprite2D
			if s == null or s.is_queued_for_deletion() or i >= _speeds.size():
				continue
			s.position.x += _speeds[i] * delta
			var half_w: float = s.scale.x * 64.0
			if s.position.x > limit + half_w:
				s.position.x = -limit - half_w
			elif s.position.x < -limit - half_w:
				s.position.x = limit + half_w
			i += 1


## Luzes (mistura ADITIVA): sol do entardecer e refletores da noite. Fixas; o entardecer só "respira" um pouquinho.
class _Light extends Node2D:
	var pitch: Vector2 = Vector2.ONE
	var time_of_day: int = 0
	var _t: float = 0.0

	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func apply(p: Vector2, t: int) -> void:
		pitch = p
		time_of_day = t
		_t = 0.0
		modulate.a = 1.0
		set_process(t == FieldAtmosphere.TimeOfDay.DUSK)
		visible = t != FieldAtmosphere.TimeOfDay.DAY
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		modulate.a = 0.88 + 0.12 * sin(_t * 0.6)   # os raios de sol variam de leve (sem redesenhar)

	func _draw() -> void:
		match time_of_day:
			FieldAtmosphere.TimeOfDay.DUSK:
				_draw_sun()
			FieldAtmosphere.TimeOfDay.NIGHT:
				_draw_floodlights()

	## Sol baixo no canto de cima à esquerda: brilho alaranjado e três raios suaves cruzando o campo
	func _draw_sun() -> void:
		var sun := Vector2(-pitch.x * 0.55, -pitch.y * 0.85)
		var aim := Vector2(pitch.x * 0.05, pitch.y * 0.05)
		var dir: Vector2 = (aim - sun).normalized()
		FieldAtmosphere._glow(self, sun, pitch.y * 1.0, Color(1.0, 0.6, 0.22, 0.22))
		FieldAtmosphere._glow(self, sun.lerp(aim, 0.25), pitch.y * 0.75, Color(1.0, 0.7, 0.35, 0.07))
		for k in 3:
			var d: Vector2 = dir.rotated((float(k) - 1.0) * 0.07)
			var start: Vector2 = sun + d.orthogonal() * (float(k) - 1.0) * pitch.y * 0.05
			_shaft(start, d, pitch.x * 1.45, 24.0, pitch.y * (0.17 + 0.04 * float(k)), 0.14 - 0.025 * float(k))

	## Raio de sol: faixa que alarga e esmaece, mais forte no meio e transparente nas bordas
	func _shaft(origin: Vector2, d: Vector2, length: float, w0: float, w1: float, a: float) -> void:
		var side: Vector2 = d.orthogonal()
		var col := Color(1.0, 0.66, 0.3)
		var steps: int = 6
		for i in steps:
			var t0: float = float(i) / float(steps)
			var t1: float = float(i + 1) / float(steps)
			var c0: Vector2 = origin + d * length * t0
			var c1: Vector2 = origin + d * length * t1
			var h0: float = lerpf(w0, w1, t0) * 0.5
			var h1: float = lerpf(w0, w1, t1) * 0.5
			var edge := Color(col, 0.0)
			for sgn in [-1.0, 1.0]:
				draw_polygon(PackedVector2Array([c0, c0 + side * h0 * sgn, c1 + side * h1 * sgn, c1]),
					PackedColorArray([Color(col, a * (1.0 - t0)), edge, edge, Color(col, a * (1.0 - t1))]))

	## 4 refletores simples nos cantos: lâmpada com um clarão, facho fraquinho e uma mancha de luz no gramado
	func _draw_floodlights() -> void:
		var warm := Color(1.0, 0.96, 0.82)
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var lamp := Vector2(c.x * (pitch.x * 0.5 + 60.0), c.y * (pitch.y * 0.5 + 60.0))
			var pool: Vector2 = lamp.lerp(Vector2.ZERO, 0.62)
			var perp: Vector2 = (pool - lamp).normalized().orthogonal()
			FieldAtmosphere._glow(self, pool, pitch.y * 0.72, Color(warm, 0.13))   # a mancha de luz no gramado
			draw_polygon(PackedVector2Array([lamp, pool + perp * pitch.y * 0.3, pool - perp * pitch.y * 0.3]),
				PackedColorArray([Color(warm, 0.10), Color(warm, 0.0), Color(warm, 0.0)]))   # facho fraquinho
			FieldAtmosphere._glow(self, lamp, 38.0, Color(warm, 0.85))   # a lâmpada
			for k in 4:   # clarão em cruz
				var v: Vector2 = Vector2.from_angle(float(k) * PI * 0.5 + 0.4) * 34.0
				draw_line(lamp - v, lamp + v, Color(warm, 0.45), 1.5)


## Desenho na tela (camada 3): só uma vinheta azul-escura leve à noite e gotinhas/flocos esparsos
class _Sky extends Control:
	var time_of_day: int = 0
	var weather: int = 0
	var _drops: PackedVector2Array = PackedVector2Array()   # posição normalizada (0..1)
	var _speeds: PackedFloat32Array = PackedFloat32Array()
	var _t: float = 0.0
	var _vignette: GradientTexture2D

	func _init() -> void:
		_vignette = GradientTexture2D.new()
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.55, 1.0])
		g.colors = PackedColorArray([Color(0.02, 0.04, 0.18, 0.0), Color(0.02, 0.04, 0.18, 0.28)])   # azul-escuro, bem leve
		_vignette.gradient = g
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.0, 0.5)
		_vignette.width = 256
		_vignette.height = 256

	func reset() -> void:
		var count: int = 0
		match weather:
			FieldAtmosphere.Weather.RAIN:
				count = 95
			FieldAtmosphere.Weather.SNOW:
				count = 18
		_drops.resize(count)
		_speeds.resize(count)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in count:
			_drops[i] = Vector2(rng.randf(), rng.randf())
			_speeds[i] = rng.randf_range(0.6, 1.4)
		set_process(count > 0)
		queue_redraw()

	func _process(delta: float) -> void:
		var dt: float = minf(delta, 0.05)
		_t += dt
		for i in _drops.size():
			var d: Vector2 = _drops[i]
			match weather:
				FieldAtmosphere.Weather.RAIN:
					d.y += dt * 1.5 * _speeds[i]
					d.x -= dt * 0.18 * _speeds[i]
				FieldAtmosphere.Weather.SNOW:
					d.y += dt * 0.10 * _speeds[i]
					d.x += sin(_t * 0.9 + float(i)) * dt * 0.03
			if d.y > 1.05:
				d.y -= 1.1
			if d.x < -0.1:
				d.x += 1.2
			if d.x > 1.1:
				d.x -= 1.2
			_drops[i] = d
		queue_redraw()

	func _draw() -> void:
		if time_of_day == FieldAtmosphere.TimeOfDay.NIGHT:
			draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
		match weather:
			FieldAtmosphere.Weather.RAIN:
				for i in _drops.size():   # gotinhas curtas e discretas
					var p: Vector2 = _drops[i] * size
					var len: float = 11.0 + 5.0 * _speeds[i]
					draw_line(p, p + Vector2(-len * 0.12, len), Color(0.8, 0.88, 1.0, 0.42), 1.7)
			FieldAtmosphere.Weather.SNOW:
				for i in _drops.size():   # poucos flocos pequenos
					draw_circle(_drops[i] * size, 1.0 + 1.2 * _speeds[i], Color(1, 1, 1, 0.6))
