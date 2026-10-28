class_name FieldAtmosphere
extends Node
## CLIMA e HORÁRIO do campo: só visual, não muda nenhuma regra.
##
##   Horário: Dia, Entardecer, Noite   (cor da cena + vinheta escura à noite)
##   Clima:   Limpo, Chuva, Neblina, Neve   (partículas na tela)
##
## A escolha fica em variáveis estáticas, então vale da tela de formação até o fim da partida
## (e se mantém se você voltar ao menu e jogar de novo). Quem escolhe é o FormationExtras
## (formation_extras.gd), na tela de formação; o modo treino também pode usar
## FieldAtmosphere.set_time() / set_weather().
##
## Como funciona: um CanvasModulate tinge o MUNDO (campo, jogadores, bola), e uma camada de
## tela (CanvasLayer 3, abaixo de todos os HUDs) desenha chuva/neve/neblina/vinheta.
## O MatchManager não precisa saber de nada: GameMode.apply_to() chama FieldAtmosphere.ensure().

enum TimeOfDay { DAY, DUSK, NIGHT }
enum Weather { CLEAR, RAIN, FOG, SNOW }

const TIME_NAMES: Array[String] = ["Dia", "Entardecer", "Noite"]
const WEATHER_NAMES: Array[String] = ["Limpo", "Chuva", "Neblina", "Neve"]

static var time_of_day: int = TimeOfDay.DAY
static var weather: int = Weather.CLEAR

var _tint: CanvasModulate
var _layer: CanvasLayer
var _fx: _Sky


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


## Cor com que o MUNDO é tingido (também usada para pré-visualizar no campo da tela de formação)
static func world_color(t: int = -1, w: int = -1) -> Color:
	var tt: int = time_of_day if t < 0 else t
	var ww: int = weather if w < 0 else w
	var c: Color = Color.WHITE
	match tt:
		TimeOfDay.DUSK:
			c = Color(1.0, 0.76, 0.58)
		TimeOfDay.NIGHT:
			c = Color(0.45, 0.52, 0.85)
	match ww:
		Weather.RAIN:
			c = c * Color(0.86, 0.9, 0.97)
		Weather.FOG:
			c = c * Color(0.93, 0.95, 0.97)
		Weather.SNOW:
			c = c * Color(0.95, 0.97, 1.0)
	return c


## Camada que escurece o campo da tela de formação (alpha 0 = sem efeito)
static func pitch_tint(t: int = -1, w: int = -1) -> Color:
	var tt: int = time_of_day if t < 0 else t
	var ww: int = weather if w < 0 else w
	var c := Color(0, 0, 0, 0)
	match tt:
		TimeOfDay.DUSK:
			c = Color(1.0, 0.5, 0.2, 0.2)
		TimeOfDay.NIGHT:
			c = Color(0.03, 0.06, 0.25, 0.5)
	if ww == Weather.RAIN:
		c = Color(c.r * 0.7, c.g * 0.7, c.b * 0.8 + 0.05, minf(c.a + 0.12, 0.7))
	return c


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


func refresh() -> void:
	if _tint == null:
		return
	_tint.color = world_color()
	_fx.time_of_day = time_of_day
	_fx.weather = weather
	_fx.reset()


## Desenho do céu: vinheta da noite + chuva / neve / neblina
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
		g.offsets = PackedFloat32Array([0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0.04, 0.0), Color(0, 0, 0.04, 0.62)])
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
				count = 260
			FieldAtmosphere.Weather.SNOW:
				count = 150
			FieldAtmosphere.Weather.FOG:
				count = 9
		_drops.resize(count)
		_speeds.resize(count)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in count:
			_drops[i] = Vector2(rng.randf(), rng.randf())
			_speeds[i] = rng.randf_range(0.6, 1.4)
		set_process(weather != FieldAtmosphere.Weather.CLEAR)
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
					d.y += dt * 0.12 * _speeds[i]
					d.x += sin(_t * 0.9 + float(i)) * dt * 0.035
				FieldAtmosphere.Weather.FOG:
					d.x += dt * 0.012 * _speeds[i]
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
		elif time_of_day == FieldAtmosphere.TimeOfDay.DUSK:
			draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(1.0, 0.45, 0.2, 0.35))
		match weather:
			FieldAtmosphere.Weather.RAIN:
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.15, 0.1))
				for i in _drops.size():
					var p: Vector2 = _drops[i] * size
					var len: float = 22.0 * _speeds[i]
					draw_line(p, p + Vector2(-len * 0.12, len), Color(0.75, 0.85, 1.0, 0.33), 1.6)
			FieldAtmosphere.Weather.SNOW:
				for i in _drops.size():
					draw_circle(_drops[i] * size, 2.0 + 2.2 * _speeds[i], Color(1, 1, 1, 0.8))
			FieldAtmosphere.Weather.FOG:
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.85, 0.9, 0.12))
				for i in _drops.size():
					var c: Vector2 = _drops[i] * size
					var r: float = size.y * (0.28 + 0.12 * _speeds[i])
					for k in 4:
						draw_circle(c, r * (1.0 - 0.2 * k), Color(0.85, 0.9, 0.95, 0.035))
