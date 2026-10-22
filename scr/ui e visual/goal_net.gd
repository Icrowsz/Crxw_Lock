class_name GoalNet
extends Node2D
## Rede do gol estilo "VÉU DE NOIVA": um tecido leve e translúcido, feito de uma malha de pontos
## ligados por molas, que se move de forma bem visível.
##
## - A borda da linha de fundo e as duas laterais ficam presas às traves (não se mexem). O resto é
##   livre: a borda de trás (o "barrado" do véu) é a que mais voa.
## - ONDAS QUE VIAJAM: quando a bola bate, o pico de energia anda pela rede como uma onda
##   (a rede é "unida": cada ponto puxa os vizinhos), vai até as traves e volta.
## - LUZ E SOMBRA NAS DOBRAS: cada ponto é pintado conforme a inclinação e a curvatura do tecido:
##   as cristas das ondas brilham e os vales ficam azulados, como seda ao vento.
## - Chutes fortes ESTICAM a rede de verdade: ela vira um "bolsão", a malha fica tensa e brilhante,
##   os nós se acendem e ela volta balançando como elástico (quanto mais forte, mais balança).
## - Os pontos deslocados "sobem" um pouco na tela (igual à altura da bola): lê como o véu inflando.
## - Parada, ela ainda respira com uma brisa muito leve (idle_flutter), redesenhada devagar.
##   Quando a simulação para, ela "dorme" e não gasta processamento de física.
##
## O Field cria uma GoalNet por gol. Dá para chamar de fora (ex: o goleiro):
##   field.poke_net(global_pos, velocidade, forca)

@export var rect: Rect2 = Rect2(0.0, -130.0, 90.0, 260.0)   # área da rede (coordenadas do Field)
@export var front_is_min_x: bool = true     # a linha de fundo (boca do gol) é o lado de menor x?
@export var cell_size: float = 10.0         # tamanho de cada quadradinho da malha
@export var stiffness: float = 45.0         # força que devolve o véu ao repouso (baixa = flutua mais)
@export var damping: float = 2.4            # quanto ele demora para parar de balançar
@export var coupling: float = 240.0         # quanto cada ponto puxa os vizinhos (velocidade das ondas)
@export var bulge: float = 1.25             # multiplicador geral do estufar
@export var max_offset: float = 190.0       # deslocamento máximo de um ponto (px)
@export var drag_gain: float = 0.6          # quanto a bola em movimento arrasta a rede
@export_range(1, 4) var substeps: int = 2   # a simulação roda em passos menores (ondas rápidas ficam estáveis)
@export_group("Esticar (chutes fortes)")
@export var stretch_power: float = 2.0      # exagero nos chutes fortes (0 = proporcional ao chute)
@export var pinch: float = 1.6              # quanto os lados são puxados para a bola (forma de bolsão)
@export var puff: float = 0.9               # quanto o estufar "sobe" na tela
@export var max_puff: float = 110.0         # altura máxima desse "subir" (px)
@export var wobble: float = 1.0             # chute forte deixa a rede mais elástica (balança mais)
@export var strain_range: float = 60.0      # deslocamento (px) em que a malha fica 100% tensa
@export_group("Véu (brisa parada)")
@export var idle_flutter: bool = true       # a rede respira mesmo sem chute
@export var flutter_amount: float = 2.4     # tamanho da brisa (px)
@export var flutter_speed: float = 1.4
@export_group("Cores")
@export var veil_color: Color = Color(0.94, 0.97, 1.0, 0.14)       # o tecido (translúcido)
@export var shadow_color: Color = Color(0.42, 0.55, 0.85)          # vales das dobras
@export var glint_color: Color = Color(1.0, 1.0, 0.95)             # cristas das ondas
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.16)         # fios da malha
@export var stretched_color: Color = Color(1.0, 1.0, 1.0, 0.85)    # fios muito esticados
@export var hem_color: Color = Color(1.0, 1.0, 1.0, 0.7)           # barrado (borda de trás)
@export var frame_color: Color = Color(1.0, 1.0, 1.0, 0.6)

var _cols: int = 2
var _rows: int = 2
var _rest: PackedVector2Array = PackedVector2Array()
var _off: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _awake: bool = false
## Multiplicador do amortecimento: cai nos chutes fortes (rede mais elástica) e volta a 1 sozinho
var _damp_mult: float = 1.0
## Clarões do impacto: {"pos": Vector2 local, "age": float, "size": float}
var _flashes: Array[Dictionary] = []

# Desenho (preenchidos a cada redesenho)
var _pts: PackedVector2Array = PackedVector2Array()
var _lift: PackedFloat32Array = PackedFloat32Array()
var _colors: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()
var _mesh: ArrayMesh
var _flutter_t: float = randf() * 10.0
var _idle_acc: float = 0.0


func _ready() -> void:
	_cols = maxi(2, roundi(rect.size.x / cell_size) + 1)
	_rows = maxi(2, roundi(rect.size.y / cell_size) + 1)
	var n: int = _cols * _rows
	_rest.resize(n)
	_off.resize(n)
	_vel.resize(n)
	_pts.resize(n)
	_lift.resize(n)
	_colors.resize(n)
	for c in _cols:
		for r in _rows:
			_rest[_idx(c, r)] = Vector2(
				rect.position.x + rect.size.x * float(c) / float(_cols - 1),
				rect.position.y + rect.size.y * float(r) / float(_rows - 1))
	# Os triângulos do tecido não mudam: dois por quadradinho
	for c in _cols - 1:
		for r in _rows - 1:
			var a: int = _idx(c, r)
			var b: int = _idx(c + 1, r)
			var d: int = _idx(c + 1, r + 1)
			var e: int = _idx(c, r + 1)
			_indices.append_array(PackedInt32Array([a, b, d, a, d, e]))
	_mesh = ArrayMesh.new()
	queue_redraw()


func _idx(c: int, r: int) -> int:
	return c * _rows + r


func _front_col() -> int:
	return 0 if front_is_min_x else _cols - 1


## Linha de fundo e laterais ficam presas às traves
func _is_fixed(c: int, r: int) -> bool:
	return c == _front_col() or r == 0 or r == _rows - 1


# ---------- API ----------

## Impacto: a bola bateu/entrou na rede em global_pos com essa velocidade.
## strength ~1 = chute normal; 2 = chute muito forte.
func hit(global_pos: Vector2, velocity: Vector2, strength: float = 1.0) -> void:
	var p: Vector2 = to_local(global_pos)
	var dir: Vector2 = velocity.normalized() if velocity.length() > 1.0 else Vector2.ZERO
	var s: float = strength * bulge

	# Chutes fortes esticam MUITO mais: o exagero cresce com o quadrado da força
	var over: float = maxf(s - 0.6, 0.0)
	var s_eff: float = s * (1.0 + stretch_power * over * over)

	var radius: float = lerpf(60.0, 190.0, clampf(s / 2.0, 0.0, 1.0))
	for c in _cols:
		for r in _rows:
			if _is_fixed(c, r):
				continue
			var i: int = _idx(c, r)
			var d: float = _rest[i].distance_to(p)
			var f: float = exp(-(d * d) / (radius * radius))
			if f < 0.02:
				continue
			if dir == Vector2.ZERO:
				# Sem direção (uma cutucada): empurra para fora do ponto
				_vel[i] += (_rest[i] - p).normalized() * f * s * 140.0
			else:
				_vel[i] += dir * f * s_eff * 300.0
				# Bolsão: os pontos dos lados são puxados para o caminho da bola
				var to_p: Vector2 = p - _rest[i]
				var lateral: Vector2 = to_p - dir * to_p.dot(dir)
				_vel[i] += lateral * f * s_eff * pinch * 0.5

	# Chute forte = rede mais elástica (amortece menos por um tempo) + clarão no impacto
	if s > 1.0:
		var m: float = clampf(1.0 / (1.0 + (s - 1.0) * wobble * 1.5), 0.3, 1.0)
		_damp_mult = minf(_damp_mult, m)
		_flashes.append({"pos": p, "age": 0.0, "size": 20.0 + 30.0 * s})
	_wake()


## Bola em movimento dentro da rede: arrasta os pontos perto dela (chame todo frame)
func drag(global_pos: Vector2, velocity: Vector2, delta: float) -> void:
	var p: Vector2 = to_local(global_pos)
	for c in _cols:
		for r in _rows:
			if _is_fixed(c, r):
				continue
			var i: int = _idx(c, r)
			var d: float = _rest[i].distance_to(p)
			var f: float = exp(-(d * d) / (45.0 * 45.0))
			if f < 0.02:
				continue
			_vel[i] += velocity * f * drag_gain * bulge * delta
	_wake()


## Vibração leve (bola bateu na trave/travessão, onde a rede está presa)
func shake(global_pos: Vector2, amount: float = 1.0) -> void:
	var p: Vector2 = to_local(global_pos)
	for c in _cols:
		for r in _rows:
			if _is_fixed(c, r):
				continue
			var i: int = _idx(c, r)
			var d: float = _rest[i].distance_to(p)
			var f: float = exp(-(d * d) / (150.0 * 150.0))
			if f < 0.02:
				continue
			_vel[i] += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 110.0 * f * amount
	_wake()


## Para a rede na hora (ex: partida recomeçando)
func settle() -> void:
	for i in _off.size():
		_off[i] = Vector2.ZERO
		_vel[i] = Vector2.ZERO
	_flashes.clear()
	_damp_mult = 1.0
	_awake = false
	queue_redraw()


func _wake() -> void:
	_awake = true


# ---------- SIMULAÇÃO ----------

func _process(delta: float) -> void:
	_flutter_t += delta
	# Parada, só a brisa mexe: redesenha poucas vezes por segundo (a física está dormindo)
	if idle_flutter and not _awake:
		_idle_acc += delta
		if _idle_acc >= 0.05:
			_idle_acc = 0.0
			queue_redraw()


func _physics_process(delta: float) -> void:
	if not _awake:
		return
	var dt_total: float = minf(delta, 1.0 / 30.0)

	# O amortecimento baixo dos chutes fortes volta ao normal em ~2 segundos
	_damp_mult = move_toward(_damp_mult, 1.0, dt_total * 0.35)
	var damp: float = damping * _damp_mult

	var steps: int = maxi(substeps, 1)
	for s in steps:
		_step(dt_total / float(steps), damp)

	# Energia que sobrou (para saber quando dormir)
	var energy: float = 0.0
	for i in _off.size():
		energy = maxf(energy, _off[i].length() + _vel[i].length() * 0.1)

	# Clarões do impacto envelhecem
	var k: int = _flashes.size() - 1
	while k >= 0:
		_flashes[k]["age"] = float(_flashes[k]["age"]) + dt_total
		if float(_flashes[k]["age"]) > 0.35:
			_flashes.remove_at(k)
		k -= 1

	if energy < 0.15 and _flashes.is_empty():
		settle()   # parou: dorme até o próximo impacto
	else:
		queue_redraw()


## Um passo da simulação: mola até o repouso + amortecimento + puxão dos vizinhos (a onda)
func _step(dt: float, damp: float) -> void:
	for c in _cols:
		for r in _rows:
			if _is_fixed(c, r):
				continue
			var i: int = _idx(c, r)
			var acc: Vector2 = -stiffness * _off[i] - damp * _vel[i]
			var n_sum: Vector2 = Vector2.ZERO
			var n_cnt: int = 0
			if c > 0:
				n_sum += _off[_idx(c - 1, r)]
				n_cnt += 1
			if c < _cols - 1:
				n_sum += _off[_idx(c + 1, r)]
				n_cnt += 1
			if r > 0:
				n_sum += _off[_idx(c, r - 1)]
				n_cnt += 1
			if r < _rows - 1:
				n_sum += _off[_idx(c, r + 1)]
				n_cnt += 1
			acc += coupling * (n_sum - _off[i] * float(n_cnt))
			_vel[i] += acc * dt
	for i in _off.size():
		_off[i] = (_off[i] + _vel[i] * dt).limit_length(max_offset)


# ---------- DESENHO ----------

## Deslocamento de um ponto (zero fora da malha: o tecido preso não se mexe)
func _off_at(c: int, r: int) -> Vector2:
	if c < 0 or c >= _cols or r < 0 or r >= _rows:
		return Vector2.ZERO
	return _off[_idx(c, r)]


func _lift_at(c: int, r: int) -> float:
	if c < 0 or c >= _cols or r < 0 or r >= _rows:
		return 0.0
	return _lift[_idx(c, r)]


func _stretch(c: int, r: int) -> float:
	return clampf(_off[_idx(c, r)].length() / strain_range, 0.0, 1.0)


## Posição de cada ponto na tela e a altura em que ele "sobe" (mais a brisa parada)
func _compute_positions() -> void:
	for c in _cols:
		for r in _rows:
			var i: int = _idx(c, r)
			var o: Vector2 = _off[i]
			var lift: float = minf(o.length() * puff, max_puff)
			var p: Vector2 = _rest[i] + o + Vector2(0.0, -lift)
			if idle_flutter and not _is_fixed(c, r):
				# A brisa mexe mais na borda de trás e some perto das traves
				var wx: float = float(absi(c - _front_col())) / float(maxi(_cols - 1, 1))
				var wy: float = sin(PI * float(r) / float(_rows - 1))
				var gust: float = 0.5 + 0.5 * sin(_flutter_t * flutter_speed + float(c) * 0.7 + float(r) * 0.28)
				var sway: float = sin(_flutter_t * flutter_speed * 0.8 + float(r) * 0.35)
				p += Vector2(sway * 0.6, -gust) * flutter_amount * wx * wy
				lift += gust * flutter_amount * wx * wy
			_lift[i] = lift
			_pts[i] = p


## Cor de cada ponto do tecido: translúcido, mais opaco quando esticado, com luz nas cristas das
## ondas e sombra azulada nos vales
func _compute_colors() -> void:
	for c in _cols:
		for r in _rows:
			var i: int = _idx(c, r)
			# Inclinação do tecido (luz vinda de cima/esquerda): quem sobe mais que o vizinho de baixo brilha
			var gy: float = _lift_at(c, r - 1) - _lift_at(c, r + 1)
			var gx: float = _lift_at(c - 1, r) - _lift_at(c + 1, r)
			var shade: float = clampf((gy + gx * 0.5) / 36.0, -1.0, 1.0)
			# Curvatura: as cristas e os vales das ondas
			var lap: Vector2 = _off_at(c - 1, r) + _off_at(c + 1, r) + _off_at(c, r - 1) + _off_at(c, r + 1) - _off[i] * 4.0
			var curv: float = clampf(lap.length() / 40.0, 0.0, 1.0)
			var tension: float = _stretch(c, r)

			var col: Color = Color(veil_color.r, veil_color.g, veil_color.b)
			if shade > 0.0:
				col = col.lerp(Color.WHITE, shade * 0.8)
			else:
				col = col.lerp(shadow_color, -shade * 0.75)
			col = col.lerp(glint_color, curv * 0.6)
			var alpha: float = veil_color.a + tension * 0.30 + absf(shade) * 0.22 + curv * 0.22
			_colors[i] = Color(col, clampf(alpha, 0.0, 0.85))


func _draw() -> void:
	if _pts.size() != _off.size() or _mesh == null:
		return
	_compute_positions()
	_compute_colors()

	# O tecido: uma malha de triângulos com cor em cada ponto (suave, sem emendas)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pts
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh(_mesh, null)

	# Fios da malha (finos) e, nos trechos muito tensos, uma segunda passada mais grossa por cima
	var pts: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var hot_pts: PackedVector2Array = PackedVector2Array()
	var hot_cols: PackedColorArray = PackedColorArray()
	for c in _cols:
		for r in _rows:
			var a: Vector2 = _pts[_idx(c, r)]
			var sa: float = _stretch(c, r)
			if c < _cols - 1:
				var b: Vector2 = _pts[_idx(c + 1, r)]
				var avg: float = (sa + _stretch(c + 1, r)) * 0.5
				pts.append(a)
				pts.append(b)
				cols.append(line_color.lerp(stretched_color, avg))
				if avg > 0.35:
					hot_pts.append(a)
					hot_pts.append(b)
					hot_cols.append(Color(stretched_color, avg))
			if r < _rows - 1:
				var b2: Vector2 = _pts[_idx(c, r + 1)]
				var avg2: float = (sa + _stretch(c, r + 1)) * 0.5
				pts.append(a)
				pts.append(b2)
				cols.append(line_color.lerp(stretched_color, avg2))
				if avg2 > 0.35:
					hot_pts.append(a)
					hot_pts.append(b2)
					hot_cols.append(Color(stretched_color, avg2))
			# Os nós mais esticados "acendem"
			if sa > 0.3 and not _is_fixed(c, r):
				draw_circle(a, 1.2 + 2.2 * sa, Color(stretched_color, 0.9 * sa))
	draw_multiline_colors(pts, cols, 1.0)
	if hot_pts.size() > 0:
		draw_multiline_colors(hot_pts, hot_cols, 2.2)

	# Barrado do véu: a borda de trás (a que mais voa) fica mais clara
	var hem := PackedVector2Array()
	var back: int = _cols - 1 - _front_col()
	for r in _rows:
		hem.append(_pts[_idx(back, r)])
	draw_polyline(hem, hem_color, 2.0, true)

	draw_rect(rect, frame_color, false, 2.0)

	# Clarão no ponto do impacto dos chutes fortes
	for fl: Dictionary in _flashes:
		var fk: float = float(fl["age"]) / 0.35
		var center: Vector2 = fl["pos"]
		draw_arc(center, 8.0 + float(fl["size"]) * fk * 2.0, 0.0, TAU, 24,
			Color(1.0, 1.0, 1.0, (1.0 - fk) * 0.8), 2.5 * (1.0 - fk) + 0.5)
