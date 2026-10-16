class_name DestroyerAura
extends Node2D
## Aura COMPACTA do Destroyer Mode do Rin: um pouco da sombra de olhos e dos espinhos do Cruel
## (Self Destruction), mas pequena e fixa nas costas dele, só para dar para ver quando o modo está
## ativo. Tudo é desenhado por código (sem imagem). Este arquivo NÃO depende do cruel_fx.gd.
##
##  - uma aura redonda em volta do corpo do Rin: brilho suave, mancha de sombra de borda
##    azul-esverdeada e um anel tracejado girando;
##  - 6 olhinhos que brilham e piscam, espalhados em volta dele;
##  - 5 espinhos pretos de contorno brilhante, SÓ nas costas (o semicírculo de trás).
## "Costas" = o lado oposto ao que o Rin olha: o nó espelha sozinho quando ele vira.
##
## O Rin cria este nó como filho dele (veja _ready no rin.gd) e liga/desliga com set_active().
## Aparece e some crescendo/encolhendo (0.35 s). Some também enquanto o Rin está derrubado.
##
## Medidas em "unit" (o raio do corpo do Rin, 18 px por padrão). Se o sprite for maior ou menor,
## use destroyer_fx_scale e destroyer_fx_offset no Inspector do Rin.

const BLACK := Color(0.015, 0.02, 0.03)
const TEAL := Color(0.15, 0.95, 0.8)
const TEAL_LIGHT := Color(0.75, 1.0, 0.95)
const TEAL_DEEP := Color(0.05, 0.55, 0.5)

const BLOB_N: int = 28
## Centro e tamanho da aura em volta do corpo (em unit, relativos aos pés do Rin)
const CENTER := Vector2(0.0, -2.0)
const RADIUS: float = 2.3
const REDRAW_EVERY: float = 0.1   # parado, redesenha ~10x por segundo (os olhos piscam)

## Tamanho de referência em pixels (o Rin passa o placeholder_radius dele)
var unit: float = 18.0
var fx_scale: float = 1.0
var fx_offset: Vector2 = Vector2.ZERO

var _active: bool = false
var _grow: float = 0.0            # 0 = escondida, 1 = completa
var _t: float = 0.0
var _redraw_acc: float = 0.0
var _noise: Array = []            # irregularidade da borda da mancha
var _spikes: Array = []           # {ang, len, w}: ângulo em radianos (y para baixo), comprimento e largura (em unit)
var _eyes: Array = []             # {pos, hw, tilt, blink, off}: posição e tamanho em unit


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in BLOB_N:
		_noise.append(rng.randf_range(0.88, 1.1))
	# Espinhos só nas costas: um leque no semicírculo de trás (o lado de trás é o -x; y cresce para baixo)
	var angles: Array[float] = [-205.0, -178.0, -150.0, -122.0, -98.0]
	var lengths: Array[float] = [1.2, 1.55, 1.9, 1.7, 1.25]
	for i in angles.size():
		_spikes.append({
			"ang": deg_to_rad(angles[i] + rng.randf_range(-6.0, 6.0)),
			"len": lengths[i] * rng.randf_range(0.9, 1.1),
			"w": rng.randf_range(0.26, 0.34),
		})
	# Olhinhos espalhados em volta do corpo, perto da borda da aura (ângulos em graus)
	var eye_angles: Array[float] = [-120.0, -70.0, -15.0, 40.0, 150.0, 200.0]
	for ea in eye_angles:
		var ring: float = rng.randf_range(1.5, 1.85)
		_eyes.append({
			"pos": CENTER + Vector2.from_angle(deg_to_rad(ea + rng.randf_range(-8.0, 8.0))) * ring,
			"hw": rng.randf_range(0.26, 0.38),
			"tilt": rng.randf_range(-0.45, 0.45),
			"blink": rng.randf_range(2.0, 4.5),
			"off": rng.randf_range(0.0, 4.0),
		})
	modulate.a = 0.0
	visible = false


## Liga ou desliga a aura (o Rin chama quando o Destroyer Mode começa ou acaba)
func set_active(on: bool) -> void:
	_active = on


func _process(delta: float) -> void:
	var rin := get_parent() as Player
	if rin == null:
		return
	# Só aparece no Rin de verdade (a cópia "fantasma" do Copy do Reo fica fora do grupo "players")
	var want: bool = _active and not rin.is_down and rin.is_in_group("players")
	var target: float = 1.0 if want else 0.0
	_grow = move_toward(_grow, target, delta / 0.35)
	visible = _grow > 0.01
	if not visible:
		return
	_t += delta
	modulate.a = clampf(_grow * 1.5, 0.0, 1.0)
	# Acompanha o corpo (a altura do pulo) e espelha quando o Rin vira
	position = Vector2(0.0, -rin.height) + fx_offset
	scale = Vector2(rin.facing * fx_scale, fx_scale)
	_redraw_acc += delta
	if _grow < 1.0 or _redraw_acc >= REDRAW_EVERY:
		_redraw_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var u: float = unit
	var e: float = 1.0 - pow(1.0 - clampf(_grow, 0.0, 1.0), 3.0)   # nasce rápido e assenta
	var center: Vector2 = CENTER * u
	var r: float = RADIUS * u * (0.6 + 0.4 * e)

	# 1) Brilho suave em volta (círculos que vão apagando para fora)
	for k in 3:
		draw_circle(center, r * (1.35 - 0.17 * float(k)), Color(TEAL_DEEP, 0.07 + 0.03 * float(k)))

	# 2) Espinhos SÓ nas costas (saem de dentro da mancha: a base fica escondida por ela)
	for sp in _spikes:
		var dir := Vector2.from_angle(float(sp["ang"]))
		var base: Vector2 = center + dir * r * 0.88
		_draw_spike(base, dir, float(sp["len"]) * u * e, float(sp["w"]) * u)

	# 3) Mancha de sombra redonda, de borda levemente irregular
	var blob := PackedVector2Array()
	for i in BLOB_N:
		var ang: float = TAU * float(i) / float(BLOB_N)
		blob.append(center + Vector2(cos(ang), sin(ang)) * r * float(_noise[i]))
	_poly(blob, Color(BLACK, 0.55), Color(TEAL, 0.6), 1.5)

	# 4) Anel tracejado girando em volta (a parte que dá cara de aura)
	for k in 6:
		var a0: float = _t * 0.9 + TAU * float(k) / 6.0
		draw_arc(center, r * 1.12, a0, a0 + 0.6, 8, Color(TEAL, 0.55), 1.6)

	# 5) Olhinhos (só abrem quando a aura já cresceu um pouco)

	var open_base: float = clampf((e - 0.45) / 0.4, 0.0, 1.0)
	if open_base <= 0.0:
		return
	var idx: int = 0
	for ey in _eyes:
		var blink: float = 1.0
		var ph: float = fposmod(_t + float(ey["off"]), float(ey["blink"]))
		if ph < 0.2:
			blink = clampf(absf(ph / 0.1 - 1.0), 0.1, 1.0)   # piscar rápido de vez em quando
		var pulse: float = 0.9 + 0.1 * sin(_t * 5.0 + float(idx))
		var hw: float = float(ey["hw"]) * u
		_draw_eye(Vector2(ey["pos"]) * u, hw, hw * 0.5, float(ey["tilt"]), pulse, open_base * blink)
		idx += 1


## Espinho de 9 pontos (o mesmo desenho dos espinhos do Cruel), preto com contorno brilhante
func _draw_spike(base: Vector2, dir: Vector2, h: float, w: float) -> void:
	if h < 1.0:
		return
	var perp: Vector2 = dir.orthogonal()
	var pts := PackedVector2Array([
		base - perp * w,
		base + dir * h * 0.30 - perp * w * 0.95,
		base + dir * h * 0.55 - perp * w * 0.40,
		base + dir * h * 0.62 - perp * w * 0.65,
		base + dir * h,
		base + dir * h * 0.58 + perp * w * 0.55,
		base + dir * h * 0.40 + perp * w * 0.35,
		base + dir * h * 0.22 + perp * w * 0.90,
		base + perp * w,
	])
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(TEAL, 0.22), 4.0)           # brilho por trás
	draw_colored_polygon(pts, Color(BLACK, 0.95))
	draw_polyline(closed, Color(TEAL, 0.95), 1.6)
	draw_line(base, base + dir * h * 0.85, Color(TEAL, 0.45), 1.0)   # reflexo no meio


## Olho em forma de amêndoa, brilhando, com uma fenda no meio. open = 1 aberto, ~0.1 fechado.
func _draw_eye(pos: Vector2, hw: float, hh: float, tilt: float, pulse: float, open: float) -> void:
	var h2: float = maxf(hh * open, 0.6)
	draw_circle(pos, hw * 1.7 * pulse, Color(TEAL_DEEP, 0.2))
	_poly(_lens(pos, hw, h2, tilt), Color(TEAL_LIGHT, 0.95), Color(TEAL, 1.0), 1.0)
	draw_colored_polygon(_lens(pos, hw * 0.55, h2 * 0.55, tilt), Color(1.0, 1.0, 1.0, 0.9))
	if open > 0.4:
		draw_line(pos + Vector2(0.0, -h2 * 0.8), pos + Vector2(0.0, h2 * 0.8), Color(BLACK, 1.0), 1.4)


## Contorno de uma amêndoa (lente), inclinada por "tilt"
func _lens(center: Vector2, half_w: float, half_h: float, tilt: float, steps: int = 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t: float = -1.0 + 2.0 * float(i) / float(steps)
		pts.append(center + Vector2(t * half_w, -(1.0 - t * t) * half_h).rotated(tilt))
	for i in range(steps - 1, 0, -1):
		var t: float = -1.0 + 2.0 * float(i) / float(steps)
		pts.append(center + Vector2(t * half_w, (1.0 - t * t) * half_h).rotated(tilt))
	return pts


## Polígono preenchido com contorno (só para formas simples)
func _poly(pts: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	if pts.size() < 3:
		return
	draw_colored_polygon(pts, fill)
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, edge, width)
