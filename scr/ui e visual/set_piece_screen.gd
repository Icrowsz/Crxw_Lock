class_name SetPieceScreen
extends CanvasLayer
## Telas da falta / pênalti (criada pelo FoulManager):
##   1) show_whistle(): aviso grande "FALTA!" / "PÊNALTI!" com quem cobra.
##   2) run_setup(): preparação. O COBRADOR se escolhe numa lista (rostinho + nome) no canto de baixo à direita; ele vai até a bola.
##      Arraste qualquer jogador com o mouse para reposicioná-lo (no pênalti a grande área é proibida e fica marcada
##      em vermelho). Cada time confirma no próprio botão; a cobrança só começa quando os DOIS confirmam.
##      Mexer num jogador de um time desfaz a confirmação desse time.
##
## Também tem SetPieceScreen.toast(host, texto, cor): aviso rápido no pé da tela.

signal finished

const PICK_RADIUS: float = 40.0    # distância (px do campo) para pegar um jogador com o mouse
const DRAG_THRESHOLD: float = 7.0  # menos que isto = foi um clique (escolhe cobrador), mais = arrasto

var foul: FoulManager
var manager: MatchManager

var _ready_teams: Dictionary = {}   # time -> true se já confirmou
var _hover: Player = null
var _drag: Player = null
var _drag_offset: Vector2 = Vector2.ZERO
var _press_pos: Vector2 = Vector2.ZERO
var _moved: bool = false
var _done: bool = false

var _banner: Control
var _setup_root: Control
var _overlay: _Overlay
var _hint: Label
var _status: Label
var _buttons: Dictionary = {}   # time -> Button
var _taker_panel: PanelContainer
var _taker_buttons: Dictionary = {}   # Player -> Button (lista de cobradores)
var _hidden_menu: Array = []          # painel de habilidades escondido durante a preparação
var _menu_scan: float = 0.0


## Distância (px) do pé da tela até os botões de confirmar: precisa passar da altura da caixa das ações gerais
var confirm_bottom_offset: float = 118.0


func _ready() -> void:
	layer = 8   # abaixo da telinha do chute (9) e das telas grandes
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------- 1) O APITO ----------

func show_whistle() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var penalty: bool = foul.kind == FoulManager.KIND_PENALTY
	var color: Color = TeamStyle.color_of(foul.fouled_team)
	var big: Label = UiStyle.make_label("PÊNALTI!" if penalty else "FALTA!", 110, UiStyle.ACCENT_COLOR)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	var sub: Label = UiStyle.make_label("%s cobra" % manager.get_team_name(foul.fouled_team), 40, color.lightened(0.3))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	big.pivot_offset = Vector2(300.0, 60.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.35, 0.25)
	await get_tree().process_frame   # o tamanho do texto só existe depois do layout
	big.pivot_offset = big.size * 0.5
	UiStyle.pop(big, 1.6, 0.35)
	await get_tree().create_timer(foul.banner_time, true, false, true).timeout

	var out := create_tween().set_parallel(true)
	out.tween_property(_banner, "modulate:a", 0.0, 0.3)
	await out.finished
	_banner.queue_free()
	_banner = null


# ---------- 2) PREPARAÇÃO ----------

func run_setup() -> void:
	_build_setup()
	await finished
	queue_free()


func _build_setup() -> void:
	_setup_root = Control.new()
	_setup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_setup_root)

	_overlay = _Overlay.new()
	_overlay.screen = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_root.add_child(_overlay)

	var penalty: bool = foul.kind == FoulManager.KIND_PENALTY
	var fouled_color: Color = TeamStyle.color_of(foul.fouled_team)

	# Em cima: o que é e o que fazer
	var top := PanelContainer.new()
	UiStyle.style_panel(top, Color(fouled_color, 0.7))
	# Notificação rápida no canto de cima à esquerda (não cobre o placar nem o campo)
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.offset_left = 14.0
	top.offset_top = 14.0
	top.custom_minimum_size = Vector2(380.0, 0.0)
	_setup_root.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	top.add_child(tv)
	var title: Label = UiStyle.make_label("%s para %s" % ["PÊNALTI" if penalty else "FALTA", manager.get_team_name(foul.fouled_team)],
		30, UiStyle.ACCENT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(title)
	var how: String = "Escolha o cobrador na lista (embaixo à direita)\nArraste os jogadores para reposicionar"
	if penalty:
		how += "\nNinguém pode ficar na grande área"
	how += "\nNinguém dentro do gol · %s fica a %d px+ do cobrador" % [manager.get_team_name(foul.fouling_team),
		int(foul.opponent_min_distance)]
	_hint = UiStyle.make_label(how, 16, UiStyle.MUTED_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(_hint)

	# Embaixo: um botão de confirmar por time
	var bottom := PanelContainer.new()
	UiStyle.style_panel(bottom)
	# Canto de baixo à esquerda, logo ACIMA da caixa das ações gerais
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.grow_horizontal = Control.GROW_DIRECTION_END
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 12.0
	bottom.offset_bottom = -confirm_bottom_offset
	_setup_root.add_child(bottom)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bottom.add_child(bv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_child(row)
	for t in manager.team_count:
		var b := Button.new()
		b.custom_minimum_size = Vector2(230.0, 50.0)
		UiStyle.style_button(b, TeamStyle.color_of(t))
		b.pressed.connect(_on_confirm_pressed.bind(t))
		row.add_child(b)
		_buttons[t] = b
	_status = UiStyle.make_label("", 17, UiStyle.MUTED_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_status)
	_build_taker_list()
	_refresh_buttons()
	UiStyle.pop(top, 1.15, 0.3)
	UiStyle.pop(bottom, 1.15, 0.3)


## Lista de personagens do time que sofreu a falta (com rostinho), no lugar do menu de habilidades
func _build_taker_list() -> void:
	var panel := PanelContainer.new()
	UiStyle.style_panel(panel, Color(TeamStyle.color_of(foul.fouled_team), 0.7))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -12.0
	panel.offset_bottom = -12.0
	panel.custom_minimum_size = Vector2(272.0, 0.0)
	_setup_root.add_child(panel)
	_taker_panel = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var head: Label = UiStyle.make_label("Cobrador", 18, UiStyle.ACCENT_COLOR)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var team_players: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == foul.fouled_team:
			team_players.append(p)
	for p in team_players:
		var b := Button.new()
		b.text = " " + p.get_display_name()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = p.get_face_image()
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0.0, 46.0)
		b.add_theme_constant_override("icon_max_width", 40)
		UiStyle.style_button(b, TeamStyle.color_of(p.team))
		b.pressed.connect(_on_taker_picked.bind(p))
		v.add_child(b)
		_taker_buttons[p] = b
	_refresh_taker_list()


func _on_taker_picked(p: Player) -> void:
	if _done or p == foul.taker:
		return
	if foul.set_taker(p):
		_ready_teams.erase(foul.fouled_team)
		_refresh_buttons()
	else:
		toast(self, "%s não pode cobrar (proibido de ser Protagonista)" % p.get_display_name(), UiStyle.BAD_COLOR, 1.8)
	_refresh_taker_list()


func _refresh_taker_list() -> void:
	for p in _taker_buttons:
		var b: Button = _taker_buttons[p]
		if not is_instance_valid(p) or not is_instance_valid(b):
			continue
		var chosen: bool = p == foul.taker
		b.text = " %s%s" % [p.get_display_name(), "   ★ cobra" if chosen else ""]
		b.modulate = Color(1.0, 0.92, 0.45) if chosen else Color.WHITE
		b.disabled = manager.is_protagonist_blocked(p)


## O menu de habilidades do jogo (painel "Habilidades") some enquanto a lista de cobradores está na tela.
## Procura pelo título "Habilidades" e esconde o painel dele; volta a aparecer quando a preparação acaba.
func _hide_skill_menu() -> void:
	for item in _hidden_menu:
		if is_instance_valid(item) and item.visible:
			item.visible = false
	if not _hidden_menu.is_empty() and _menu_scan > 0.0:
		return
	_menu_scan = 0.5
	var found: Array[Node] = []
	_find_skill_titles(get_tree().root, found)
	for label in found:
		var top: Node = label
		while top.get_parent() != null and not (top.get_parent() is CanvasLayer) and top.get_parent() != get_tree().root:
			top = top.get_parent()
		if top is Control and top.visible and not _hidden_menu.has(top):
			(top as Control).visible = false
			_hidden_menu.append(top)


func _find_skill_titles(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child is Label and (child as Label).text.strip_edges().to_lower() == "habilidades" \
				and (child as Label).is_visible_in_tree():
			out.append(child)
		_find_skill_titles(child, out)


func _restore_skill_menu() -> void:
	for item in _hidden_menu:
		if is_instance_valid(item):
			item.visible = true
	_hidden_menu.clear()


func _refresh_buttons() -> void:
	var waiting: Array[String] = []
	for t in _buttons:
		var b: Button = _buttons[t]
		var ok: bool = bool(_ready_teams.get(t, false))
		b.text = ("✔ %s pronto" if ok else "Confirmar %s") % manager.get_team_name(t)
		b.disabled = t == foul.fouled_team and foul.taker == null
		if not ok:
			waiting.append(manager.get_team_name(t))
	if waiting.is_empty():
		_status.text = "Tudo pronto!"
	else:
		_status.text = "Esperando: %s" % ", ".join(waiting)


func _on_confirm_pressed(team: int) -> void:
	if _done:
		return
	_ready_teams[team] = not bool(_ready_teams.get(team, false))
	_refresh_buttons()
	if _ready_teams.size() >= manager.team_count and _ready_teams.values().all(func(v): return v):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_restore_skill_menu()
	_drag = null
	await get_tree().create_timer(0.35, true, false, true).timeout
	finished.emit()


func _process(_delta: float) -> void:
	if _done or _setup_root == null:
		return
	if manager.match_over:
		_finish()
		return
	if _drag == null:
		_hover = _player_under_mouse()
	_menu_scan -= _delta
	_hide_skill_menu()
	_overlay.queue_redraw()


# ---------- MOUSE: ESCOLHER COBRADOR / ARRASTAR ----------

func _mouse_world() -> Vector2:
	return foul.field.get_global_mouse_position()


func _player_under_mouse() -> Player:
	var m: Vector2 = _mouse_world()
	var best: Player = null
	var best_d: float = PICK_RADIUS
	for p: Player in get_tree().get_nodes_in_group("players"):
		var d: float = (p.global_position + Vector2(0.0, -18.0)).distance_to(m)
		if d < best_d:
			best_d = d
			best = p
	return best


func _unhandled_input(event: InputEvent) -> void:
	if _done or _setup_root == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Player = _player_under_mouse()
			if p == null:
				return
			_drag = p
			_hover = p
			_moved = false
			_press_pos = event.position
			_drag_offset = p.global_position - _mouse_world()
			get_viewport().set_input_as_handled()
		elif _drag != null:
			_release_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag != null:
		if not _moved and (event.position - _press_pos).length() > DRAG_THRESHOLD:
			_moved = true
		if _moved and _drag != foul.taker:
			foul.stop_motion(_drag)
			_drag.global_position = foul.constrain_position(_drag, _mouse_world() + _drag_offset)
			_ready_teams[_drag.team] = false
			_refresh_buttons()
		get_viewport().set_input_as_handled()


func _release_drag() -> void:
	var p: Player = _drag
	_drag = null
	if _moved or p == null:
		return
	# Foi só um clique no campo: o cobrador agora se escolhe na lista (embaixo à direita)


# ---------- DESENHO POR CIMA DO CAMPO ----------

class _Overlay extends Control:
	var screen: SetPieceScreen

	func _draw() -> void:
		if screen == null or screen.foul == null or screen.foul.field == null:
			return
		var foul: FoulManager = screen.foul
		var xf: Transform2D = get_viewport().get_canvas_transform()
		var zoom: float = xf.get_scale().x
		var font: Font = ThemeDB.fallback_font

		# Pênalti: a grande área proibida
		if foul.kind == FoulManager.KIND_PENALTY:
			var rect: Rect2 = foul.field.get_penalty_area_rect(foul.fouling_team)
			var pts := PackedVector2Array()
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				pts.append(xf * foul.field.to_global(corner))
			draw_colored_polygon(pts, Color(0.95, 0.2, 0.2, 0.16))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.35, 0.3, 0.8), 3.0)

		# A bola
		var bp: Vector2 = xf * foul.spot
		draw_arc(bp, 20.0 * zoom, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.5)

		# Os jogadores: anel do time, anel dourado no cobrador, destaque no que está sob o mouse
		for p: Player in get_tree().get_nodes_in_group("players"):
			var pos: Vector2 = xf * (p.global_position + Vector2(0.0, -18.0))
			var color: Color = TeamStyle.color_of(p.team)
			var radius: float = 17.0 * zoom
			var is_taker: bool = p == foul.taker
			if is_taker:
				draw_arc(pos, radius + 3.0 * zoom, 0.0, TAU, 40, UiStyle.ACCENT_COLOR, 2.5)
				var label := "COBRADOR"
				var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				var at := pos + Vector2(-w * 0.5, -radius - 12.0 * zoom)
				draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.85))
				draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.ACCENT_COLOR)
			else:
				draw_arc(pos, radius, 0.0, TAU, 32, Color(color, 0.6), 1.5)
			if p == screen._hover or p == screen._drag:
				draw_arc(pos, radius + 2.0 * zoom, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 2.0)


# ---------- AVISO RÁPIDO ----------

## Texto curto no pé da tela que some sozinho
static func toast(host: Node, text: String, color: Color = Color.WHITE, seconds: float = 1.5) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	host.add_child(layer)
	var label := UiStyle.make_label(text, 26, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_bottom = -130.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	var tw := layer.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)
