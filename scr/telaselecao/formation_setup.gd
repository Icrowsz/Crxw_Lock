class_name FormationSetup
extends CanvasLayer
## Tela de montagem das formações, antes da partida.
##
## VISUAL: o campo do jogo some atrás de um fundo escuro (só um rastro dele com opacidade baixa).
## À esquerda ficam dois cartões grandes: "Personalizar time" (nome, ícone e cor) e "Formações"
## (abre a lista de formações prontas). À direita fica o CAMPO EM PERSPECTIVA, com a imagem de
## cada personagem numa bolinha:
##   - arrastar uma bolinha do time da vez move o jogador de verdade no campo do jogo;
##   - DUPLO CLIQUE numa bolinha abre o menu de personagens, na esquerda;
##   - ao confirmar um time, o campo gira e o outro time passa a ficar na frente.
## A tela inteira balança de leve o tempo todo e "faz gelatina" a cada interação (UiStyle).
##
## Um time por vez: o time da vez arrasta os próprios jogadores (só dentro da sua metade do
## campo, que fica destacada) ou escolhe uma formação pronta, e depois confirma.
## Quando todos os times confirmaram, emite "finished" e some.
##
## O MatchManager cria este nó sozinho (use_formation_setup).
##
## Identidade do time: nome, cor (17 cores prontas + seletor livre + aleatória) e ÍCONE (logo),
## que aparece num selo ao lado do nome e como marca d'água na metade do campo do time.
##
## O SELETOR (menu da esquerda) é uma grade com o rosto e o nome de cada personagem. Ao
## confirmar, aparece a imagem completa do personagem com um flash de tela.
## As imagens vêm do CharacterRoster (face_for / full_for) e do KeeperRoster (face_for / art_for).
##
## O seletor tem ABAS de categoria (Atacantes, Laterais, Meio-campistas, Zagueiros; veja
## CharacterRoster.ROLES): abre na categoria que combina com a posição, mas dá para escolher
## qualquer personagem (aba "Todos"). Também tem busca por nome, aviso de quem já está em campo,
## botão Sortear, duplo clique para escolher e Enter para confirmar.
## Depois de confirmar um time, o botão "Voltar" deixa editar o time anterior de novo.
## Passar o mouse numa formação pronta mostra os espaços dela no campo antes de aplicar.
##
## BANCO: embaixo do campo há 3 vagas de RESERVAS por time (BenchManager.RESERVES).
## Clicar numa vaga abre o mesmo seletor; o reserva escolhido entra numa substituição durante o jogo.

signal finished

var manager: MatchManager

var _field: Field
var _team: int = -1
var _confirmed: Array[bool] = []
var _keeper_retried: bool = false  # o Field cria os goleiros no próximo frame: tenta de novo uma vez
var _snapshot: Dictionary = {}     # Player -> posição quando começou a editar (botão "Restaurar")
var _targets: Dictionary = {}      # Player -> destino de uma formação pronta que ainda está deslizando
var _dragging: Player = null
var _drag_offset: Vector2 = Vector2.ZERO
var _hover: Player = null
var _move_tween: Tween
var _color_tween: Tween

var _overlay: _Overlay
var _title: Label
var _title_style: StyleBoxFlat
var _preset_box: HFlowContainer
var _bg: ColorRect                   # fundo escuro que esconde o campo do jogo
var _pitch: _PerspectivePitch        # campo em perspectiva (direita)
var _left_col: VBoxContainer         # cartões da esquerda (somem quando o seletor abre)
var _card_team: Button
var _card_forms: Button
var _card_badge: TeamBadge
var _preset_panel: PanelContainer    # lista de formações (abre embaixo do cartão "Formações")
var _bench_row: HBoxContainer        # vagas de reservas embaixo do campo
var _picker_panel: PanelContainer
var _spin_tween: Tween
var _spun_once: bool = false
var _formation_label: Label
var _formation_name: String = ""     # formação pronta aplicada ("" = montada na mão)
var _slot_targets: Array[Node2D] = []   # Player/Goalkeeper de cada posição (índice = número - 1)

var _modal_open: bool = false        # seletor ou revelação na tela: o campo não recebe cliques
var _picker: Control
var _picker_title: Label
var _picker_name: Label
var _picker_desc: Label            # texto curto do goleiro escolhido (só aparece para goleiros)
var _picker_grid: GridContainer
var _picker_index: int = -1
var _picker_is_keeper: bool = false
var _picker_entries: Array[Dictionary] = []
var _picker_current_id: String = ""
var _picker_pending_id: String = ""
var _pick_buttons: Dictionary = {}   # id -> Button
var _pick_tags: Dictionary = {}      # id -> Label ("Já no time" / "No adversário")
var _picker_scroll: ScrollContainer
var _picker_role_hint: Label         # sugestão de categoria para a posição
var _picker_tab_box: HFlowContainer  # abas de categoria
var _picker_tab_buttons: Dictionary = {}   # categoria ("" = Todos) -> Button
var _picker_tab: String = ""         # aba aberta ("" = Todos)
var _picker_recommended: String = "" # categoria sugerida para a posição aberta
var _picker_search: LineEdit
var _picker_empty: Label             # "nenhum personagem encontrado"
var _composition_label: Label        # resumo do time por categorias
var _back_button: Button             # volta para editar o time anterior (já confirmado)
var _history: Array[int] = []        # times já confirmados, na ordem (o último é o do "Voltar")
var _formation_by_team: Dictionary = {}   # time -> formação pronta aplicada quando confirmou
var _preview_active: bool = false    # mostrando os espaços de uma formação (mouse em cima do botão)
var _slots_before_preview: Array[Vector2] = []

var _reveal: Control
var _reveal_box: VBoxContainer
var _reveal_image: TextureRect
var _reveal_placeholder: Label
var _reveal_name: Label
var _reveal_flash: ColorRect
var _reveal_band: ColorRect          # faixa inclinada na cor do time atrás da imagem
var _reveal_badge: TeamBadge
var _reveal_token: int = 0
var _reveal_start_msec: int = 0

const CARD_BG := Color(0.13, 0.15, 0.20)
const CARD_HOVER := Color(0.19, 0.22, 0.30)
const UI_SCALE: float = 1.3          # aumenta todos os textos da tela de formação
const PICK_FACE_SIZE: int = 108      # rosto no seletor (menu da esquerda)
const PICK_COLUMNS: int = 4
const PICK_CARD_W: float = 132.0
const PICK_PANEL_W: float = 4.0 * (132.0 + 10.0)
const WIDE_ROLE_THRESHOLD: float = 0.62   # quão aberto (0 = centro, 1 = lateral) para sugerir Lateral
var _name_edit: LineEdit             # nome do time
var _top_panel: PanelContainer       # faixa do topo (título + botão "Personalizar time")
var _banner_badge: TeamBadge         # selo do time na faixa do topo
var _team_modal: Control             # janela "Personalizar time": nome, ícone e cor
var _swatch_box: HFlowContainer      # bolinhas de cor do time (quebra em linhas)
var _custom_picker: ColorPickerButton   # cor livre
var _updating_picker: bool = false      # mudando o seletor por código (não é escolha do jogador)
var _color_hint: Label                  # aviso: cor parecida com o outro time / com o gramado
var _icon_badge: TeamBadge              # selo do time na linha do nome
var _icon_name_label: Label
var _icon_picker: Control
var _icon_title: Label
var _icon_hint: Label
var _icon_grid: GridContainer
const ICON_COLUMNS: int = 5
var _confirm_button: Button


## Destaque desenhado no campo: metade do time, espaços da formação e anel nos jogadores
class _Overlay extends Node2D:
	var rect: Rect2 = Rect2()
	var color: Color = Color.WHITE
	var slots: Array[Vector2] = []        # coordenadas locais do campo
	var players: Array[Player] = []
	var hover: Player = null
	var dragging: Player = null
	var icon: Texture2D = null   # ícone do time: marca d'água no centro da metade do campo

	func _draw() -> void:
		draw_rect(rect, Color(color, 0.14))
		draw_rect(rect, Color(color, 0.65), false, 3.0)
		if icon != null:
			var box: float = minf(rect.size.x, rect.size.y) * 0.42
			var aspect: float = float(icon.get_width()) / maxf(float(icon.get_height()), 1.0)
			var s: Vector2 = Vector2(box, box / aspect) if aspect >= 1.0 else Vector2(box * aspect, box)
			draw_texture_rect(icon, Rect2(rect.get_center() - s * 0.5, s), false, Color(1, 1, 1, 0.16))
		for s in slots:
			draw_arc(s, 16.0, 0.0, TAU, 24, Color(color.lightened(0.3), 0.8), 2.0)
			draw_circle(s, 3.0, Color(color.lightened(0.3), 0.8))
		for p in players:
			var strong: bool = p == hover or p == dragging
			var width: float = 4.0 if strong else 2.0
			var alpha: float = 1.0 if strong else 0.7
			draw_arc(to_local(p.global_position), 30.0, 0.0, TAU, 32, Color(1, 1, 1, alpha), width)


## Campo em PERSPECTIVA (3D de verdade, projetado à mão): mostra todos os jogadores como bolinhas
## com a imagem do personagem. O time da vez (editable_team) fica perto da câmera, tem os jogadores
## arrastáveis (arrastar muda a posição real no campo do jogo) e duplo clique troca o personagem.
## "yaw" gira o campo em volta do eixo vertical: ao confirmar um time o campo dá meia-volta e o
## outro time passa a ficar na frente. Molinhas internas dão o balanço natural e a gelatina.
class _PerspectivePitch extends Control:
	signal dot_double_clicked(node: Node2D)
	signal drag_started(node: Node2D)
	signal dragged(node: Node2D, field_norm: Vector2)   # posição no campo, normalizada (-1..1)
	signal drag_ended(node: Node2D)

	const CAM_HEIGHT: float = 2.6      # altura da câmera (o campo tem 1 de meia-extensão no comprimento)
	const CAM_DIST: float = 3.1        # distância da câmera até o centro do campo
	const DOT_RADIUS: float = 0.09     # raio do personagem no mundo
	const KEEPER_RADIUS: float = 0.09


	var field: Field
	var targets: Array = []             # todos os jogadores e goleiros (de todos os times)
	var team_count: int = 2
	var editable_team: int = 0
	var slots: Array[Vector2] = []      # guias de formação (coordenadas locais do campo)
	var yaw: float = 0.0                # giro do campo (0 ou PI = um time ou o outro na frente)
	var spinning: bool = false          # girando: sem cliques
	var locked: bool = false            # outra janela aberta: sem cliques
	var selected: Node2D = null         # personagem com o seletor aberto
	var tint: Color = Color(0, 0, 0, 0)

	var _focal: float = 400.0
	var _center: Vector2 = Vector2.ZERO
	var _t: float = 0.0
	var _wob: float = 0.0
	var _wob_v: float = 0.0
	var _bounce: float = 0.0
	var _bounce_v: float = 0.0
	var _springs: Dictionary = {}       # instance_id -> Vector2(escala, velocidade)
	var _hover: Node2D = null
	var _drag_node: Node2D = null
	var _drag_pending: Node2D = null
	var _press_pos: Vector2 = Vector2.ZERO
	var _grab_offset: Vector2 = Vector2.ZERO
	var _tex_cache: Dictionary = {}     # instance_id -> Texture2D (ou null)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = false
		custom_minimum_size = Vector2(420.0, 360.0)

	# ---------- gelatina ----------

	## Sacode o campo inteiro (interação na tela). strength ~ 0.5 leve, 1 normal, 2 forte
	func kick(strength: float = 1.0) -> void:
		_wob_v += strength * 3.4
		_bounce_v += strength * 2.2

	## Dá um "pulinho" de gelatina no personagem
	func pulse(node: Node2D, strength: float = 1.0) -> void:
		if node == null:
			return
		var sp: Vector2 = _springs.get(node.get_instance_id(), Vector2(1.0, 0.0))
		sp.y += 7.0 * strength
		_springs[node.get_instance_id()] = sp

	func refresh_targets() -> void:
		_tex_cache.clear()
		queue_redraw()

	func _process(delta: float) -> void:
		var dt: float = minf(delta, 0.033)
		_t += dt
		_wob_v += (-70.0 * _wob - 5.0 * _wob_v) * dt
		_wob += _wob_v * dt
		_bounce_v += (-90.0 * _bounce - 6.0 * _bounce_v) * dt
		_bounce += _bounce_v * dt
		for node in targets:
			if not is_instance_valid(node):
				continue
			var id: int = node.get_instance_id()
			var sp: Vector2 = _springs.get(id, Vector2(1.0, 0.0))
			var want: float = 1.0
			if node == _drag_node:
				want = 1.3
			elif node == _hover or node == selected:
				want = 1.14
			sp.y += ((want - sp.x) * 150.0 - sp.y * 9.0) * dt
			sp.x += sp.y * dt
			_springs[id] = sp
		queue_redraw()

	# ---------- câmera ----------

	func _wr() -> float:
		return clampf(field.pitch_size.y / maxf(field.pitch_size.x, 1.0), 0.35, 1.0)

	func _alpha() -> float:
		return atan2(CAM_HEIGHT, CAM_DIST)

	func _yaw_now() -> float:
		return yaw + sin(_t * 0.65) * 0.03 + _wob * 0.07

	func _zoom() -> float:
		var spin: float = 1.0 - 0.36 * absf(sin(yaw))
		return spin * (1.0 + sin(_t * 1.05) * 0.006 + _bounce * 0.035)

	## Ponto do campo (nx = comprimento, ny = largura, -1..1) -> espaço da câmera
	func _cam(nx: float, ny: float, ang: float, lift: float = 0.0) -> Vector3:
		var x: float = ny * _wr()
		var cy: float = cos(ang)
		var sy: float = sin(ang)
		var xp: float = x * cy + nx * sy
		var zp: float = -x * sy + nx * cy
		var a: float = _alpha()
		var dy: float = -CAM_HEIGHT + lift
		var dz: float = zp + CAM_DIST
		return Vector3(xp, dy * cos(a) + dz * sin(a), -dy * sin(a) + dz * cos(a))

	## Ajusta o zoom/centro para o campo (de frente) caber na área
	func _fit() -> void:
		var min_p := Vector2(INF, INF)
		var max_p := Vector2(-INF, -INF)
		for cx in [-1.0, 1.0]:
			for cy in [-1.0, 1.0]:
				var c: Vector3 = _cam(cx, cy, 0.0)
				var q := Vector2(c.x / c.z, -c.y / c.z)
				min_p = Vector2(minf(min_p.x, q.x), minf(min_p.y, q.y))
				max_p = Vector2(maxf(max_p.x, q.x), maxf(max_p.y, q.y))
		var bw: float = maxf(max_p.x - min_p.x, 0.001)
		var bh: float = maxf(max_p.y - min_p.y, 0.001)
		_focal = minf(size.x * 0.94 / bw, size.y * 0.80 / bh)
		_center = size * 0.5 - _focal * (min_p + max_p) * 0.5 + Vector2(0.0, size.y * 0.04)

	## Ponto do campo -> tela. z = pixels por unidade do mundo naquele ponto (escala)
	func _proj(nx: float, ny: float, lift: float = 0.0) -> Vector3:
		var c: Vector3 = _cam(nx, ny, _yaw_now(), lift)
		var f: float = _focal * _zoom()
		return Vector3(_center.x + f * c.x / c.z, _center.y - f * c.y / c.z, f / c.z)

	func _p(nx: float, ny: float) -> Vector2:
		var v: Vector3 = _proj(nx, ny)
		return Vector2(v.x, v.y)

	## Tela -> ponto do campo (inverso da projeção, no chão)
	func _unproject(sp: Vector2) -> Vector2:
		var f: float = _focal * _zoom()
		var u: float = (sp.x - _center.x) / f
		var v: float = (_center.y - sp.y) / f
		var a: float = _alpha()
		var denom: float = minf(v * cos(a) - sin(a), -0.001)
		var t: float = -CAM_HEIGHT / denom
		var xp: float = t * u
		var zp: float = t * (v * sin(a) + cos(a)) - CAM_DIST
		var ang: float = _yaw_now()
		var x: float = xp * cos(ang) - zp * sin(ang)
		var zr: float = xp * sin(ang) + zp * cos(ang)
		return Vector2(clampf(zr, -1.0, 1.0), clampf(x / _wr(), -1.0, 1.0))

	# ---------- personagens ----------

	func _norm_of(node: Node2D) -> Vector2:
		var half: Vector2 = field.pitch_size * 0.5
		var l: Vector2 = field.to_local(node.global_position)
		return Vector2(clampf(l.x / half.x, -1.0, 1.0), clampf(l.y / half.y, -1.0, 1.0))

	func _team_of(node: Node2D) -> int:
		return int(node.get("team"))

	func _radius_of(node: Node2D) -> float:
		return KEEPER_RADIUS if node is Goalkeeper else DOT_RADIUS

	func _interactive(node: Node2D) -> bool:
		return is_instance_valid(node) and _team_of(node) == editable_team

	## Centro (na tela), raio e profundidade do personagem
	func _geometry(node: Node2D) -> Dictionary:
		var n: Vector2 = _norm_of(node)
		var g: Vector3 = _proj(n.x, n.y)
		var sp: Vector2 = _springs.get(node.get_instance_id(), Vector2(1.0, 0.0))
		var r: float = _radius_of(node) * g.z * maxf(sp.x, 0.2)
		var bob: float = sin(_t * 2.1 + float(node.get_instance_id() % 97)) * 1.4
		var cam: Vector3 = _cam(n.x, n.y, _yaw_now())
		return {"ground": Vector2(g.x, g.y), "center": Vector2(g.x, g.y - r * 1.05 + bob),
			"r": r, "z": cam.z}

	func _node_at(pos: Vector2) -> Node2D:
		var best: Node2D = null
		var best_d: float = INF
		for node in targets:
			if not _interactive(node):
				continue
			var geo: Dictionary = _geometry(node)
			var d: float = (geo["center"] as Vector2).distance_to(pos)
			if d <= float(geo["r"]) * 1.15 and d < best_d:
				best = node
				best_d = d
		return best

	func _texture_of(node: Node2D) -> Texture2D:
		var id: int = node.get_instance_id()
		if _tex_cache.has(id):
			return _tex_cache[id] as Texture2D
		var tex: Texture2D = null
		if node is Goalkeeper:
			tex = KeeperRoster.face_for((node as Goalkeeper).keeper_id)
		elif node is Player:
			tex = CharacterRoster.face_for((node as Player).character_id)
		_tex_cache[id] = tex
		return tex

	# ---------- entrada ----------

	func _gui_input(event: InputEvent) -> void:
		if spinning or locked or field == null:
			return
		if event is InputEventMouseMotion:
			var pos: Vector2 = (event as InputEventMouseMotion).position
			if _drag_pending != null and pos.distance_to(_press_pos) > 4.0:
				_drag_node = _drag_pending
				_drag_pending = null
				drag_started.emit(_drag_node)
			if _drag_node != null:
				dragged.emit(_drag_node, _unproject(pos - _grab_offset))
			else:
				var over: Node2D = _node_at(pos)
				if over != _hover:
					_hover = over
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over != null \
						else Control.CURSOR_ARROW
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				var node: Node2D = _node_at(mb.position)
				if node == null:
					return
				accept_event()
				pulse(node, 0.6)
				if mb.double_click:
					_drag_pending = null
					_drag_node = null
					dot_double_clicked.emit(node)
				elif node is Player:
					_drag_pending = node
					_press_pos = mb.position
					_grab_offset = mb.position - (_geometry(node)["center"] as Vector2)
			else:
				if _drag_node != null:
					pulse(_drag_node, 1.2)   # soltou: a bolinha "quica"
					drag_ended.emit(_drag_node)
				_drag_node = null
				_drag_pending = null
				accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and _drag_node == null:
			_hover = null
			mouse_default_cursor_shape = Control.CURSOR_ARROW

	# ---------- desenho ----------

	func _poly(points: Array, color: Color, width: float, closed: bool = false) -> void:
		var pts := PackedVector2Array()
		for q in points:
			pts.append(_p((q as Vector2).x, (q as Vector2).y))
		if closed and not points.is_empty():
			pts.append(pts[0])
		if pts.size() >= 2:
			draw_polyline(pts, color, width, true)

	func _quad(x0: float, x1: float, y0: float, y1: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([_p(x0, y0), _p(x1, y0), _p(x1, y1), _p(x0, y1)]), color)

	func _draw() -> void:
		if field == null:
			return
		_fit()
		var wr: float = _wr()

		# Placa do campo (sombra + gramado + listras + metades dos times)
		var plate := PackedVector2Array([_p(-1, -1), _p(1, -1), _p(1, 1), _p(-1, 1)])
		var shadow := PackedVector2Array()
		for q in plate:
			shadow.append(q + Vector2(0.0, 16.0))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
		draw_colored_polygon(plate, Color(0.14, 0.42, 0.22))
		if tint.a > 0.0:
			draw_colored_polygon(plate, tint)
		var bands: int = 12
		for i in bands:
			if i % 2 == 0:
				var x0: float = -1.0 + 2.0 * float(i) / float(bands)
				_quad(x0, x0 + 2.0 / float(bands), -1.0, 1.0, Color(1, 1, 1, 0.055))
		for t in team_count:
			var left: bool = field.defend_dir(t) < 0
			var tint: Color = TeamStyle.color_of(t)
			_quad(-1.0 if left else 0.0, 0.0 if left else 1.0, -1.0, 1.0,
				Color(tint, 0.26 if t == editable_team else 0.09))

		# Linhas do campo
		var line := Color(1, 1, 1, 0.88)
		_poly([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)], line, 2.2, true)
		_poly([Vector2(0, -1), Vector2(0, 1)], line, 2.0)
		var circle: Array = []
		for i in 33:
			var a: float = TAU * float(i) / 32.0
			circle.append(Vector2(0.17 * cos(a), 0.17 * sin(a) / wr))
		_poly(circle, line, 2.0)
		for sgn in [-1.0, 1.0]:
			_poly([Vector2(sgn, -0.59), Vector2(sgn * 0.686, -0.59), Vector2(sgn * 0.686, 0.59), Vector2(sgn, 0.59)], line, 2.0)
			_poly([Vector2(sgn, -0.27), Vector2(sgn * 0.895, -0.27), Vector2(sgn * 0.895, 0.27), Vector2(sgn, 0.27)], line, 2.0)
			_poly([Vector2(sgn, -0.11), Vector2(sgn * 1.04, -0.11), Vector2(sgn * 1.04, 0.11), Vector2(sgn, 0.11)], Color(1, 1, 1, 0.7), 2.0)
			var arc: Array = []   # meia-lua da área (só a parte de fora)
			for i in 25:
				var a2: float = -1.1 + 2.2 * float(i) / 24.0
				var px: float = sgn * 0.79 - sgn * 0.174 * cos(a2)
				if absf(px) < 0.686:
					arc.append(Vector2(px, 0.174 * sin(a2) / wr))
			_poly(arc, line, 2.0)

		# Guias da formação (a pré-visualização dos botões de formação)
		var half: Vector2 = field.pitch_size * 0.5
		for s in slots:
			var n := Vector2(clampf(s.x / half.x, -1.0, 1.0), clampf(s.y / half.y, -1.0, 1.0))
			var ring: Array = []
			for i in 21:
				var a3: float = TAU * float(i) / 20.0
				ring.append(Vector2(n.x + 0.05 * cos(a3), n.y + 0.05 * sin(a3) / wr))
			var gc: Color = TeamStyle.color_of(editable_team).lightened(0.4)
			_poly(ring, Color(gc, 0.95), 2.4)

		# Personagens, do fundo para a frente
		var order: Array[Node2D] = []
		for node in targets:
			if is_instance_valid(node):
				order.append(node)
		var geos: Dictionary = {}
		for node in order:
			geos[node] = _geometry(node)
		order.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return float((geos[a] as Dictionary)["z"]) > float((geos[b] as Dictionary)["z"]))
		var number: int = 0
		var numbers: Dictionary = {}
		for node in targets:
			if is_instance_valid(node) and node is Player and _team_of(node) == editable_team:
				number += 1
				numbers[node] = number
		for node in order:
			_draw_dot(node, geos[node] as Dictionary, int(numbers.get(node, 0)))

	func _draw_dot(node: Node2D, geo: Dictionary, number: int) -> void:
		var r: float = geo["r"]
		var c: Vector2 = geo["center"]
		var ground: Vector2 = geo["ground"]
		var team: int = _team_of(node)
		var color: Color = TeamStyle.color_of(team)
		var mine: bool = team == editable_team
		var strong: bool = node == _hover or node == _drag_node or node == selected

		# sombra no chão
		var sh := PackedVector2Array()
		for i in 20:
			var a: float = TAU * float(i) / 20.0
			sh.append(ground + Vector2(cos(a) * r * 0.95, sin(a) * r * 0.34 + 2.0))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.38 if not strong else 0.5))

		# aro na cor do time (mais grosso e claro para quem pode ser editado)
		var ring_w: float = maxf(r * (0.16 if mine else 0.1), 2.0)
		draw_circle(c, r + ring_w, Color.WHITE if strong else color.lightened(0.15 if mine else 0.0))
		draw_circle(c, r + ring_w * 0.55, color)

		# imagem do personagem recortada em círculo
		var tex: Texture2D = _texture_of(node)
		var modulate_c: Color = Color.WHITE if mine else Color(0.82, 0.84, 0.9, 1.0)
		if tex != null:
			var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
			var su: float = 1.0 / aspect if aspect >= 1.0 else 1.0
			var sv: float = 1.0 if aspect >= 1.0 else aspect
			var cv: float = 0.5 - maxf(0.0, 1.0 - aspect) * 0.25   # retrato alto: foca na parte de cima
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 36:
				var a2: float = TAU * float(i) / 36.0
				pts.append(c + Vector2(cos(a2), sin(a2)) * r)
				uvs.append(Vector2(0.5 + 0.5 * cos(a2) * su, cv + 0.5 * sin(a2) * sv))
			draw_colored_polygon(pts, modulate_c, uvs, tex)
		else:
			draw_circle(c, r, color.darkened(0.45))
			var font: Font = ThemeDB.fallback_font
			var letter: String = "G" if node is Goalkeeper else "?"
			var fs: int = maxi(int(r * 1.1), 8)
			draw_string(font, c + Vector2(-r, fs * 0.35), letter, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)

		# número da posição (só do time da vez; G = goleiro)
		if mine and r > 6.0:
			var br: float = maxf(r * 0.36, 6.0)
			var bp: Vector2 = c + Vector2(r * 0.72, r * 0.72)
			draw_circle(bp, br + 1.5, Color(0, 0, 0, 0.55))
			draw_circle(bp, br, color.darkened(0.15))
			var txt: String = "G" if node is Goalkeeper else str(number)
			var fsz: int = maxi(int(br * 1.25), 7)
			draw_string(ThemeDB.fallback_font, bp + Vector2(-br, fsz * 0.36), txt,
				HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, fsz, Color.WHITE)


func _ready() -> void:
	layer = 12  # acima do placar e do menu da partida
	_field = get_tree().get_first_node_in_group("field") as Field
	if _field == null:
		push_warning("FormationSetup: nenhum Field encontrado; pulando a montagem das formações.")
		finished.emit.call_deferred()
		queue_free()
		return

	_confirmed.resize(manager.team_count)
	_confirmed.fill(false)

	_overlay = _Overlay.new()
	_overlay.z_as_relative = false
	_overlay.z_index = -4000   # acima do gramado, abaixo de jogadores e bola
	_overlay.visible = false   # o campo do jogo fica escondido; o destaque agora é desenhado no campo em perspectiva
	_field.add_child(_overlay)

	_build_ui()
	FormationExtras.attach(self)
	_pitch.slots = _overlay.slots
	_begin_team(0)
	_intro.call_deferred()


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()


# ---------- CONSTRUÇÃO ----------

func _fs(size: int) -> int:
	return int(round(float(size) * UI_SCALE))


## Painel com margens generosas (para a tela não ficar apertada)
func _big_panel(panel: PanelContainer, border: Color = UiStyle.PANEL_BORDER) -> StyleBoxFlat:
	var sb: StyleBoxFlat = UiStyle.panel_style(border, 30.0, 22.0)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	return sb


func _big_button(b: Button, min_size: Vector2, font: int) -> void:
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)


func _make_menu_card(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 136.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_card_button(b, _fs(22))
	return b


func _build_ui() -> void:
	# Fundo escuro: esconde o campo do jogo (sobra só um rastro dele, com a opacidade bem baixa)
	_bg = ColorRect.new()
	_bg.color = UiStyle.SCREEN_BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(cols)

	# ---------- ESQUERDA: cartões grandes ----------
	_left_col = VBoxContainer.new()
	_left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_left_col.add_theme_constant_override("separation", 30)
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.size_flags_stretch_ratio = 0.8
	_left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(_left_col)

	_card_team = _make_menu_card("Personalizar time")
	_card_team.tooltip_text = "Nome, ícone e cor do time"
	_card_team.pressed.connect(_open_team_modal)
	_left_col.add_child(_card_team)
	_card_badge = TeamBadge.make(0, 62.0)
	_card_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_SIZE, 26)
	_card_team.add_child(_card_badge)

	_card_forms = _make_menu_card("Formações")
	_card_forms.tooltip_text = "Formações prontas (passe o mouse para ver os espaços no campo)"
	_card_forms.pressed.connect(_toggle_presets)
	_left_col.add_child(_card_forms)

	_preset_panel = PanelContainer.new()
	_preset_panel.visible = false
	_big_panel(_preset_panel)
	_left_col.add_child(_preset_panel)
	_preset_box = HFlowContainer.new()
	_preset_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_preset_box.add_theme_constant_override("h_separation", 10)
	_preset_box.add_theme_constant_override("v_separation", 10)
	_preset_panel.add_child(_preset_box)

	# ---------- DIREITA: faixa do time, campo em perspectiva, reservas e botões ----------
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	right.add_theme_constant_override("separation", 12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(right)

	# Faixa do time (a borda leva a cor do time)
	_top_panel = PanelContainer.new()
	_top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_style = UiStyle.panel_style(UiStyle.PANEL_BORDER, 22.0, 10.0)
	_title_style.set_border_width_all(3)
	_top_panel.add_theme_stylebox_override("panel", _title_style)
	right.add_child(_top_panel)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_panel.add_child(top_row)
	_banner_badge = TeamBadge.make(0, 52.0)
	_banner_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_banner_badge)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 2)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_box)
	_title = UiStyle.make_label("", _fs(20))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_box.add_child(_title)
	_formation_label = UiStyle.make_label("", _fs(11), UiStyle.MUTED_COLOR)
	_formation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_box.add_child(_formation_label)
	_composition_label = UiStyle.make_label("", _fs(11), UiStyle.ACCENT_COLOR)
	_composition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_box.add_child(_composition_label)
	var hint: Label = UiStyle.make_label("Arraste • duplo clique para trocar o personagem", _fs(10), UiStyle.MUTED_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	top_row.add_child(hint)

	# Campo em perspectiva
	_pitch = _PerspectivePitch.new()
	_pitch.field = _field
	_pitch.team_count = manager.team_count
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.dot_double_clicked.connect(_on_dot_double_clicked)
	_pitch.drag_started.connect(_on_dot_drag_started)
	_pitch.dragged.connect(_on_dot_dragged)
	_pitch.drag_ended.connect(_on_dot_drag_ended)
	right.add_child(_pitch)

	# Reservas
	_bench_row = HBoxContainer.new()
	_bench_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bench_row.add_theme_constant_override("separation", 12)
	right.add_child(_bench_row)

	# Voltar (editar de novo o time que já confirmou) + Confirmar
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 16)
	right.add_child(action_row)

	_back_button = Button.new()
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.visible = false   # só aparece quando já existe um time confirmado para voltar
	UiStyle.style_button(_back_button, Color(0.35, 0.45, 0.85))
	_big_button(_back_button, Vector2(260.0, 54.0), _fs(15))
	_back_button.pressed.connect(_on_back_pressed)
	action_row.add_child(_back_button)

	_confirm_button = Button.new()
	UiStyle.style_button(_confirm_button, Color(0.25, 0.65, 0.35))
	_big_button(_confirm_button, Vector2(300.0, 54.0), _fs(16))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	action_row.add_child(_confirm_button)

	_build_team_modal()
	_build_picker()
	_build_icon_picker()
	_build_reveal()

	# A tela inteira reage a cada clique em botão
	for b: Button in [_card_team, _card_forms, _back_button, _confirm_button]:
		b.pressed.connect(_poke_ui)


## Entrada: os elementos "pulam" um depois do outro e depois ficam balançando de leve
func _intro() -> void:
	await get_tree().process_frame
	var floaters: Array = [_card_team, _card_forms, _top_panel, _pitch, _confirm_button]
	for i in floaters.size():
		var c: Control = floaters[i]
		c.pivot_offset = c.size * 0.5
		if c != _pitch:   # o campo tem a própria molinha
			UiStyle.alive(c, float(i) / float(floaters.size()))
	_card_badge.pivot_offset = _card_badge.size * 0.5
	UiStyle.jelly_chain([_card_team, _card_forms, _top_panel, _confirm_button], 1.12, 0.07)
	_pitch.kick(1.6)


## Mexeu em qualquer botão: o campo e os cartões balançam um pouco mais
func _poke_ui() -> void:
	_pitch.kick(0.7)
	UiStyle.jelly_chain([_card_team, _card_forms, _top_panel], 1.05, 0.05)


func _toggle_presets() -> void:
	_end_preview_preset()
	_preset_panel.visible = not _preset_panel.visible
	if _preset_panel.visible:
		UiStyle.pop(_preset_panel, 0.85, 0.4)


## Janela "Personalizar time": nome, ícone e cor, com folga entre as seções
func _build_team_modal() -> void:
	_team_modal = Control.new()
	_team_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_team_modal.visible = false
	add_child(_team_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_team_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_team_modal.add_child(center)

	var panel := PanelContainer.new()
	_big_panel(panel)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	panel.add_child(box)

	var title: Label = UiStyle.make_label("Personalizar time", _fs(24))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Nome
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 10)
	box.add_child(name_col)
	name_col.add_child(UiStyle.make_label("Nome do time", _fs(13), UiStyle.MUTED_COLOR))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(0.0, 52.0)
	_name_edit.add_theme_font_size_override("font_size", _fs(16))
	_name_edit.max_length = TeamStyle.MAX_NAME_LENGTH
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _name_edit.release_focus())
	name_col.add_child(_name_edit)

	# Ícone
	var icon_col := VBoxContainer.new()
	icon_col.add_theme_constant_override("separation", 10)
	box.add_child(icon_col)
	icon_col.add_child(UiStyle.make_label("Ícone (logo)", _fs(13), UiStyle.MUTED_COLOR))
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 18)
	icon_col.add_child(icon_row)
	_icon_badge = TeamBadge.make(0, 76.0)
	icon_row.add_child(_icon_badge)
	_icon_name_label = UiStyle.make_label("Emblema padrão", _fs(14))
	_icon_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_row.add_child(_icon_name_label)
	var icon_button := Button.new()
	icon_button.text = "Escolher ícone"
	icon_button.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(icon_button)
	_big_button(icon_button, Vector2(200.0, 52.0), _fs(15))
	icon_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_button.pressed.connect(_open_icon_picker)
	icon_row.add_child(icon_button)

	# Cor
	var color_col := VBoxContainer.new()
	color_col.add_theme_constant_override("separation", 14)
	box.add_child(color_col)
	color_col.add_child(UiStyle.make_label("Cor do time", _fs(13), UiStyle.MUTED_COLOR))
	_swatch_box = HFlowContainer.new()
	_swatch_box.add_theme_constant_override("h_separation", 14)
	_swatch_box.add_theme_constant_override("v_separation", 14)
	_swatch_box.custom_minimum_size = Vector2(640.0, 0.0)
	_swatch_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_col.add_child(_swatch_box)

	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 16)
	color_col.add_child(custom_row)
	var custom_label: Label = UiStyle.make_label("Cor personalizada", _fs(13))
	custom_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_row.add_child(custom_label)
	_custom_picker = ColorPickerButton.new()
	_custom_picker.custom_minimum_size = Vector2(110.0, 48.0)
	_custom_picker.edit_alpha = false
	_custom_picker.focus_mode = Control.FOCUS_NONE
	_custom_picker.tooltip_text = "Escolha qualquer cor"
	_custom_picker.color_changed.connect(_on_custom_color)
	_custom_picker.popup_closed.connect(_rebuild_swatches)   # só no fim, para não fechar o seletor
	custom_row.add_child(_custom_picker)
	var random_button := Button.new()
	random_button.text = "Aleatória"
	random_button.focus_mode = Control.FOCUS_NONE
	random_button.tooltip_text = "Sorteia uma cor"
	UiStyle.style_button(random_button)
	_big_button(random_button, Vector2(170.0, 48.0), _fs(15))
	random_button.pressed.connect(_on_random_color)
	custom_row.add_child(random_button)

	_color_hint = UiStyle.make_label("", _fs(12), UiStyle.MUTED_COLOR)
	_color_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_color_hint.custom_minimum_size = Vector2(640.0, 0.0)
	color_col.add_child(_color_hint)

	var done := Button.new()
	done.text = "Pronto"
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(done, Color(0.25, 0.65, 0.35))
	_big_button(done, Vector2(240.0, 56.0), _fs(16))
	done.pressed.connect(_close_team_modal)
	box.add_child(done)


func _open_team_modal() -> void:
	if _modal_open:
		return
	_finish_move()
	_dragging = null
	_team_modal.visible = true
	_modal_open = true


func _close_team_modal() -> void:
	_team_modal.visible = false
	_modal_open = false
	_rebuild_swatches()   # a bolinha marcada pode ter mudado com a cor livre


## Botões de formação do time atual (dependem de quantos jogadores ele tem)
func _rebuild_presets() -> void:
	for child in _preset_box.get_children():
		_preset_box.remove_child(child)
		child.queue_free()

	var count: int = manager.get_team_players(_team).size()
	for formation in Formations.presets_for(count):
		var b := Button.new()
		b.text = formation
		b.tooltip_text = Formations.nickname(formation)
		b.pressed.connect(_apply_preset.bind(formation))
		b.pressed.connect(_pitch.kick.bind(0.9))
		b.mouse_entered.connect(_preview_preset.bind(formation))
		b.mouse_exited.connect(_end_preview_preset)
		UiStyle.style_button(b)
		_big_button(b, Vector2(88.0, 50.0), _fs(14))
		_preset_box.add_child(b)

	var restore := Button.new()
	restore.text = "Restaurar"
	restore.pressed.connect(_restore)
	restore.pressed.connect(_pitch.kick.bind(0.9))
	UiStyle.style_button(restore, Color(0.75, 0.30, 0.30))
	_big_button(restore, Vector2(130.0, 50.0), _fs(14))
	_preset_box.add_child(restore)


# ---------- NOME E COR DO TIME ----------

func _on_name_changed(text: String) -> void:
	TeamStyle.set_team_name(_team, text)   # vazio = volta ao nome padrão
	_title.text = "Formação — %s" % manager.get_team_name(_team)


## Uma bolinha por cor da paleta. A do time está marcada; a que já é de um time que
## confirmou a formação fica apagada (um time ainda editando troca de cor com este).
func _rebuild_swatches() -> void:
	for child in _swatch_box.get_children():
		_swatch_box.remove_child(child)
		child.queue_free()

	var mine: Color = TeamStyle.color_of(_team)
	for entry in TeamStyle.PALETTE:
		var color: Color = entry["color"]
		var taken: bool = false
		for t in manager.team_count:
			if t != _team and _confirmed[t] and TeamStyle.similar(color, TeamStyle.color_of(t), 0.15):
				taken = true

		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = taken
		b.tooltip_text = ("%s (já é a cor do outro time)" if taken else "%s") % entry["name"]
		var selected: bool = color.is_equal_approx(mine)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = color.darkened(0.65) if taken else color
			if state == "hover":
				sb.bg_color = color.lightened(0.2)
			sb.set_corner_radius_all(23)
			sb.set_border_width_all(5 if selected else 2)
			sb.border_color = Color.WHITE if selected else Color(1, 1, 1, 0.3)
			b.add_theme_stylebox_override(state, sb)
		b.pressed.connect(_on_color_picked.bind(color))
		_swatch_box.add_child(b)
	_sync_custom_picker()


func _on_color_picked(color: Color) -> void:
	_set_color_hint("", UiStyle.MUTED_COLOR)
	_apply_color(color, true)


## Aplica a cor ao time atual. rebuild = false enquanto o seletor livre está aberto (refazer as
## bolinhas fecharia o seletor); elas se atualizam quando ele fecha.
func _apply_color(color: Color, rebuild: bool) -> void:
	var old: Color = TeamStyle.color_of(_team)
	if color.is_equal_approx(old):
		return

	# Se outro time (que ainda não confirmou) já usa exatamente essa cor, os dois trocam de cor
	for t in manager.team_count:
		if t != _team and TeamStyle.color_of(t).is_equal_approx(color):
			TeamStyle.set_color(t, old)
			_refresh_team_visuals(t)

	TeamStyle.set_color(_team, color)
	_refresh_team_visuals(_team)

	_overlay.color = color
	_overlay.queue_redraw()
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(_title_style, "border_color", color, 0.25)
	if rebuild:
		_rebuild_swatches()
		_sync_custom_picker()


## Repinta os jogadores e o goleiro de um time depois da troca de cor
func _refresh_team_visuals(team: int) -> void:
	for p in manager.get_team_players(team):
		p.refresh_team_color()
	for g in get_tree().get_nodes_in_group("goalkeepers"):
		if g.get("team") == team:
			(g as CanvasItem).queue_redraw()


# ---------- PAINEL LATERAL: MAPA DA FORMAÇÃO + POSIÇÕES ----------

func _card_style(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(border_width)
	sb.border_color = border
	return sb


## Rosto (ou, sem imagem, a inicial do nome num quadro escuro)
func _make_face(tex: Texture2D, label: String, px: int, border: Color) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	var sb: StyleBoxFlat = _card_style(Color(0.09, 0.10, 0.14), border, 2)
	sb.set_content_margin_all(0)
	holder.add_theme_stylebox_override("panel", sb)
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	else:
		var letter: Label = UiStyle.make_label(label.substr(0, 1).to_upper(), int(px * 0.5), UiStyle.MUTED_COLOR)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(letter)
	return holder


func _update_formation_label() -> void:
	if _formation_name == "":
		_formation_label.text = "Formação personalizada"
	else:
		var nick: String = Formations.nickname(_formation_name)
		_formation_label.text = "Formação %s%s" % [_formation_name, (" — " + nick) if nick != "" else ""]


func _character_name(id: String, fallback: Player) -> String:
	var entry: Dictionary = CharacterRoster.find(id)
	return String(entry.get("name", fallback.get_display_name()))


func _keeper_name(id: String) -> String:
	for k in KeeperRoster.KEEPERS:
		if k["id"] == id:
			return String(k["name"])
	return id


## Quão "para a frente" o jogador está na metade do time: 0 = linha de fundo, 1 = meio-campo
func _depth_of(node: Node2D) -> float:
	var area: Rect2 = Formations.team_area(_team, _field)
	var local: Vector2 = _field.to_local(node.global_position)
	var depth: float = (local.x - area.position.x) / maxf(area.size.x, 1.0)
	return 1.0 - depth if _field.defend_dir(_team) > 0 else depth


## Categoria de personagem que mais combina com onde a posição está (id de CharacterRoster.ROLES).
## É só uma SUGESTÃO: o seletor abre nela, mas dá para escolher qualquer personagem.
## Ataque = Atacante; defesa ou meio bem aberto, perto da lateral = Lateral; o resto da defesa =
## Zagueiro e o resto do meio = Meio-campista.
func _recommended_role(node: Node2D) -> String:
	var depth: float = _depth_of(node)
	if depth >= 0.67:
		return "atacante"
	var half_h: float = maxf(_field.pitch_size.y * 0.5, 1.0)
	var wide: float = absf(_field.to_local(node.global_position).y) / half_h
	if wide >= WIDE_ROLE_THRESHOLD:
		return "lateral"
	return "zagueiro" if depth < 0.34 else "meio"


## "Defesa / Meio-campo / Ataque", conforme onde o jogador está na metade do time
func _role_for(node: Node2D) -> String:
	if node is Goalkeeper:
		return "Goleiro"
	var depth: float = _depth_of(node)
	if depth < 0.34:
		return "Defesa"
	if depth < 0.67:
		return "Meio-campo"
	return "Ataque"


## Refaz o que o campo mostra e as vagas de reserva do time atual
func _rebuild_positions() -> void:
	_slot_targets.clear()
	for p in manager.get_team_players(_team):
		_slot_targets.append(p)

	# O goleiro do time (ele não é um Player: a troca é pelo KeeperRoster). O Field o cria no
	# próximo frame, então tenta de novo uma vez.
	var keeper: Goalkeeper = _keeper_of(_team)
	if keeper != null:
		_slot_targets.append(keeper)
	elif not _keeper_retried:
		_keeper_retried = true
		_rebuild_positions.call_deferred()

	_refresh_pitch_targets()
	_rebuild_bench()
	_update_composition()


## O campo em perspectiva mostra TODOS os personagens (os do outro time só para ver)
func _refresh_pitch_targets() -> void:
	var all: Array = []
	for t in manager.team_count:
		for p in manager.get_team_players(t):
			all.append(p)
	for k in get_tree().get_nodes_in_group("goalkeepers"):
		all.append(k)
	_pitch.targets = all
	_pitch.editable_team = _team
	_pitch.refresh_targets()


## Três vagas de reserva (embaixo do campo). Clicar abre o mesmo seletor.
## O índice da vaga no seletor é o número de posições + o número da vaga (veja _open_picker).
func _rebuild_bench() -> void:
	for child in _bench_row.get_children():
		_bench_row.remove_child(child)
		child.queue_free()
	_bench_row.visible = manager.bench != null
	if manager.bench == null:
		return
	var title: Label = UiStyle.make_label("Reservas", _fs(12), UiStyle.MUTED_COLOR)
	_bench_row.add_child(title)
	var team_color: Color = TeamStyle.color_of(_team)
	for slot in BenchManager.RESERVES:
		var id: String = manager.bench.reserve_id(_team, slot)
		var entry: Dictionary = CharacterRoster.find(id) if id != "" else {}
		var chip := Button.new()
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(82.0, 82.0)
		chip.expand_icon = true
		chip.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.tooltip_text = "Reserva %d: %s\nEntra no jogo quando o time faz uma substituição (máx. %d por partida)" \
			% [slot + 1, String(entry.get("name", "vaga vazia")), BenchManager.MAX_SUBS]
		if id != "":
			chip.icon = CharacterRoster.face_for(id)
		else:
			chip.text = "+"
			chip.add_theme_font_size_override("font_size", _fs(22))
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb: StyleBoxFlat = _card_style(CARD_HOVER if state != "normal" else CARD_BG,
				Color.WHITE if state == "pressed" else team_color, 3)
			sb.set_corner_radius_all(20)
			sb.set_content_margin_all(5)
			chip.add_theme_stylebox_override(state, sb)
		chip.pressed.connect(_open_picker.bind(_slot_targets.size() + slot))
		chip.pressed.connect(UiStyle.jelly.bind(chip, 1.2, 0.5))
		_bench_row.add_child(chip)


## Resumo do time pelas categorias dos personagens escolhidos (só informativo)
func _update_composition() -> void:
	if _composition_label == null:
		return
	var counts: Dictionary = {}
	var uncategorized: int = 0
	for p in manager.get_team_players(_team):
		var role: String = CharacterRoster.role_of(p.character_id)
		if role == "":
			uncategorized += 1
		else:
			counts[role] = int(counts.get(role, 0)) + 1
	var parts: PackedStringArray = []
	for r in CharacterRoster.ROLES:
		var n: int = int(counts.get(r["id"], 0))
		if n > 0:
			parts.append("%d %s" % [n, r["single"] if n == 1 else r["plural"]])
	if uncategorized > 0:
		parts.append("%d sem categoria" % uncategorized)
	_composition_label.text = ("Elenco: " + " · ".join(parts)) if not parts.is_empty() else ""


## Troca o personagem de um jogador (o nó antigo é substituído por um novo, no mesmo lugar)
func _apply_character(old: Player, id: String) -> void:
	if id == old.character_id:
		return

	_finish_move()
	_dragging = null
	_hover = null

	var fresh: Player = CharacterRoster.replace_player(old, id)
	if fresh == null:
		_rebuild_positions.call_deferred()   # não deu: a lista volta ao personagem de antes
		return

	manager.register_player(fresh)
	_pitch.kick(1.1)
	_pitch.pulse(fresh, 1.8)
	if _snapshot.has(old):
		_snapshot[fresh] = _snapshot[old]   # o "Restaurar" continua valendo para o jogador novo
		_snapshot.erase(old)

	var players: Array[Player] = manager.get_team_players(_team)
	_overlay.players = players
	_overlay.hover = null
	_overlay.dragging = null
	_overlay.queue_redraw()
	_rebuild_positions.call_deferred()


## O goleiro do time (null se o Field ainda não criou)
func _keeper_of(team: int) -> Goalkeeper:
	for k: Goalkeeper in get_tree().get_nodes_in_group("goalkeepers"):
		if k.team == team:
			return k
	return null


# ---------- SELETOR DE PERSONAGEM ----------

func _build_picker() -> void:
	# Menuzinho na ESQUERDA (o campo em perspectiva continua à direita, com o personagem escolhido em destaque)
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE)
	holder.custom_minimum_size = Vector2(PICK_PANEL_W + 100.0, 0.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		holder.add_theme_constant_override("margin_" + side, 24)
	holder.visible = false
	add_child(holder)
	_picker = holder

	var panel := PanelContainer.new()
	var panel_sb: StyleBoxFlat = _big_panel(panel)
	panel_sb.content_margin_left = 22.0
	panel_sb.content_margin_right = 22.0
	panel_sb.content_margin_top = 18.0
	panel_sb.content_margin_bottom = 18.0
	_picker_panel = panel
	holder.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	_picker_title = UiStyle.make_label("", _fs(20))
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_picker_title)
	var picker_hint: Label = UiStyle.make_label(
		"Clique e confirme (duplo clique escolhe na hora; Esc cancela)", _fs(10), UiStyle.MUTED_COLOR)
	picker_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	picker_hint.custom_minimum_size = Vector2(PICK_PANEL_W, 0.0)
	box.add_child(picker_hint)
	_picker_role_hint = UiStyle.make_label("", _fs(12), UiStyle.ACCENT_COLOR)
	_picker_role_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_role_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picker_role_hint.custom_minimum_size = Vector2(PICK_PANEL_W, 0.0)
	box.add_child(_picker_role_hint)

	# Abas de categoria (refeitas a cada abertura) e busca por nome
	_picker_tab_box = HFlowContainer.new()
	_picker_tab_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_picker_tab_box.add_theme_constant_override("h_separation", 8)
	_picker_tab_box.add_theme_constant_override("v_separation", 8)
	_picker_tab_box.custom_minimum_size = Vector2(PICK_PANEL_W, 0.0)
	box.add_child(_picker_tab_box)
	_picker_search = LineEdit.new()
	_picker_search.placeholder_text = "Buscar personagem..."
	_picker_search.clear_button_enabled = true
	_picker_search.custom_minimum_size = Vector2(PICK_PANEL_W - 20.0, 40.0)
	_picker_search.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picker_search.add_theme_font_size_override("font_size", _fs(13))
	_picker_search.text_changed.connect(func(_text: String) -> void: _apply_pick_filter())
	box.add_child(_picker_search)

	var scroll := ScrollContainer.new()
	# A grade usa a altura que sobra no menu (as abas e a busca ocupam espaço)
	scroll.custom_minimum_size = Vector2(PICK_PANEL_W, 200.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_picker_grid = GridContainer.new()
	_picker_grid.columns = PICK_COLUMNS
	_picker_grid.add_theme_constant_override("h_separation", 10)
	_picker_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_picker_grid)

	_picker_empty = UiStyle.make_label("Nenhum personagem encontrado nesta aba", _fs(13), UiStyle.MUTED_COLOR)
	_picker_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_empty.visible = false
	box.add_child(_picker_empty)

	_picker_name = UiStyle.make_label("", _fs(18))
	_picker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_picker_name)
	_picker_desc = UiStyle.make_label("", _fs(12), UiStyle.MUTED_COLOR)
	_picker_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picker_desc.custom_minimum_size = Vector2(PICK_PANEL_W, 0.0)
	_picker_desc.visible = false
	box.add_child(_picker_desc)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	UiStyle.style_button(cancel, Color(0.75, 0.30, 0.30))
	_big_button(cancel, Vector2(120.0, 48.0), _fs(13))
	cancel.pressed.connect(_close_picker)
	buttons.add_child(cancel)
	var random := Button.new()
	random.text = "Sortear"
	random.focus_mode = Control.FOCUS_NONE
	random.tooltip_text = "Escolhe um personagem aleatório entre os que aparecem na aba"
	UiStyle.style_button(random)
	_big_button(random, Vector2(120.0, 48.0), _fs(13))
	random.pressed.connect(_on_pick_random)
	buttons.add_child(random)
	var ok := Button.new()
	ok.text = "Confirmar"
	UiStyle.style_button(ok, Color(0.25, 0.65, 0.35))
	_big_button(ok, Vector2(200.0, 48.0), _fs(13))
	ok.pressed.connect(_on_picker_confirm)
	buttons.add_child(ok)


## Entradas do seletor: {id, name, face, full} (+ role nos personagens e description nos goleiros). Goleiro usa o KeeperRoster (rosto = face_for, imagem completa = art_for).
func _entries_for(keeper: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if keeper:
		for k in KeeperRoster.KEEPERS:
			var art: Texture2D = KeeperRoster.art_for(k["id"])
			out.append({"id": k["id"], "name": k["name"], "face": KeeperRoster.face_for(k["id"]), "full": art,
				"description": KeeperRoster.description_for(k["id"])})
	else:
		for c in CharacterRoster.available():
			out.append({"id": c["id"], "name": c["name"], "role": String(c.get("role", "")),
				"face": CharacterRoster.face_for(c["id"]), "full": CharacterRoster.full_for(c["id"])})
	return out


func _entry_by_id(id: String) -> Dictionary:
	for e in _picker_entries:
		if e["id"] == id:
			return e
	return {}


func _make_pick_card(entry: Dictionary) -> Button:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(PICK_CARD_W, float(PICK_FACE_SIZE) + 62.0)
	card.pressed.connect(_on_pick_card_pressed.bind(String(entry["id"])))
	card.gui_input.connect(_on_pick_card_input.bind(String(entry["id"])))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var face: Control = _make_face(entry["face"], String(entry["name"]), PICK_FACE_SIZE, Color(1, 1, 1, 0.25))
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(face)
	var label: Label = UiStyle.make_label(String(entry["name"]), _fs(10))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PICK_CARD_W - 14.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(label)
	# Aviso pequeno ("Já no time" / "No adversário"); preenchido em _refresh_pick_tags
	var tag: Label = UiStyle.make_label("", _fs(9), UiStyle.MUTED_COLOR)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tag)
	_pick_tags[String(entry["id"])] = tag
	return card


func _style_pick_card(card: Button, selected: bool) -> void:
	var team_color: Color = TeamStyle.color_of(_team)
	var bg: Color = CARD_HOVER if selected else CARD_BG
	var border: Color = team_color.lightened(0.25) if selected else Color(1, 1, 1, 0.12)
	var width: int = 4 if selected else 2
	card.add_theme_stylebox_override("normal", _card_style(bg, border, width))
	card.add_theme_stylebox_override("hover", _card_style(CARD_HOVER, team_color, 3))
	card.add_theme_stylebox_override("pressed", _card_style(CARD_HOVER, Color.WHITE, 3))
	card.add_theme_stylebox_override("focus", _card_style(bg, border, width))


func _refresh_pick_selection() -> void:
	for id: String in _pick_buttons:
		_style_pick_card(_pick_buttons[id] as Button, id == _picker_pending_id)
	var entry: Dictionary = _entry_by_id(_picker_pending_id)
	_picker_name.text = String(entry.get("name", ""))
	var desc: String = String(entry.get("description", ""))
	_picker_desc.text = desc
	_picker_desc.visible = desc != ""


## Duplo clique num personagem = escolhe e confirma na hora
func _on_pick_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_picker_pending_id = id
		_refresh_pick_selection()
		_on_picker_confirm()


## Escolhe um personagem aleatório entre os que aparecem na aba (e na busca)
func _on_pick_random() -> void:
	var options: Array[String] = []
	for entry in _picker_entries:
		var id: String = String(entry["id"])
		var candidate: Button = _pick_buttons.get(id) as Button
		if candidate != null and candidate.visible and id != _picker_pending_id:
			options.append(id)
	if options.is_empty():
		return
	_picker_pending_id = String(options.pick_random())
	_refresh_pick_selection()
	var chosen: Button = _pick_buttons.get(_picker_pending_id) as Button
	if chosen != null and _picker_scroll != null:
		_picker_scroll.ensure_control_visible(chosen)
	UiStyle.pop(_picker_name, 1.1, 0.15)


## Mostra só os cartões da aba aberta que combinam com a busca (goleiros: sempre todos)
func _apply_pick_filter() -> void:
	var query: String = _picker_search.text.strip_edges().to_lower()
	var shown: int = 0
	for entry in _picker_entries:
		var card: Button = _pick_buttons.get(String(entry["id"])) as Button
		if card == null:
			continue
		var in_tab: bool = _picker_is_keeper or _picker_tab == "" \
			or String(entry.get("role", "")) == _picker_tab
		var in_search: bool = query == "" or String(entry["name"]).to_lower().contains(query)
		card.visible = in_tab and in_search
		if card.visible:
			shown += 1
	_picker_empty.visible = shown == 0


func _tab_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = _card_style(bg, border, width)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	return sb


func _style_tab_button(b: Button, selected: bool) -> void:
	var team_color: Color = TeamStyle.color_of(_team)
	var bg: Color = team_color.darkened(0.45) if selected else CARD_BG
	var border: Color = team_color.lightened(0.25) if selected else Color(1, 1, 1, 0.12)
	var width: int = 3 if selected else 2
	b.add_theme_stylebox_override("normal", _tab_style(bg, border, width))
	b.add_theme_stylebox_override("hover", _tab_style(CARD_HOVER, team_color, 3))
	b.add_theme_stylebox_override("pressed", _tab_style(CARD_HOVER, Color.WHITE, 3))
	b.add_theme_stylebox_override("focus", _tab_style(bg, border, width))


func _add_pick_tab(role_id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 44.0)
	b.add_theme_font_size_override("font_size", _fs(12))
	b.pressed.connect(_set_pick_tab.bind(role_id))
	_picker_tab_box.add_child(b)
	_picker_tab_buttons[role_id] = b


## Abas: "Todos" + uma por categoria, com a quantidade de personagens de cada
func _rebuild_pick_tabs() -> void:
	for child in _picker_tab_box.get_children():
		_picker_tab_box.remove_child(child)
		child.queue_free()
	_picker_tab_buttons.clear()
	var counts: Dictionary = {}
	for e in _picker_entries:
		var r: String = String(e.get("role", ""))
		counts[r] = int(counts.get(r, 0)) + 1
	_add_pick_tab("", "Todos (%d)" % _picker_entries.size())
	for r in CharacterRoster.ROLES:
		_add_pick_tab(String(r["id"]), "%s (%d)" % [r["plural"], int(counts.get(r["id"], 0))])


func _set_pick_tab(role_id: String) -> void:
	_picker_tab = role_id
	for id: String in _picker_tab_buttons:
		_style_tab_button(_picker_tab_buttons[id] as Button, id == role_id)
	_apply_pick_filter()
	if _picker_scroll != null:
		_picker_scroll.scroll_vertical = 0


## Avisa nos cartões quem já está em campo: no próprio time (outra posição) ou no adversário.
## É só informação: dá para escolher o mesmo personagem de novo.
func _refresh_pick_tags(current: Node2D) -> void:
	var mine: Dictionary = {}
	var theirs: Dictionary = {}
	for t in manager.team_count:
		for p in manager.get_team_players(t):
			if p == current or p.character_id == "base":
				continue
			if t == _team:
				mine[p.character_id] = true
			else:
				theirs[p.character_id] = true
	if manager.bench != null:
		for t in manager.team_count:
			for rid in manager.bench.reserves_of(t):
				if rid == "" or rid == _picker_current_id:
					continue
				if t == _team:
					mine[rid] = true
				else:
					theirs[rid] = true
	for id: String in _pick_tags:
		var tag: Label = _pick_tags[id] as Label
		if mine.has(id):
			tag.text = "Já no time"
			tag.add_theme_color_override("font_color", UiStyle.ACCENT_COLOR)
		elif theirs.has(id):
			tag.text = "No adversário"
			tag.add_theme_color_override("font_color", UiStyle.MUTED_COLOR)
		else:
			tag.text = ""


func _on_pick_card_pressed(id: String) -> void:
	_picker_pending_id = id
	_refresh_pick_selection()
	if _pick_buttons.has(id):
		UiStyle.pop(_picker_name, 1.1, 0.15)


## Abre o seletor para a posição (índice na lista/mapa; a última é o goleiro).
## Índices DEPOIS da última posição são as vagas do banco de reservas (BenchManager.RESERVES).
func _open_picker(index: int) -> void:
	var is_bench: bool = manager.bench != null and index >= _slot_targets.size() \
		and index < _slot_targets.size() + BenchManager.RESERVES
	if (_modal_open and not _picker.visible) or index < 0 or (index >= _slot_targets.size() and not is_bench):
		return
	var target: Node2D = null if is_bench else _slot_targets[index]
	if not is_bench and not is_instance_valid(target):
		return
	_finish_move()
	_dragging = null

	_picker_index = index
	_picker_is_keeper = target is Goalkeeper
	_picker_entries = _entries_for(_picker_is_keeper)
	if is_bench:
		_picker_current_id = manager.bench.reserve_id(_team, index - _slot_targets.size())
	else:
		_picker_current_id = (target as Goalkeeper).keeper_id if _picker_is_keeper \
			else (target as Player).character_id
	_picker_pending_id = _picker_current_id
	if is_bench:
		_picker_title.text = "Reserva %d — escolha o personagem" % (index - _slot_targets.size() + 1)
	else:
		_picker_title.text = ("Goleiro" if _picker_is_keeper else "Posição %d" % (index + 1)) \
			+ " — escolha o personagem"

	for child in _picker_grid.get_children():
		_picker_grid.remove_child(child)
		child.queue_free()
	_pick_buttons.clear()
	_pick_tags.clear()
	for entry in _picker_entries:
		var card: Button = _make_pick_card(entry)
		_picker_grid.add_child(card)
		_pick_buttons[String(entry["id"])] = card
	_refresh_pick_selection()

	# Abas e busca (goleiros não têm categorias). Abre na categoria que combina com a posição.
	_picker_recommended = "" if (_picker_is_keeper or is_bench) else _recommended_role(target)
	_picker_tab_box.visible = not _picker_is_keeper
	_picker_search.visible = not _picker_is_keeper
	_picker_role_hint.visible = not _picker_is_keeper
	_picker_search.text = ""
	if not _picker_is_keeper:
		_refresh_pick_tags(target)
		_rebuild_pick_tabs()
		if is_bench:
			_picker_role_hint.text = "Reserva: entra no lugar de um jogador em campo, numa substituição durante a partida."
		else:
			_picker_role_hint.text = "Sugestão para esta posição: %s. Você pode escolher qualquer personagem (veja a aba Todos)." \
				% String(CharacterRoster.role_info(_picker_recommended).get("plural", ""))
	_set_pick_tab(_picker_recommended)

	_picker.visible = true
	_modal_open = true
	_left_col.visible = false      # o menu de personagens ocupa o lugar dos cartões
	_pitch.selected = target       # a bolinha escolhida fica em destaque no campo
	_pitch.kick(0.8)
	UiStyle.pop(_picker_title, 1.08, 0.2)
	_jelly_next_frame(_picker_panel, 1.07)


func _close_picker() -> void:
	_picker.visible = false
	_modal_open = false
	_left_col.visible = true
	_pitch.selected = null
	_jelly_next_frame(_left_col, 1.03)


## Gelatina no próximo quadro (o tamanho do controle só é conhecido depois do layout)
func _jelly_next_frame(control: Control, strength: float) -> void:
	await get_tree().process_frame
	if is_instance_valid(control):
		control.pivot_offset = control.size * 0.5
		UiStyle.jelly(control, strength, 0.6)


func _on_picker_confirm() -> void:
	var entry: Dictionary = _entry_by_id(_picker_pending_id)
	if entry.is_empty():
		return
	var id: String = _picker_pending_id
	var is_bench: bool = _picker_index >= _slot_targets.size()
	var target: Node2D = _slot_targets[_picker_index] if _picker_index < _slot_targets.size() else null
	_close_picker()

	if is_bench:
		if manager.bench != null and id != _picker_current_id:
			manager.bench.set_reserve(_team, _picker_index - _slot_targets.size(), id)
			_rebuild_positions.call_deferred()   # os cartões do banco mostram o reserva novo
	elif is_instance_valid(target) and id != _picker_current_id:
		if _picker_is_keeper:
			KeeperRoster.replace_keeper(target as Goalkeeper, id)
			_rebuild_positions.call_deferred()   # a lista passa a apontar para o goleiro novo
		else:
			_apply_character(target as Player, id)
	_show_reveal(entry)


# ---------- REVELAÇÃO: IMAGEM COMPLETA + FLASH DE TELA ----------

func _build_reveal() -> void:
	_reveal = Control.new()
	_reveal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal.visible = false
	add_child(_reveal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_reveal_input)
	_reveal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(center)

	_reveal_box = VBoxContainer.new()
	_reveal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_box.add_theme_constant_override("separation", 6)
	_reveal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_reveal_box)

	_reveal_image = TextureRect.new()
	_reveal_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reveal_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reveal_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_box.add_child(_reveal_image)

	_reveal_placeholder = UiStyle.make_label("", 180, UiStyle.MUTED_COLOR)
	_reveal_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_box.add_child(_reveal_placeholder)

	_reveal_name = UiStyle.make_label("", 48)
	_reveal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_box.add_child(_reveal_name)

	# Flash branco por cima de tudo (a "telinha piscando")
	_reveal_band = ColorRect.new()
	_reveal_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(_reveal_band)
	_reveal.move_child(_reveal_band, 1)   # entre o escurecimento e a imagem

	_reveal_badge = TeamBadge.make(0, 64.0)
	_reveal_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_reveal_badge.position = Vector2(28.0, 24.0)
	_reveal.add_child(_reveal_badge)

	_reveal_flash = ColorRect.new()
	_reveal_flash.color = Color.WHITE
	_reveal_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_flash.modulate.a = 0.0
	_reveal.add_child(_reveal_flash)


func _on_reveal_input(event: InputEvent) -> void:
	# Clicar fecha (depois de um instante, para o clique da confirmação não fechar na hora)
	if event is InputEventMouseButton and event.pressed \
			and Time.get_ticks_msec() - _reveal_start_msec > 450:
		_hide_reveal()


func _show_reveal(entry: Dictionary) -> void:
	_reveal_token += 1
	var token: int = _reveal_token
	_reveal_start_msec = Time.get_ticks_msec()
	_modal_open = true
	_reveal.visible = true

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var tex: Texture2D = entry["full"]
	var accent: Color = TeamStyle.color_of(_team)
	if tex != null:
		var h: float = screen.y * 0.68
		var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		_reveal_image.texture = tex
		_reveal_image.custom_minimum_size = Vector2(minf(h * aspect, screen.x * 0.7), h)
		_reveal_image.visible = true
		_reveal_placeholder.visible = false
	else:
		_reveal_image.visible = false
		_reveal_placeholder.text = String(entry["name"]).substr(0, 1).to_upper()
		_reveal_placeholder.visible = true
	_reveal_name.text = String(entry["name"])
	_reveal_name.add_theme_color_override("font_color", accent.lightened(0.35))
	_reveal_badge.team = _team

	# Faixa inclinada na cor do time (atravessa a tela atrás do personagem)
	_reveal_band.color = Color(accent, 0.38)
	_reveal_band.size = Vector2(screen.x * 1.6, screen.y * 0.3)
	_reveal_band.pivot_offset = _reveal_band.size * 0.5
	_reveal_band.position = screen * 0.5 - _reveal_band.size * 0.5
	_reveal_band.rotation = deg_to_rad(-9.0)
	_reveal_band.scale = Vector2(0.0, 1.0)
	create_tween().tween_property(_reveal_band, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Flash de tela: pisca duas vezes
	_reveal_flash.modulate.a = 0.0
	var flash := create_tween()
	flash.tween_property(_reveal_flash, "modulate:a", 0.9, 0.05)
	flash.tween_property(_reveal_flash, "modulate:a", 0.0, 0.09)
	flash.tween_property(_reveal_flash, "modulate:a", 0.65, 0.05)
	flash.tween_property(_reveal_flash, "modulate:a", 0.0, 0.28)

	# A imagem entra com um "estouro" (começa maior e transparente)
	_reveal_box.modulate.a = 0.0
	_reveal_box.scale = Vector2(1.3, 1.3)
	await get_tree().process_frame
	if token != _reveal_token:
		return
	_reveal_box.pivot_offset = _reveal_box.size * 0.5
	var pop := create_tween().set_parallel(true)
	pop.tween_property(_reveal_box, "modulate:a", 1.0, 0.18)
	pop.tween_property(_reveal_box, "scale", Vector2.ONE, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(1.8).timeout
	if token == _reveal_token:
		_hide_reveal()


func _hide_reveal() -> void:
	if not _reveal.visible:
		return
	_reveal_token += 1   # cancela o fechamento automático pendente
	var token: int = _reveal_token
	var fade := create_tween()
	fade.tween_property(_reveal_box, "modulate:a", 0.0, 0.18)
	await fade.finished
	if token == _reveal_token:
		_reveal.visible = false
		_modal_open = false


# ---------- COR PERSONALIZADA / ALEATÓRIA ----------

## Por que esta cor não pode ser usada agora ("" = pode)? Parecida demais com a de um time que
## já confirmou a formação (os dois se confundiriam em campo).
func _color_conflict(color: Color) -> String:
	for t in manager.team_count:
		if t != _team and _confirmed[t] and TeamStyle.similar(color, TeamStyle.color_of(t), 0.25):
			return "Parecida demais com a cor do outro time"
	return ""


## Cor escolhida no seletor livre. Atualiza ao vivo enquanto o jogador arrasta no seletor.
func _on_custom_color(color: Color) -> void:
	if _updating_picker:
		return
	var conflict: String = _color_conflict(color)
	if conflict != "":
		_set_color_hint(conflict, UiStyle.BAD_COLOR)
		return
	if TeamStyle.is_grassy(color):
		_set_color_hint("Cor parecida com o gramado: o time pode sumir no campo", UiStyle.ACCENT_COLOR)
	else:
		_set_color_hint("", UiStyle.MUTED_COLOR)
	_apply_color(color, false)


func _on_random_color() -> void:
	for i in 12:
		var color: Color = TeamStyle.random_color()
		if _color_conflict(color) == "":
			_set_color_hint("", UiStyle.MUTED_COLOR)
			_apply_color(color, true)
			return


func _set_color_hint(text: String, color: Color) -> void:
	_color_hint.text = text
	_color_hint.add_theme_color_override("font_color", color)


## Mantém o seletor livre mostrando a cor do time (sem disparar o color_changed dele)
func _sync_custom_picker() -> void:
	if _custom_picker == null:
		return
	_updating_picker = true
	_custom_picker.color = TeamStyle.color_of(_team)
	_updating_picker = false


# ---------- ÍCONE DO TIME ----------

func _build_icon_picker() -> void:
	_icon_picker = Control.new()
	_icon_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_picker.visible = false
	add_child(_icon_picker)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_icon_picker())
	_icon_picker.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_picker.add_child(center)

	var panel := PanelContainer.new()
	_big_panel(panel)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	_icon_title = UiStyle.make_label("Ícone do time", _fs(22))
	box.add_child(_icon_title)
	_icon_hint = UiStyle.make_label("", _fs(11), UiStyle.MUTED_COLOR)
	box.add_child(_icon_hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(float(ICON_COLUMNS) * 134.0, 380.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_icon_grid = GridContainer.new()
	_icon_grid.columns = ICON_COLUMNS
	_icon_grid.add_theme_constant_override("h_separation", 10)
	_icon_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_icon_grid)

	var close := Button.new()
	close.text = "Fechar"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(close, Color(0.75, 0.30, 0.30))
	_big_button(close, Vector2(200.0, 54.0), _fs(15))
	close.pressed.connect(_close_icon_picker)
	box.add_child(close)


## Um cartão de ícone: o selo do time (cor + ícone) e o nome. id "" = emblema padrão.
func _make_icon_card(id: String, label: String) -> Button:
	var selected: bool = id == TeamStyle.icon_id_of(_team)
	var team_color: Color = TeamStyle.color_of(_team)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(122.0, 142.0)
	card.add_theme_stylebox_override("normal",
		_card_style(CARD_HOVER if selected else CARD_BG, team_color.lightened(0.25) if selected else Color(1, 1, 1, 0.12), 4 if selected else 2))
	card.add_theme_stylebox_override("hover", _card_style(CARD_HOVER, team_color, 3))
	card.add_theme_stylebox_override("pressed", _card_style(CARD_HOVER, Color.WHITE, 3))
	card.add_theme_stylebox_override("focus", _card_style(CARD_HOVER, Color.WHITE, 3))
	card.pressed.connect(_on_icon_chosen.bind(id))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# Pré-visualização: o selo de verdade, com este ícone no time atual
	var preview := _IconPreview.new()
	preview.team = _team
	preview.icon_id = id
	preview.custom_minimum_size = Vector2(80.0, 80.0)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(preview)
	var name_label: Label = UiStyle.make_label(label, _fs(10))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	return card


func _open_icon_picker() -> void:
	if _icon_picker.visible:
		return
	_finish_move()
	_dragging = null
	for child in _icon_grid.get_children():
		_icon_grid.remove_child(child)
		child.queue_free()

	_icon_grid.add_child(_make_icon_card("", "Emblema padrão"))
	var icons: Array[Dictionary] = TeamStyle.available_icons(true)
	for entry in icons:
		_icon_grid.add_child(_make_icon_card(String(entry["id"]), String(entry["name"])))
	if icons.is_empty():
		_icon_hint.text = "Nenhum ícone encontrado. Coloque as imagens em %s" % TeamStyle.ICON_DIR
	else:
		_icon_hint.text = "Clique num ícone para escolher (Esc fecha)"

	_icon_picker.visible = true
	_modal_open = true
	UiStyle.pop(_icon_title, 1.08, 0.2)


func _close_icon_picker() -> void:
	_icon_picker.visible = false
	_modal_open = _team_modal.visible   # volta para a janela de personalizar, se ela estiver aberta


func _on_icon_chosen(id: String) -> void:
	TeamStyle.set_icon(_team, id)
	_overlay.icon = TeamStyle.icon_of(_team)
	_overlay.queue_redraw()
	_close_icon_picker()
	UiStyle.pop(_icon_badge, 1.5, 0.35)
	UiStyle.pop(_banner_badge, 1.4, 0.3)
	if _icon_name_label != null:
		_icon_name_label.text = _icon_display_name()


func _icon_display_name() -> String:
	var id: String = TeamStyle.icon_id_of(_team)
	if id == "":
		return "Emblema padrão"
	for entry in TeamStyle.available_icons():
		if entry["id"] == id:
			return String(entry["name"])
	return id


## Mostra o selo de um ícone específico (ou o emblema padrão) com a cor do time
class _IconPreview extends Control:
	var team: int = 0
	var icon_id: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var color: Color = TeamStyle.color_of(team)
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		draw_circle(center, radius, color.darkened(0.6))
		draw_circle(center, radius * 0.92, color.darkened(0.35))
		var tex: Texture2D = TeamStyle.icon_by_id(icon_id)
		if tex != null:
			var box: float = radius * 1.46
			var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
			var s: Vector2 = Vector2(box, box / aspect) if aspect >= 1.0 else Vector2(box * aspect, box)
			draw_texture_rect(tex, Rect2(center - s * 0.5, s), false)
		else:
			# emblema padrão: escudo simples
			var w: float = radius * 0.62
			var top: float = -radius * 0.62
			var bottom: float = radius * 0.7
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-w, top), center + Vector2(w, top),
				center + Vector2(w, top + (bottom - top) * 0.5), center + Vector2(0.0, bottom),
				center + Vector2(-w, top + (bottom - top) * 0.5)]), color)
		draw_arc(center, radius - 1.5, 0.0, TAU, 40, color, maxf(2.0, radius * 0.1))


# ---------- FLUXO ENTRE OS TIMES ----------

func _begin_team(team: int) -> void:
	_team = team
	_dragging = null
	_hover = null
	_targets.clear()

	_snapshot.clear()
	var players: Array[Player] = manager.get_team_players(team)
	for p in players:
		_snapshot[p] = p.global_position

	var color: Color = TeamStyle.color_of(team)
	_overlay.rect = Formations.team_area(team, _field)
	_overlay.color = color
	_overlay.slots.clear()
	_overlay.players = players
	_overlay.hover = null
	_overlay.dragging = null
	_overlay.queue_redraw()

	_overlay.icon = TeamStyle.icon_of(team)
	for badge in [_icon_badge, _card_badge, _banner_badge]:
		badge.team = team
		badge.fallback_name = manager.get_default_team_name(team)
	_icon_name_label.text = _icon_display_name()
	_set_color_hint("", UiStyle.MUTED_COLOR)
	_title.text = "Formação — %s" % manager.get_team_name(team)
	_name_edit.placeholder_text = manager.get_default_team_name(team)
	_name_edit.text = manager.get_team_name(team) if TeamStyle.has_custom_name(team) else ""
	_name_edit.release_focus()
	_rebuild_swatches()
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(_title_style, "border_color", color, 0.25)
	UiStyle.pop(_title, 1.12, 0.25)

	_confirm_button.text = "Confirmar e começar a partida" if _next_team_after(team) == -1 \
		else "Confirmar formação"
	_rebuild_presets()
	_preview_active = false
	_formation_name = String(_formation_by_team.get(team, ""))   # voltando a um time: a formação que ele tinha
	_update_formation_label()
	_update_back_button()
	_keeper_retried = false
	_rebuild_positions()
	_ensure_on_pitch()
	_spin_to_team(team, _spun_once)
	_spun_once = true


## Yaw do campo em perspectiva para o time da vez ficar na frente (0 = metade da esquerda perto)
func _team_yaw(team: int) -> float:
	return 0.0 if _field.defend_dir(team) < 0 else PI


## O campo dá meia-volta (com um balanço de gelatina no fim) e o time da vez passa a ficar na frente
func _spin_to_team(team: int, animate: bool) -> void:
	var target: float = _team_yaw(team)
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_pitch.spinning = false
	var diff: float = fposmod(target - _pitch.yaw, TAU)
	if not animate or diff < 0.01 or diff > TAU - 0.01:
		_pitch.yaw = target
		return
	_pitch.spinning = true
	_pitch.kick(1.6)
	_spin_tween = create_tween()
	_spin_tween.tween_property(_pitch, "yaw", _pitch.yaw + diff, 1.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spin_tween.tween_callback(func() -> void:
		_pitch.spinning = false
		_pitch.kick(1.2))


## Personagens ainda fora do campo (antes de qualquer formação) ficariam empilhados na borda do
## mapa: nesse caso entra a primeira formação pronta, e "Restaurar" volta a ela.
func _ensure_on_pitch() -> void:
	var half: Vector2 = _field.pitch_size * 0.5
	var outside: bool = false
	for p in manager.get_team_players(_team):
		var l: Vector2 = _field.to_local(p.global_position)
		if absf(l.x) > half.x or absf(l.y) > half.y:
			outside = true
	if not outside:
		return
	var presets: Array = Formations.presets_for(manager.get_team_players(_team).size())
	if presets.is_empty():
		return
	_apply_preset(String(presets[0]))
	for key in _targets:
		_snapshot[key] = _targets[key]


## Próximo time que ainda não confirmou (-1 = ninguém, ou seja, este é o último)
func _next_team_after(team: int) -> int:
	for t in _confirmed.size():
		if t != team and not _confirmed[t]:
			return t
	return -1


## Botão "Voltar": reabre o último time que confirmou para mexer de novo. O que o time que está
## sendo editado agora já fez (posições, nome, cor, personagens) fica guardado.
func _on_back_pressed() -> void:
	if _history.is_empty() or _modal_open:
		return
	_finish_move()
	_dragging = null
	_end_preview_preset()
	_formation_by_team[_team] = _formation_name
	var previous: int = _history.pop_back()
	_confirmed[previous] = false
	_begin_team(previous)


func _update_back_button() -> void:
	if _back_button == null:
		return
	_back_button.visible = not _history.is_empty()
	if not _history.is_empty():
		_back_button.text = "Voltar e editar %s" % manager.get_team_name(int(_history.back()))


func _on_confirm_pressed() -> void:
	_finish_move()
	_dragging = null
	_end_preview_preset()
	_confirmed[_team] = true
	_formation_by_team[_team] = _formation_name
	_history.append(_team)
	var next: int = _next_team_after(_team)
	if next == -1:
		finished.emit()
		queue_free()
	else:
		_begin_team(next)


# ---------- FORMAÇÕES PRONTAS ----------

func _apply_preset(formation: String) -> void:
	_finish_move()
	_preview_active = false   # o clique vale mais que a pré-visualização (que some ao tirar o mouse)
	var players: Array[Player] = manager.get_team_players(_team)
	var slot_positions: Array[Vector2] = Formations.slots(formation, _team, _field)
	_targets = Formations.assign(players, slot_positions)
	_formation_name = formation
	_update_formation_label()

	_overlay.slots.clear()
	for s in slot_positions:
		_overlay.slots.append(_field.to_local(s))
	_start_move()


## Mouse em cima do botão de uma formação: mostra os espaços dela no campo, sem aplicar
func _preview_preset(formation: String) -> void:
	if _modal_open or _dragging != null:
		return
	if not _preview_active:
		_slots_before_preview.clear()
		for v in _overlay.slots:
			_slots_before_preview.append(v)
	_preview_active = true
	_overlay.slots.clear()
	for pos in Formations.slots(formation, _team, _field):
		_overlay.slots.append(_field.to_local(pos))
	_overlay.queue_redraw()


## Tirou o mouse do botão: os espaços voltam ao que estavam
func _end_preview_preset() -> void:
	if not _preview_active:
		return
	_preview_active = false
	_overlay.slots.clear()
	for v in _slots_before_preview:
		_overlay.slots.append(v)
	_overlay.queue_redraw()


func _restore() -> void:
	_finish_move()
	_targets = _snapshot.duplicate()
	_formation_name = ""
	_update_formation_label()
	_overlay.slots.clear()
	_start_move()


func _start_move() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween().set_parallel(true)
	for key in _targets:
		var p: Player = key
		_move_tween.tween_property(p, "global_position", _targets[key], 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(func() -> void: _targets.clear(), CONNECT_ONE_SHOT)


## Se uma formação ainda está deslizando, termina na hora (evita brigar com o arrastar/confirmar)
func _finish_move() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	for key in _targets:
		var p: Player = key
		p.global_position = _targets[key]
	_targets.clear()


# ---------- ARRASTAR (o campo em perspectiva manda; o jogador de verdade acompanha) ----------

func _on_dot_double_clicked(node: Node2D) -> void:
	var idx: int = _slot_targets.find(node)
	if idx < 0:
		return
	if _picker.visible:
		_close_picker()
	_open_picker(idx)


func _on_dot_drag_started(_node: Node2D) -> void:
	_finish_move()
	_formation_name = ""   # mexeu na mão: deixa de ser uma formação pronta
	_update_formation_label()
	_overlay.slots.clear()   # o guia some quando você começa a mexer na mão
	_pitch.kick(0.5)


func _on_dot_dragged(node: Node2D, field_norm: Vector2) -> void:
	if not (node is Player) or not is_instance_valid(node):
		return
	var half: Vector2 = _field.pitch_size * 0.5
	var world: Vector2 = _field.to_global(Vector2(field_norm.x * half.x, field_norm.y * half.y))
	node.global_position = _constrain(world, node as Player)


func _on_dot_drag_ended(_node: Node2D) -> void:
	_pitch.kick(0.8)


func _unhandled_input(event: InputEvent) -> void:
	if _team < 0:
		return
	# Esc fecha o seletor de personagem
	if _picker != null and _picker.visible and event.is_action_pressed("ui_cancel"):
		_close_picker()
		get_viewport().set_input_as_handled()
		return
	# Enter confirma o personagem escolhido (digitando na busca, o Enter fica com o campo de texto)
	if _picker != null and _picker.visible and event.is_action_pressed("ui_accept"):
		_on_picker_confirm()
		get_viewport().set_input_as_handled()
		return
	if _icon_picker != null and _icon_picker.visible and event.is_action_pressed("ui_cancel"):
		_close_icon_picker()
		get_viewport().set_input_as_handled()
		return
	if _team_modal != null and _team_modal.visible and event.is_action_pressed("ui_cancel"):
		_close_team_modal()
		get_viewport().set_input_as_handled()
		return


func _process(_delta: float) -> void:
	if _field == null or _team < 0 or _pitch == null:
		return
	# Com o seletor aberto o campo continua mexível; com as outras janelas, não
	_pitch.locked = _modal_open and not _picker.visible


## Mantém o jogador dentro da metade do time e fora de cima de outros jogadores e goleiros
func _constrain(target_global: Vector2, who: Player) -> Vector2:
	var pos: Vector2 = _clamp_to_area(target_global)
	for i in 3:
		for other: Player in get_tree().get_nodes_in_group("players"):
			if other != who:
				pos = _push_away(pos, who.body_radius, other.global_position, other.body_radius)
		for keeper: Goalkeeper in get_tree().get_nodes_in_group("goalkeepers"):
			pos = _push_away(pos, who.body_radius, keeper.global_position, keeper.body_radius)
		pos = _clamp_to_area(pos)
	return pos


func _clamp_to_area(global_pos: Vector2) -> Vector2:
	var area: Rect2 = Formations.team_area(_team, _field)
	var local: Vector2 = _field.to_local(global_pos)
	local.x = clampf(local.x, area.position.x, area.end.x)
	local.y = clampf(local.y, area.position.y, area.end.y)
	return _field.to_global(local)


func _push_away(pos: Vector2, radius: float, other_pos: Vector2, other_radius: float) -> Vector2:
	var need: float = radius + other_radius + 6.0
	var away: Vector2 = pos - other_pos
	if away.length() >= need:
		return pos
	if away.length() < 0.01:
		away = Vector2.RIGHT
	return other_pos + away.normalized() * need
