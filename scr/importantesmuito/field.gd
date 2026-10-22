class_name Field
extends Node2D
## Campo de futebol 2.5D: linhas, gols (traves + travessão + rede) e limites.
##
## - Origem (0, 0) = centro do campo.
## - Time 0 defende o gol da ESQUERDA e ataca para a DIREITA (time 1, o contrário) — até a troca de
##   lado do 2º tempo. Depois dela é o contrário: use defend_dir(time) em vez de supor o lado.
## - Traves e travessão são desenhados "em pé" (subindo na tela), igual à bola,
##   e ordenados por profundidade junto com jogadores e bola.
## - Não rotacione nem escale este nó (a conversão usa to_local/to_global).
##
## Visual vivo (tudo opcional, veja os grupos de exports):
## - Grama ao vento: uma malha de folhinhas que balança por shader (GPU), sem custo no processador.
## - Banco de cada time fora do campo (linha lateral de baixo) com os RESERVES sentados; comemoram gol.
## - Bandeirinhas de escanteio ao vento e poeirinha levada pela brisa.
## - F3 = MODO FOTO: esconde a interface; roda do mouse = zoom, botão do meio (ou setas) = mover a
##   câmera, R = centralizar. F3 de novo volta tudo como estava.
##
## Estrutura da cena:
## Field (Node2D)  <- este script (arraste a Ball em "Ball")

signal goal_scored(team: int)
signal ball_out(local_position: Vector2)
## A bola voltou ao centro depois de um gol (o MatchManager aproveita para reposicionar os times)
signal ball_reset_after_goal

@export var ball: Ball

@export_group("Campo")
@export var pitch_size: Vector2 = Vector2(2400, 1350)
@export var margin: float = 500.0                      # grama além das linhas
## Medidas na proporção do futebol real (campo de 105 x 68 m): grande área 16,5 x 40,3 m, pequena
## área 5,5 x 18,3 m, marca do pênalti a 11 m e círculo central de 9,15 m de raio
@export var center_circle_radius: float = 110.0
@export var penalty_area_size: Vector2 = Vector2(220, 480)  # profundidade x largura
@export var goal_area_size: Vector2 = Vector2(80, 220)
@export var penalty_spot_distance: float = 150.0
@export var penalty_arc_radius: float = 110.0         # a "meia-lua" da grande área (9,15 m)
@export var line_width: float = 3.0

@export_group("Gol")
@export var goal_width: float = 260.0                  # boca do gol (era 220)
@export var goal_depth: float = 90.0                   # profundidade da rede (era 70)
@export var crossbar_height: float = 80.0              # altura (Z) do travessão: Suspenso (50) passa por baixo, Voando (100) passa por cima
@export var post_radius: float = 6.0
@export var crossbar_thickness: float = 6.0
@export var ball_hit_radius: float = 8.0               # "tamanho" da bola para bater na trave
@export var post_bounce: float = 0.6
@export var reset_delay: float = 2.0                   # tempo até a bola voltar ao centro após o gol

@export_group("Goleiros")
@export var spawn_goalkeepers: bool = true             # cria um goleiro por time (se a cena não tiver)

@export_group("Rede")
@export var animate_nets: bool = true                  # rede deformável (false = rede estática antiga)
@export var net_cell_size: float = 10.0                # tamanho de cada quadradinho da malha (menor = tecido mais liso)
@export var net_stiffness: float = 45.0                # quanto a rede volta ao repouso (baixo = flutua mais, estilo véu)
@export var net_damping: float = 2.4                   # quanto ela demora para parar de balançar
@export var net_coupling: float = 240.0                # velocidade das ondas que correm pela rede
@export var net_bulge: float = 1.25                    # multiplicador de quanto ela estufa
@export var net_idle_flutter: bool = true              # a rede respira com uma brisa leve mesmo parada

@export_group("Cores")
@export var grass_dark: Color = Color("2e7d32")
@export var grass_light: Color = Color("388e3c")
@export var line_color: Color = Color(1, 1, 1, 0.9)
@export var post_color: Color = Color(0.97, 0.97, 0.97)

@export_group("Vento e grama")
@export var animate_grass: bool = true                 # grama balançando com a brisa (feito na placa de vídeo, quase sem custo)
@export_range(0.1, 2.0) var blade_density: float = 1.0 # 1 = padrão; baixe (0.5) em computador fraco
@export var blade_height: Vector2 = Vector2(9.0, 16.0) # altura mínima e máxima de cada folha
@export var wind_strength: float = 3.2                 # quanto a ponta da grama balança (px)
@export var wind_speed: float = 1.1                    # velocidade das rajadas
@export var wind_direction: Vector2 = Vector2(1.0, 0.25)
@export var wind_particles: bool = true                # poeirinha/pólen levado pelo vento
@export var corner_flags: bool = true                  # bandeirinhas de escanteio ao vento

@export_group("Banco de reservas")
@export var show_benches: bool = true                  # banco de cada time, fora do campo, com os reservas
@export var bench_x_offset: float = 330.0              # distância do meio-campo (um banco para cada lado)
@export var bench_distance: float = 90.0               # distância da linha lateral de baixo
@export var bench_width: float = 250.0

@export_group("Modo foto (F3)")
@export var photo_mode_key: Key = KEY_F3
@export var photo_modal_layer: int = 100                # telas acima desta camada (formação, pausa) bloqueiam o modo foto
@export var photo_zoom_range: Vector2 = Vector2(0.5, 3.0)   # limites do zoom, em vezes o zoom que a câmera já tinha

var _prev_pos: Vector2 = Vector2.INF
var _scored_side: int = 0  # 0 = nenhum gol em andamento, 1 = gol da direita, -1 = gol da esquerda
var _nets: Dictionary = {}  # lado (1 = direita, -1 = esquerda) -> GoalNet

## Troca de lado do 2º tempo: false = o time 0 defende o gol da ESQUERDA (padrão); true = o da DIREITA.
## Quem muda isto é o MatchManager.
var sides_swapped: bool = false

## --- Visual vivo ---
const GRASS_SHADER: String = """
shader_type canvas_item;

uniform float wind_strength = 3.2;
uniform float wind_speed = 1.1;
uniform vec2 wind_dir = vec2(1.0, 0.25);
uniform float gust_scale = 0.0035;
uniform float gust_light = 0.07;

void vertex() {
    // O Field marca a ponta de cada folha com alfa < 1 (base = 1): só a ponta balança
    float w = clamp((1.0 - COLOR.a) * 2.0, 0.0, 1.0);
    COLOR.a = 1.0;
    vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    vec2 d = normalize(wind_dir);
    // Rajadas que atravessam o campo: uma onda principal e outra menor por cima
    float phase = dot(wp, d) * gust_scale - TIME * wind_speed;
    float gust = sin(phase) + 0.45 * sin(phase * 2.1 + wp.y * 0.011 + TIME * 0.7);
    // A grama fica sempre um pouco inclinada a favor do vento e vai e volta com a rajada
    float push = 0.55 + 0.45 * gust;
    VERTEX.x += d.x * push * wind_strength * w;
    VERTEX.y += d.y * push * wind_strength * w * 0.35;
    // Quando a rajada passa, a ponta clareia um pouco (lado de baixo da folha aparecendo)
    COLOR.rgb *= 1.0 + gust_light * gust * w;
}
"""

var _grass_mat: ShaderMaterial
var _flag_drawers: Array[Node2D] = []
var _bench_drawers: Array[Node2D] = [null, null]
var _bench_ids: Array = [[], []]                  # time -> ids dos reservas (atualizado a cada tick)
var _bench_colors: Array[Color] = [Color(0.4, 0.4, 0.45), Color(0.4, 0.4, 0.45)]
var _cheer: Array[float] = [0.0, 0.0]             # comemoração do banco (1 -> 0)
var _bench_timer: float = 0.0
var _manager: MatchManager

## Modo foto (F3)
var _photo_mode: bool = false
var _photo_hidden: Array = []                    # CanvasLayers e Controls escondidos (voltam ao sair)
var _photo_toast: CanvasLayer
var _photo_label: Label
var _photo_cam: Camera2D
var _photo_zoom_start: Vector2 = Vector2.ONE
var _photo_offset_start: Vector2 = Vector2.ZERO
var _photo_zoom_target: float = 1.0
var _photo_offset_target: Vector2 = Vector2.ZERO
var _photo_check: float = 0.0
var _photo_tween: Tween


## Nó auxiliar que desenha uma peça (trave) com profundidade própria
class _Drawer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


func _ready() -> void:
	add_to_group("field")  # o MatchManager e os goleiros encontram o campo por aqui
	_spawn_goalkeepers.call_deferred()
	z_index = -4096  # o chão fica atrás de tudo
	# Ordem das camadas (mesma profundidade, desenha na ordem em que nasceram):
	# grama do campo (este nó) < folhas ao vento < linhas < rede
	_build_grass()
	_build_lines_layer()
	for side in [-1, 1]:
		var dir: int = side
		var gx: float = pitch_size.x * 0.5 * dir
		_add_drawer(Vector2(gx, -goal_width * 0.5), _draw_post.bind(true))   # trave de trás (com travessão)
		_add_drawer(Vector2(gx, goal_width * 0.5), _draw_post.bind(false))   # trave da frente
	_build_nets()
	_build_benches()
	_build_flags()
	_build_wind_particles()
	goal_scored.connect(_on_goal_cheer)


## Cria um goleiro para cada time que ainda não tem um (você pode colocar os seus na cena).
## O estilo vem do KeeperRoster (escolhido na tela de formação; padrão = goleiro comum).
func _spawn_goalkeepers() -> void:
	if not spawn_goalkeepers or ball == null:
		return
	var has_keeper := {}
	for k: Goalkeeper in get_tree().get_nodes_in_group("goalkeepers"):
		has_keeper[k.team] = true
	for t in 2:
		if has_keeper.has(t):
			continue
		var keeper: Goalkeeper = KeeperRoster.create(KeeperRoster.choice_for(t))
		keeper.team = t
		ball.get_parent().add_child(keeper)  # mesma camada de profundidade da bola e dos jogadores


## Uma rede deformável por gol (fica acima da grama e atrás de jogadores e bola)
func _build_nets() -> void:
	if not animate_nets:
		return
	var half_x: float = pitch_size.x * 0.5
	for side in [-1, 1]:
		var dir: int = side
		var gx: float = half_x * dir
		var net := GoalNet.new()
		net.rect = Rect2(gx if dir > 0 else gx - goal_depth, -goal_width * 0.5, goal_depth, goal_width)
		net.front_is_min_x = dir > 0
		net.cell_size = net_cell_size
		net.stiffness = net_stiffness
		net.damping = net_damping
		net.coupling = net_coupling
		net.bulge = net_bulge
		net.idle_flutter = net_idle_flutter
		add_child(net)
		net.z_index = 1   # relativo ao campo (-4096): acima da grama, abaixo de todo o resto
		_nets[dir] = net


func _net_hit(side: int, global_pos: Vector2, velocity: Vector2, strength: float) -> void:
	var net := _nets.get(side) as GoalNet
	if net:
		net.hit(global_pos, velocity, strength)


func _net_shake(side: int, global_pos: Vector2, amount: float) -> void:
	var net := _nets.get(side) as GoalNet
	if net:
		net.shake(global_pos, amount)


## Para outros scripts (ex: o goleiro mergulhando na rede): mexe na rede do gol mais perto
func poke_net(global_pos: Vector2, velocity: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	var side: int = 1 if to_local(global_pos).x >= 0.0 else -1
	_net_hit(side, global_pos, velocity, strength)


func _add_drawer(local_pos: Vector2, fn: Callable) -> void:
	var d := _Drawer.new()
	d.position = local_pos
	d.fn = fn
	d.z_as_relative = false
	add_child(d)
	d.z_index = int(d.global_position.y)  # mesma regra de profundidade da bola e dos jogadores


# ---------- FÍSICA: LIMITES, TRAVES E GOL ----------

func _physics_process(_delta: float) -> void:
	if ball == null:
		return

	var p: Vector2 = to_local(ball.global_position)
	if _prev_pos == Vector2.INF:
		_prev_pos = p

	if _scored_side != 0:
		p = _contain_in_net(p)
	else:
		p = _check_goals(p)
		if _scored_side == 0:
			p = _clamp_to_pitch(p)

	ball.global_position = to_global(p)
	_prev_pos = p


func _check_goals(p: Vector2) -> Vector2:
	var half: Vector2 = pitch_size * 0.5
	var post_y: float = goal_width * 0.5
	var r: float = post_radius + ball_hit_radius
	var top: float = crossbar_height + crossbar_thickness

	for side in [-1, 1]:
		var dir: int = side
		var gx: float = half.x * dir

		# A bola cruzou a linha de fundo (vindo de dentro do campo) neste frame?
		var was_inside: bool = (_prev_pos.x - gx) * dir < 0.0
		var is_outside: bool = (p.x - gx) * dir >= 0.0
		if not (was_inside and is_outside):
			continue

		# Onde (y) e a que altura (z) ela cruzou a linha
		var t: float = (gx - _prev_pos.x) / (p.x - _prev_pos.x)
		var cross_y: float = absf(lerpf(_prev_pos.y, p.y, t))
		var h: float = ball.height

		if cross_y < post_y - r:
			# Dentro da boca do gol
			if h < crossbar_height - crossbar_thickness:
				_register_goal(dir, p)
				return p
			elif h <= top:
				# Travessão: quica para baixo e volta
				ball.vel_z = -absf(ball.vel_z) * 0.5
				return _bounce_x(p, gx, dir)
			# Acima do travessão: segue para fora (tratado pelo limite do campo)
		elif cross_y <= post_y + r and h <= top:
			# Trave
			return _bounce_x(p, gx, dir)

	return p


func _bounce_x(p: Vector2, gx: float, dir: int) -> Vector2:
	var v: Vector2 = ball.velocity
	# A rede está presa na trave/travessão: a pancada faz ela tremer
	_net_shake(dir, to_global(Vector2(gx, p.y)), clampf(absf(v.x) / 800.0, 0.2, 1.5))
	v.x = -v.x * post_bounce
	ball.velocity = v
	var out: Vector2 = p
	out.x = gx - dir * 2.0  # devolve a bola para dentro do campo
	return out


func _register_goal(dir: int, entry: Vector2 = Vector2.ZERO) -> void:
	_scored_side = dir
	# A rede estufa conforme a força do chute (velocidade da bola ao entrar)
	_net_hit(dir, to_global(entry), ball.velocity, clampf(ball.velocity.length() / 700.0, 0.35, 2.0))
	var scoring_team: int = 0 if defend_dir(0) == -dir else 1  # quem ataca este gol (padrão: o time 0 ataca o da direita)
	goal_scored.emit(scoring_team)
	_reset_after_delay()


func _reset_after_delay() -> void:
	await get_tree().create_timer(reset_delay).timeout
	reset_ball()
	ball_reset_after_goal.emit()


## A bola fica presa dentro da rede depois do gol
func _contain_in_net(p: Vector2) -> Vector2:
	var half: Vector2 = pitch_size * 0.5
	var gx: float = half.x * _scored_side
	var inner_y: float = goal_width * 0.5 - post_radius - ball_hit_radius
	var x_min: float = gx if _scored_side > 0 else gx - goal_depth
	var x_max: float = gx + goal_depth if _scored_side > 0 else gx

	var out: Vector2 = p
	var v: Vector2 = ball.velocity
	var net := _nets.get(_scored_side) as GoalNet

	# A bola arrasta a rede enquanto anda lá dentro
	if net:
		net.drag(to_global(out), v, get_physics_process_delta_time())

	if out.x < x_min:
		out.x = x_min
		if net and absf(v.x) > 40.0:
			net.hit(to_global(out), Vector2(v.x, 0.0), clampf(absf(v.x) / 700.0, 0.2, 2.0))
		v.x = absf(v.x) * 0.2
	elif out.x > x_max:
		out.x = x_max
		if net and absf(v.x) > 40.0:
			net.hit(to_global(out), Vector2(v.x, 0.0), clampf(absf(v.x) / 700.0, 0.2, 2.0))
		v.x = -absf(v.x) * 0.2

	if absf(out.y) > inner_y:
		out.y = signf(out.y) * inner_y
		if net and absf(v.y) > 40.0:
			net.hit(to_global(out), Vector2(0.0, v.y), clampf(absf(v.y) / 700.0, 0.2, 2.0))
		v.y = -v.y * 0.2

	ball.velocity = v
	return out


## Por enquanto a bola quica nos limites (placeholder para lateral, escanteio e tiro de meta)
func _clamp_to_pitch(p: Vector2) -> Vector2:
	var half: Vector2 = pitch_size * 0.5
	var out: Vector2 = p
	var v: Vector2 = ball.velocity
	var went_out: bool = false

	if absf(out.x) > half.x:
		out.x = signf(out.x) * half.x
		v.x = -v.x * 0.5
		went_out = true
	if absf(out.y) > half.y:
		out.y = signf(out.y) * half.y
		v.y = -v.y * 0.5
		went_out = true

	if went_out:
		ball.velocity = v
		ball_out.emit(out)
	return out


# ---------- API ----------

## Coloca a bola parada em uma posição local do campo (padrão: centro)
func reset_ball(local_pos: Vector2 = Vector2.ZERO) -> void:
	_scored_side = 0
	_prev_pos = local_pos
	if ball:
		ball.reset(to_global(local_pos))


## Lado do gol que o time DEFENDE: -1 = gol da ESQUERDA, +1 = gol da DIREITA.
## (Padrão: time 0 na esquerda e time 1 na direita; troca depois da virada de lado do 2º tempo.)
func defend_dir(team: int) -> int:
	var d: int = -1 if team == 0 else 1
	return -d if sides_swapped else d


## Grande área que o time DEFENDE (em coordenadas locais do campo)
func get_penalty_area_rect(team: int) -> Rect2:
	var half: Vector2 = pitch_size * 0.5
	var dir: int = defend_dir(team)
	var gx: float = half.x * dir
	var x0: float = gx if dir < 0 else gx - penalty_area_size.x
	return Rect2(x0, -penalty_area_size.y * 0.5, penalty_area_size.x, penalty_area_size.y)


## Pequena área (área do gol) que o time DEFENDE (em coordenadas locais do campo)
func get_goal_area_rect(team: int) -> Rect2:
	var half: Vector2 = pitch_size * 0.5
	var dir: int = defend_dir(team)
	var gx: float = half.x * dir
	var x0: float = gx if dir < 0 else gx - goal_area_size.x
	return Rect2(x0, -goal_area_size.y * 0.5, goal_area_size.x, goal_area_size.y)


## Esta posição (global) está dentro da grande área defendida por esse time?
func is_in_penalty_area(global_pos: Vector2, team: int) -> bool:
	return get_penalty_area_rect(team).has_point(to_local(global_pos))


## Centro (global) do gol que o time ataca — útil para IA e chutes
func get_attack_goal_center(team: int) -> Vector2:
	var dir: float = -float(defend_dir(team))
	return to_global(Vector2(pitch_size.x * 0.5 * dir, 0.0))


## Centro (global) do gol que o time defende
func get_defend_goal_center(team: int) -> Vector2:
	var dir: float = float(defend_dir(team))
	return to_global(Vector2(pitch_size.x * 0.5 * dir, 0.0))


# ---------- DESENHO ----------

func _draw() -> void:
	var half: Vector2 = pitch_size * 0.5

	# Grama + listras (as folhas ao vento e as linhas ficam em nós filhos, por cima)
	var full := Rect2(-half - Vector2(margin, margin), pitch_size + Vector2(margin, margin) * 2.0)
	draw_rect(full, grass_dark)
	var stripes: int = 12
	var stripe_w: float = pitch_size.x / stripes
	for i in stripes:
		if i % 2 == 0:
			draw_rect(Rect2(-half.x + i * stripe_w, -half.y, stripe_w, pitch_size.y), grass_light)


## Linhas do campo (e a rede estática antiga) num nó filho, para ficarem por cima das folhas
func _build_lines_layer() -> void:
	var layer := _Drawer.new()
	layer.fn = _draw_pitch_lines
	add_child(layer)
	layer.z_index = 1   # relativo ao campo: acima da grama e das folhas


func _draw_pitch_lines(n: Node2D) -> void:
	var half: Vector2 = pitch_size * 0.5

	# Linhas gerais
	n.draw_rect(Rect2(-half, pitch_size), line_color, false, line_width)
	n.draw_line(Vector2(0, -half.y), Vector2(0, half.y), line_color, line_width)
	n.draw_arc(Vector2.ZERO, center_circle_radius, 0.0, TAU, 64, line_color, line_width)
	n.draw_circle(Vector2.ZERO, 4.0, line_color)

	for side in [-1, 1]:
		var dir: int = side
		var gx: float = half.x * dir

		# Grande área e pequena área
		var pa_x: float = gx if dir < 0 else gx - penalty_area_size.x
		n.draw_rect(Rect2(pa_x, -penalty_area_size.y * 0.5, penalty_area_size.x, penalty_area_size.y),
			line_color, false, line_width)
		var ga_x: float = gx if dir < 0 else gx - goal_area_size.x
		n.draw_rect(Rect2(ga_x, -goal_area_size.y * 0.5, goal_area_size.x, goal_area_size.y),
			line_color, false, line_width)

		# Marca do pênalti e a meia-lua: só o pedaço do arco que fica FORA da grande área
		var spot := Vector2(gx - dir * penalty_spot_distance, 0.0)
		n.draw_circle(spot, 4.0, line_color)
		var edge_gap: float = penalty_area_size.x - penalty_spot_distance   # do pênalti até a linha da área
		if penalty_arc_radius > edge_gap:
			var half_angle: float = acos(clampf(edge_gap / penalty_arc_radius, -1.0, 1.0))
			var center_angle: float = 0.0 if dir < 0 else PI   # o arco abre para o meio do campo
			n.draw_arc(spot, penalty_arc_radius, center_angle - half_angle, center_angle + half_angle, 32, line_color, line_width)

		# Rede estática antiga (a rede deformável é o GoalNet)
		if not animate_nets:
			_draw_static_net(n, gx, dir)


## Rede desenhada direto no campo (usada só quando animate_nets = false)
func _draw_static_net(n: Node2D, gx: float, dir: int) -> void:
	var net_x: float = gx if dir > 0 else gx - goal_depth
	var net := Rect2(net_x, -goal_width * 0.5, goal_depth, goal_width)
	n.draw_rect(net, Color(0, 0, 0, 0.35))
	var step: float = 12.0
	var x: float = net.position.x
	while x <= net.end.x:
		n.draw_line(Vector2(x, net.position.y), Vector2(x, net.end.y), Color(1, 1, 1, 0.25), 1.0)
		x += step
	var y: float = net.position.y
	while y <= net.end.y:
		n.draw_line(Vector2(net.position.x, y), Vector2(net.end.x, y), Color(1, 1, 1, 0.25), 1.0)
		y += step
	n.draw_rect(net, Color(1, 1, 1, 0.6), false, 2.0)


## Desenha uma trave "em pé"; a de trás também desenha o travessão
func _draw_post(n: Node2D, with_crossbar: bool) -> void:
	n.draw_circle(Vector2.ZERO, post_radius + 2.0, Color(0, 0, 0, 0.35))  # sombra na base
	n.draw_line(Vector2.ZERO, Vector2(0, -crossbar_height), post_color, post_radius * 2.0)
	if with_crossbar:
		n.draw_line(
			Vector2(0, -crossbar_height),
			Vector2(0, goal_width - crossbar_height),
			post_color, crossbar_thickness * 2.0
		)


# ---------- VISUAL VIVO: GRAMA AO VENTO ----------

## Cor da grama no ponto (as listras claras/escuras do campo; fora das linhas é sempre a escura)
func _grass_color_at(p: Vector2) -> Color:
	var half: Vector2 = pitch_size * 0.5
	if absf(p.x) <= half.x and absf(p.y) <= half.y:
		var i: int = int(floorf((p.x + half.x) / (pitch_size.x / 12.0)))
		return grass_light if i % 2 == 0 else grass_dark
	return grass_dark


## Monta UMA malha com milhares de folhinhas (triângulos) e põe um shader que balança só a ponta.
## O balanço roda inteiro na placa de vídeo: depois de montada, a grama não custa nada por quadro.
func _build_grass() -> void:
	if not animate_grass:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261016   # sempre a mesma grama (não "pula" a cada partida)
	var half: Vector2 = pitch_size * 0.5
	var area := Rect2(-half - Vector2(margin, margin), pitch_size + Vector2(margin, margin) * 2.0)
	var step: float = 46.0 / sqrt(maxf(blade_density, 0.05))

	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var y: float = area.position.y
	while y < area.end.y:
		var x: float = area.position.x
		while x < area.end.x:
			var tuft := Vector2(x + rng.randf() * step, y + rng.randf() * step)
			var ground: Color = _grass_color_at(tuft)
			for b in 3:
				var bp := tuft + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-6.0, 6.0))
				var h: float = rng.randf_range(blade_height.x, blade_height.y)
				var bw: float = rng.randf_range(1.6, 2.6)
				var lean: float = rng.randf_range(-2.5, 2.5)
				var c_base: Color = ground.darkened(rng.randf_range(0.10, 0.22))
				var c_tip: Color = ground.lightened(rng.randf_range(0.08, 0.22))
				c_tip.a = rng.randf_range(0.5, 0.7)   # alfa da PONTA = quanto ela balança (o shader devolve 1.0)
				verts.append(bp + Vector2(-bw, 0.0))
				cols.append(c_base)
				verts.append(bp + Vector2(bw, 0.0))
				cols.append(c_base)
				verts.append(bp + Vector2(lean, -h))
				cols.append(c_tip)
			x += step
		y += step

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var shader := Shader.new()
	shader.code = GRASS_SHADER
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = shader
	_grass_mat.set_shader_parameter("wind_strength", wind_strength)
	_grass_mat.set_shader_parameter("wind_speed", wind_speed)
	_grass_mat.set_shader_parameter("wind_dir", wind_direction)

	var blades := MeshInstance2D.new()
	blades.mesh = mesh
	blades.material = _grass_mat
	add_child(blades)   # z relativo 0: acima da grama do campo, abaixo das linhas


## Poeirinha/pólen clarinho flutuando a favor do vento (poucas partículas, bem leve)
func _build_wind_particles() -> void:
	if not wind_particles:
		return
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0   # já começa com o campo "cheio"
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = pitch_size * 0.5 + Vector2(margin, margin) * 0.5
	p.direction = wind_direction.normalized()
	p.spread = 14.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 0.9, 0.3), Color(1, 1, 0.9, 0.3), Color(1, 1, 1, 0.0)])
	p.color_ramp = ramp
	p.z_index = 2   # acima da grama, abaixo de jogadores e bola
	add_child(p)


# ---------- VISUAL VIVO: BANDEIRINHAS DE ESCANTEIO ----------

func _build_flags() -> void:
	if not corner_flags:
		return
	var half: Vector2 = pitch_size * 0.5
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var pos := Vector2(half.x * float(sx), half.y * float(sy))
			_add_drawer(pos, _draw_flag.bind(float(sx * 3 + sy)))
			_flag_drawers.append(get_child(get_child_count() - 1) as Node2D)


## Poste com uma bandeirinha que balança a favor do vento
func _draw_flag(n: Node2D, phase: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	var pole_h: float = 36.0
	n.draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.3))
	n.draw_line(Vector2.ZERO, Vector2(0, -pole_h), Color(0.95, 0.95, 0.95), 2.4)
	var wd: Vector2 = wind_direction.normalized()
	var flutter: float = sin(t * 3.2 + phase) * 2.6 + sin(t * 5.1 + phase * 1.7) * 1.2
	var top := Vector2(0, -pole_h)
	var mid := top + Vector2(wd.x * 11.0 + flutter * 0.5, 6.0 + flutter * 0.25)
	var tip := top + Vector2(wd.x * 20.0 + flutter, 11.0 + flutter * 0.4)
	var low := top + Vector2(0, 12.0)
	n.draw_colored_polygon(PackedVector2Array([top, mid, tip, low]), Color(1.0, 0.82, 0.2))
	n.draw_polyline(PackedVector2Array([top, mid, tip, low, top]), Color(0.45, 0.3, 0.05, 0.8), 1.0)


# ---------- VISUAL VIVO: BANCO DE RESERVAS ----------

## Um banco por time, fora do campo (linha lateral de baixo), um de cada lado do meio-campo.
## Time 0 à esquerda, time 1 à direita (o banco fica com o time mesmo depois da troca de lado).
func _build_benches() -> void:
	if not show_benches:
		return
	var half: Vector2 = pitch_size * 0.5
	for team in 2:
		var x: float = -bench_x_offset if team == 0 else bench_x_offset
		_add_drawer(Vector2(x, half.y + bench_distance), _draw_bench.bind(team))
		_bench_drawers[team] = get_child(get_child_count() - 1) as Node2D


## O MatchManager e os reservas escolhidos (lidos a cada tick, não a cada quadro)
func _update_bench_data() -> void:
	if _manager == null:
		_manager = get_tree().get_first_node_in_group("match_manager") as MatchManager
	for team in 2:
		_bench_colors[team] = TeamStyle.color_of(team)
		var ids: Array = []
		if _manager != null and _manager.bench != null:
			for slot in BenchManager.RESERVES:
				ids.append(_manager.bench.reserve_id(team, slot))
		_bench_ids[team] = ids


func _on_goal_cheer(scoring_team: int) -> void:
	if scoring_team >= 0 and scoring_team < 2:
		_cheer[scoring_team] = 1.0   # o banco do time que fez o gol pula de alegria


func _draw_bench(n: Node2D, team: int) -> void:
	var color: Color = _bench_colors[team]
	var w: float = bench_width * 0.5
	var t: float = Time.get_ticks_msec() * 0.001
	var cheer: float = _cheer[team]

	# Sombra no chão
	var shadow := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		shadow.append(Vector2(cos(a) * (w + 14.0), sin(a) * 9.0 + 4.0))
	n.draw_colored_polygon(shadow, Color(0, 0, 0, 0.30))

	# Parede do fundo (translúcida) e os dois postes
	n.draw_rect(Rect2(-w, -70.0, w * 2.0, 56.0), Color(0.04, 0.06, 0.09, 0.5))
	n.draw_line(Vector2(-w, 0.0), Vector2(-w, -88.0), Color(0.86, 0.88, 0.92), 4.0)
	n.draw_line(Vector2(w, 0.0), Vector2(w, -88.0), Color(0.86, 0.88, 0.92), 4.0)

	# Teto na cor do time
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(-w - 12.0, -88.0), Vector2(w + 12.0, -88.0),
		Vector2(w + 4.0, -74.0), Vector2(-w - 4.0, -74.0)]), color.darkened(0.12))
	n.draw_line(Vector2(-w - 12.0, -88.0), Vector2(w + 12.0, -88.0), color.lightened(0.35), 3.0)

	# Reservas sentados (corpo na cor do time + rosto redondo)
	var ids: Array = _bench_ids[team]
	var spacing: float = (bench_width - 50.0) / 2.0
	for slot in ids.size():
		var id: String = String(ids[slot])
		if id == "":
			continue
		var cx: float = -spacing + spacing * float(slot)
		var bob: float = sin(t * 1.8 + float(slot) * 2.1 + float(team)) * 1.0
		var jump: float = -absf(sin(t * 10.0 + float(slot) * 1.7)) * 14.0 * cheer
		var body_top: float = -50.0 + bob + jump
		n.draw_rect(Rect2(cx - 15.0, body_top, 30.0, 32.0), color)
		n.draw_rect(Rect2(cx - 15.0, body_top, 30.0, 6.0), color.lightened(0.25))
		var head := Vector2(cx, body_top - 10.0)
		n.draw_circle(head, 16.5, Color.WHITE)
		var tex: Texture2D = CharacterRoster.face_for(id)
		if tex != null:
			_draw_round_face(n, tex, head, 14.0)
		else:
			n.draw_circle(head, 14.0, color.darkened(0.45))
			var initial: String = String(CharacterRoster.find(id).get("name", id)).substr(0, 1).to_upper()
			n.draw_string(ThemeDB.fallback_font, head + Vector2(-14.0, 6.0), initial,
				HORIZONTAL_ALIGNMENT_CENTER, 28.0, 16, Color.WHITE)

	# Assento na frente das pernas: tábua clara com a frente na cor do time
	n.draw_rect(Rect2(-w + 6.0, -20.0, w * 2.0 - 12.0, 9.0), Color(0.84, 0.86, 0.9))
	n.draw_rect(Rect2(-w + 6.0, -11.0, w * 2.0 - 12.0, 5.0), color)


## Imagem recortada em círculo (mesma ideia do rosto no campo da tela de formação)
func _draw_round_face(n: Node2D, tex: Texture2D, center: Vector2, radius: float) -> void:
	var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
	var su: float = 1.0 / aspect if aspect >= 1.0 else 1.0
	var sv: float = 1.0 if aspect >= 1.0 else aspect
	var cv: float = 0.5 - maxf(0.0, 1.0 - aspect) * 0.25   # retrato alto: foca na parte de cima
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 28:
		var a: float = TAU * float(i) / 28.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
		uvs.append(Vector2(0.5 + 0.5 * cos(a) * su, cv + 0.5 * sin(a) * sv))
	n.draw_colored_polygon(pts, Color.WHITE, uvs, tex)


# ---------- LOOP ----------

func _process(delta: float) -> void:
	# Bandeirinhas: só 4 desenhos pequenos por quadro
	for d in _flag_drawers:
		d.queue_redraw()

	# Banco: lê os reservas e redesenha em ritmo baixo (mais rápido enquanto comemora)
	var cheering: bool = _cheer[0] > 0.0 or _cheer[1] > 0.0
	_bench_timer -= delta
	if _bench_timer <= 0.0:
		_bench_timer = 1.0 / 30.0 if cheering else 1.0 / 10.0
		_update_bench_data()
		for team in 2:
			if _bench_drawers[team] != null:
				_bench_drawers[team].queue_redraw()
	for team in 2:
		_cheer[team] = maxf(0.0, _cheer[team] - delta / 1.8)

	if _photo_mode:
		_photo_process(delta)


# ---------- MODO FOTO (F3) ----------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == photo_mode_key:
		_toggle_photo_mode()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _photo_mode or _photo_cam == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var step: float = 1.1
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_photo_zoom_target = clampf(_photo_zoom_target * step,
				_photo_zoom_start.x * photo_zoom_range.x, _photo_zoom_start.x * photo_zoom_range.y)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_photo_zoom_target = clampf(_photo_zoom_target / step,
				_photo_zoom_start.x * photo_zoom_range.x, _photo_zoom_start.x * photo_zoom_range.y)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		_photo_offset_target -= event.relative / maxf(_photo_cam.zoom.x, 0.01)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_photo_zoom_target = _photo_zoom_start.x
		_photo_offset_target = _photo_offset_start


## Alguma tela "grande" (formação, pausa...) está aberta? Aí o modo foto não faz sentido.
func _modal_open() -> bool:
	var layers: Array[CanvasLayer] = []
	_collect_layers(get_tree().root, layers)
	for layer in layers:
		if layer != _photo_toast and layer.visible and layer.layer >= photo_modal_layer:
			return true
	return false


func _collect_layers(node: Node, out: Array[CanvasLayer]) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			out.append(child)
		_collect_layers(child, out)


func _toggle_photo_mode() -> void:
	if _photo_mode:
		_exit_photo_mode()
	elif not _modal_open():
		_enter_photo_mode()


func _enter_photo_mode() -> void:
	_photo_mode = true
	_photo_hidden.clear()

	# Esconde a interface: camadas da partida e controles soltos na cena
	var layers: Array[CanvasLayer] = []
	_collect_layers(get_tree().root, layers)
	for layer in layers:
		if layer != _photo_toast and layer.visible and layer.layer < photo_modal_layer:
			layer.visible = false
			_photo_hidden.append(layer)
	var scene: Node = get_tree().current_scene
	if scene != null:
		for child in scene.get_children():
			if child is Control and (child as Control).visible:
				(child as Control).visible = false
				_photo_hidden.append(child as Control)

	# Câmera: zoom e deslocamento começam de onde já estão (restaurados ao sair)
	_photo_cam = get_viewport().get_camera_2d()
	if _photo_cam != null:
		_photo_zoom_start = _photo_cam.zoom
		_photo_offset_start = _photo_cam.offset
		_photo_zoom_target = _photo_zoom_start.x
		_photo_offset_target = _photo_offset_start
		if _photo_tween != null:
			_photo_tween.kill()
	_show_photo_toast()


func _exit_photo_mode() -> void:
	_photo_mode = false
	for item in _photo_hidden:
		if is_instance_valid(item):
			item.visible = true
	_photo_hidden.clear()
	if _photo_toast != null:
		_photo_toast.visible = false
	if _photo_cam != null and is_instance_valid(_photo_cam):
		_photo_tween = create_tween().set_parallel(true)
		_photo_tween.tween_property(_photo_cam, "zoom", _photo_zoom_start, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_photo_tween.tween_property(_photo_cam, "offset", _photo_offset_start, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_photo_cam = null


## Zoom/movimento suaves e a checagem de telas que abrem durante o modo foto
func _photo_process(delta: float) -> void:
	if _photo_cam != null and is_instance_valid(_photo_cam):
		var dir := Vector2(
			Input.get_axis(&"ui_left", &"ui_right"), Input.get_axis(&"ui_up", &"ui_down"))
		if dir != Vector2.ZERO:
			_photo_offset_target += dir * 700.0 * delta / maxf(_photo_cam.zoom.x, 0.01)
		var k: float = 1.0 - exp(-9.0 * delta)
		var z: float = lerpf(_photo_cam.zoom.x, _photo_zoom_target, k)
		_photo_cam.zoom = Vector2(z, z)
		_photo_cam.offset = _photo_cam.offset.lerp(_photo_offset_target, k)
	_photo_check -= delta
	if _photo_check <= 0.0:
		_photo_check = 0.3
		if _modal_open():
			_exit_photo_mode()   # abriu uma tela grande (ex: pausa): sai do modo foto


## Aviso rápido no pé da tela (some sozinho)
func _show_photo_toast() -> void:
	if _photo_toast == null:
		_photo_toast = CanvasLayer.new()
		_photo_toast.layer = 99
		add_child(_photo_toast)
		_photo_label = Label.new()
		_photo_label.text = "MODO FOTO   ·   F3 volta   ·   roda: zoom   ·   botão do meio / setas: mover   ·   R: centralizar"
		_photo_label.add_theme_font_size_override("font_size", 18)
		_photo_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		_photo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_photo_label.add_theme_constant_override("outline_size", 6)
		_photo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_photo_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_photo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_photo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_photo_label.offset_bottom = -24.0
		_photo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_photo_toast.add_child(_photo_label)
	_photo_toast.visible = true
	_photo_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_photo_label, "modulate:a", 0.0, 1.0)
