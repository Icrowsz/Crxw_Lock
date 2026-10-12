class_name FormationSetup
extends CanvasLayer
## Tela de montagem das formações, antes da partida.
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
## Painel lateral (do lado oposto à metade do time, para não cobrir quem está sendo arrastado):
##  - um MAPA do campo com a formação (bolinhas numeradas = posições) e, ao lado,
##  - a lista de POSIÇÕES com o rosto e o nome do personagem de cada uma.
## Clicar numa posição (no mapa ou na lista) abre o SELETOR: uma grade com o rosto e o nome de
## cada personagem. Ao confirmar, aparece a imagem completa do personagem com um flash de tela.
## As imagens vêm do CharacterRoster (face_for / full_for) e do KeeperRoster (art_for).

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
var _side_panel: PanelContainer      # painel lateral: mapa da formação + lista de posições
var _mini: _MiniPitch
var _position_list: VBoxContainer
var _formation_label: Label
var _formation_name: String = ""     # formação pronta aplicada ("" = montada na mão)
var _slot_targets: Array[Node2D] = []   # Player/Goalkeeper de cada posição (índice = número - 1)
var _role_labels: Array[Label] = []     # "Defesa / Meio-campo / Ataque" de cada posição
var _role_timer: float = 0.0

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
const POSITION_FACE_SIZE: int = 64   # rosto na lista de posições
const PICK_FACE_SIZE: int = 112      # rosto no seletor
const PICK_COLUMNS: int = 5
var _name_edit: LineEdit             # nome do time
var _top_panel: PanelContainer       # faixa do topo (título + botão "Personalizar time")
var _bottom_panel: PanelContainer    # formações prontas + confirmar
var _banner_badge: TeamBadge         # selo do time na faixa do topo
var _team_modal: Control             # janela "Personalizar time": nome, ícone e cor
var _swatch_box: HFlowContainer      # bolinhas de cor do time (quebra em linhas)
var _custom_picker: ColorPickerButton   # cor livre
var _updating_picker: bool = false      # mudando o seletor por código (não é escolha do jogador)
var _color_hint: Label                  # aviso: cor parecida com o outro time / com o gramado
var _icon_badge: TeamBadge              # selo do time na linha do nome
var _icon_name_label: Label
var _side_badge: TeamBadge              # selo no cabeçalho do painel lateral
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


## Mapa esquemático do campo com a formação do time: bolinhas numeradas = posições (o "G" é o
## goleiro). Clicar numa bolinha abre a escolha de personagem daquela posição.
class _MiniPitch extends Control:
	signal slot_clicked(index: int)

	var field: Field
	var team: int = 0
	var color: Color = Color.WHITE
	var targets: Array[Node2D] = []   # Player/Goalkeeper; índice + 1 = número da posição
	var hover_index: int = -1

	func _init() -> void:
		custom_minimum_size = Vector2(260.0, 170.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Posição global no campo -> posição neste mapa
	func _to_mini(global_p: Vector2) -> Vector2:
		var half: Vector2 = field.pitch_size * 0.5
		var l: Vector2 = field.to_local(global_p)
		var p := Vector2((l.x / half.x * 0.5 + 0.5) * size.x, (l.y / half.y * 0.5 + 0.5) * size.y)
		# Quem ainda está fora do campo (antes de escolher a formação) fica na borda do mapa
		return Vector2(clampf(p.x, 14.0, size.x - 14.0), clampf(p.y, 14.0, size.y - 14.0))

	func _index_at(pos: Vector2) -> int:
		var best: int = -1
		var best_dist: float = 17.0
		for i in targets.size():
			if not is_instance_valid(targets[i]):
				continue
			var d: float = _to_mini(targets[i].global_position).distance_to(pos)
			if d < best_dist:
				best = i
				best_dist = d
		return best

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var idx: int = _index_at((event as InputEventMouseMotion).position)
			if idx != hover_index:
				hover_index = idx
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if idx >= 0 \
					else Control.CURSOR_ARROW
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var idx: int = _index_at((event as InputEventMouseButton).position)
			if idx >= 0:
				slot_clicked.emit(idx)
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover_index != -1:
			hover_index = -1
			queue_redraw()

	func _draw() -> void:
		if field == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.12, 0.38, 0.20))
		for i in 8:   # faixas do gramado
			if i % 2 == 0:
				draw_rect(Rect2(size.x * float(i) / 8.0, 0.0, size.x / 8.0, size.y), Color(1, 1, 1, 0.045))
		var half_w: float = size.x * 0.5
		# metade do time (cor do time)
		draw_rect(Rect2(0.0 if team == 0 else half_w, 0.0, half_w, size.y), Color(color, 0.24))
		# linhas
		var line := Color(1, 1, 1, 0.75)
		draw_rect(r, line, false, 2.0)
		draw_line(Vector2(half_w, 0.0), Vector2(half_w, size.y), line, 1.5)
		draw_arc(Vector2(half_w, size.y * 0.5), size.y * 0.17, 0.0, TAU, 28, line, 1.5)
		var box := Vector2(size.x * 0.14, size.y * 0.5)
		draw_rect(Rect2(0.0, (size.y - box.y) * 0.5, box.x, box.y), line, false, 1.5)
		draw_rect(Rect2(size.x - box.x, (size.y - box.y) * 0.5, box.x, box.y), line, false, 1.5)
		# posições
		var font: Font = ThemeDB.fallback_font
		for i in targets.size():
			var t: Node2D = targets[i]
			if not is_instance_valid(t):
				continue
			var p: Vector2 = _to_mini(t.global_position)
			var strong: bool = i == hover_index
			var radius: float = 12.5 if strong else 10.5
			var fill: Color = color.lightened(0.45) if t is Goalkeeper else color
			draw_circle(p + Vector2(0.0, 2.0), radius + 1.0, Color(0, 0, 0, 0.35))
			draw_circle(p, radius, fill)
			draw_arc(p, radius, 0.0, TAU, 20, Color.WHITE if strong else Color(1, 1, 1, 0.8),
				3.0 if strong else 1.5)
			var txt: String = "G" if t is Goalkeeper else str(i + 1)
			draw_string_outline(font, p + Vector2(-6.0, 5.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 12.0, 13, 4, Color(0, 0, 0, 0.8))
			draw_string(font, p + Vector2(-6.0, 5.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 12.0, 13, Color.WHITE)


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
	_field.add_child(_overlay)

	_build_ui()
	_begin_team(0)


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


func _build_ui() -> void:
	# Topo: faixa com a vez de quem monta (a borda leva a cor do time). Fica do lado do time.
	_top_panel = PanelContainer.new()
	_top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_style = _big_panel(_top_panel)
	_title_style.set_border_width_all(3)
	add_child(_top_panel)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_panel.add_child(top_row)

	_banner_badge = TeamBadge.make(0, 64.0)
	_banner_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_banner_badge)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 6)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_box)
	_title = UiStyle.make_label("", _fs(24))
	top_box.add_child(_title)
	var hint: Label = UiStyle.make_label(
		"Arraste os jogadores dentro da sua metade (área colorida) ou escolha uma formação pronta",
		_fs(11), UiStyle.MUTED_COLOR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(430.0, 0.0)
	top_box.add_child(hint)

	var customize := Button.new()
	customize.text = "Personalizar time"
	customize.focus_mode = Control.FOCUS_NONE
	customize.tooltip_text = "Nome, ícone e cor do time"
	UiStyle.style_button(customize, Color(0.35, 0.45, 0.85))
	_big_button(customize, Vector2(220.0, 52.0), _fs(15))
	customize.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	customize.pressed.connect(_open_team_modal)
	top_row.add_child(customize)

	# Rodapé: formações prontas + confirmar
	_bottom_panel = PanelContainer.new()
	_bottom_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bottom_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_panel.offset_bottom = -16
	_big_panel(_bottom_panel)
	add_child(_bottom_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_bottom_panel.add_child(box)

	var presets_title: Label = UiStyle.make_label("Formações prontas", _fs(14))
	presets_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(presets_title)

	_preset_box = HFlowContainer.new()
	_preset_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_preset_box.add_theme_constant_override("h_separation", 12)
	_preset_box.add_theme_constant_override("v_separation", 12)
	_preset_box.custom_minimum_size = Vector2(640.0, 0.0)
	box.add_child(_preset_box)

	_confirm_button = Button.new()
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(_confirm_button, Color(0.25, 0.65, 0.35))
	_big_button(_confirm_button, Vector2(300.0, 58.0), _fs(16))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	box.add_child(_confirm_button)

	_build_side_panel()
	_build_team_modal()
	_build_picker()
	_build_icon_picker()
	_build_reveal()


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
		UiStyle.style_button(b)
		_big_button(b, Vector2(88.0, 50.0), _fs(14))
		_preset_box.add_child(b)

	var restore := Button.new()
	restore.text = "Restaurar"
	restore.pressed.connect(_restore)
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
	if _mini != null:
		_mini.color = color
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


func _build_side_panel() -> void:
	_side_panel = PanelContainer.new()
	_big_panel(_side_panel)
	add_child(_side_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_side_panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	_side_badge = TeamBadge.make(0, 46.0)
	head.add_child(_side_badge)
	var title: Label = UiStyle.make_label("Posições", _fs(20))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	_formation_label = UiStyle.make_label("", _fs(12), UiStyle.MUTED_COLOR)
	_formation_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_formation_label)
	box.add_child(UiStyle.make_label(
		"Clique numa posição (no mapa ou na lista) para escolher o personagem", _fs(11), UiStyle.MUTED_COLOR))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	box.add_child(body)

	_mini = _MiniPitch.new()
	_mini.field = _field
	var aspect: float = _field.pitch_size.y / maxf(_field.pitch_size.x, 1.0)
	_mini.custom_minimum_size = Vector2(300.0, clampf(300.0 * aspect, 140.0, 260.0))
	_mini.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_mini.slot_clicked.connect(_open_picker)
	body.add_child(_mini)

	# A lista usa a altura que sobra na tela (acima do rodapé)
	var screen_h: float = get_viewport().get_visible_rect().size.y
	var list_h: float = clampf(screen_h - 520.0, 220.0, 560.0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350.0, list_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_position_list = VBoxContainer.new()
	_position_list.add_theme_constant_override("separation", 12)
	_position_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_position_list)


## Faixa do topo e o painel de posições ficam em lados opostos: a faixa do lado do time e as
## posições do lado OPOSTO (time 0 = esquerda), para nada cobrir quem está sendo arrastado
func _place_panels(team: int) -> void:
	var left: bool = team == 0
	_top_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT if left else Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_top_panel.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	_side_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT if left else Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_side_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if left else Control.GROW_DIRECTION_END
	_side_panel.offset_top = 128.0   # abaixo da faixa do topo


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


## "Defesa / Meio-campo / Ataque", conforme onde o jogador está na metade do time
func _role_for(node: Node2D) -> String:
	if node is Goalkeeper:
		return "Goleiro"
	var area: Rect2 = Formations.team_area(_team, _field)
	var local: Vector2 = _field.to_local(node.global_position)
	var depth: float = (local.x - area.position.x) / maxf(area.size.x, 1.0)
	if _team == 1:
		depth = 1.0 - depth
	if depth < 0.34:
		return "Defesa"
	if depth < 0.67:
		return "Meio-campo"
	return "Ataque"


## Uma linha por posição: número, rosto, nome do personagem e função. Clicar abre o seletor.
func _make_position_card(index: int, target: Node2D) -> Button:
	var is_keeper: bool = target is Goalkeeper
	var name_text: String
	var face: Texture2D
	if is_keeper:
		var keeper: Goalkeeper = target as Goalkeeper
		name_text = _keeper_name(keeper.keeper_id)
		face = KeeperRoster.art_for(keeper.keeper_id)
	else:
		var player: Player = target as Player
		name_text = _character_name(player.character_id, player)
		face = CharacterRoster.face_for(player.character_id)

	var team_color: Color = TeamStyle.color_of(_team)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0.0, POSITION_FACE_SIZE + 20.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "Clique para escolher o personagem desta posição"
	if is_keeper:
		card.tooltip_text = KeeperRoster.description_for((target as Goalkeeper).keeper_id) \
			+ "\n\nClique para escolher o goleiro desta posição"
	card.add_theme_stylebox_override("normal", _card_style(CARD_BG, Color(1, 1, 1, 0.12)))
	card.add_theme_stylebox_override("hover", _card_style(CARD_HOVER, team_color, 3))
	card.add_theme_stylebox_override("pressed", _card_style(CARD_HOVER, Color.WHITE, 3))
	card.add_theme_stylebox_override("focus", _card_style(CARD_HOVER, Color.WHITE, 3))
	card.pressed.connect(_open_picker.bind(index))
	card.mouse_entered.connect(_set_mini_hover.bind(index))
	card.mouse_exited.connect(_set_mini_hover.bind(-1))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var badge: Label = UiStyle.make_label("G" if is_keeper else str(index + 1), _fs(16), team_color.lightened(0.35))
	badge.custom_minimum_size = Vector2(30.0, 0.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)

	row.add_child(_make_face(face, name_text, POSITION_FACE_SIZE, team_color))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_label: Label = UiStyle.make_label(name_text, _fs(14))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var role_label: Label = UiStyle.make_label(_role_for(target), _fs(10), UiStyle.MUTED_COLOR)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(role_label)
	_role_labels.append(role_label)
	return card


func _set_mini_hover(index: int) -> void:
	if _mini != null:
		_mini.hover_index = index
		_mini.queue_redraw()


## Refaz a lista de posições (e o mapa) do time atual: um cartão por jogador + o goleiro
func _rebuild_positions() -> void:
	for child in _position_list.get_children():
		_position_list.remove_child(child)
		child.queue_free()
	_slot_targets.clear()
	_role_labels.clear()

	var players: Array[Player] = manager.get_team_players(_team)
	for p in players:
		_slot_targets.append(p)

	# O goleiro do time (ele não é um Player: a troca é pelo KeeperRoster). O Field o cria no
	# próximo frame, então tenta de novo uma vez.
	var keeper: Goalkeeper = _keeper_of(_team)
	if keeper != null:
		_slot_targets.append(keeper)
	elif not _keeper_retried:
		_keeper_retried = true
		_rebuild_positions.call_deferred()

	for i in _slot_targets.size():
		_position_list.add_child(_make_position_card(i, _slot_targets[i]))

	_mini.team = _team
	_mini.color = TeamStyle.color_of(_team)
	_mini.targets = _slot_targets
	_mini.hover_index = -1
	_mini.queue_redraw()


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
	_picker = Control.new()
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.visible = false
	add_child(_picker)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker.add_child(center)

	var panel := PanelContainer.new()
	_big_panel(panel)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	_picker_title = UiStyle.make_label("", _fs(22))
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_picker_title)
	box.add_child(UiStyle.make_label("Clique num personagem e confirme (Esc cancela)", _fs(11), UiStyle.MUTED_COLOR))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(float(PICK_COLUMNS) * 156.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_picker_grid = GridContainer.new()
	_picker_grid.columns = PICK_COLUMNS
	_picker_grid.add_theme_constant_override("h_separation", 10)
	_picker_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_picker_grid)

	_picker_name = UiStyle.make_label("", _fs(18))
	_picker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_picker_name)
	_picker_desc = UiStyle.make_label("", _fs(12), UiStyle.MUTED_COLOR)
	_picker_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picker_desc.custom_minimum_size = Vector2(float(PICK_COLUMNS) * 156.0, 0.0)
	_picker_desc.visible = false
	box.add_child(_picker_desc)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	UiStyle.style_button(cancel, Color(0.75, 0.30, 0.30))
	_big_button(cancel, Vector2(180.0, 54.0), _fs(15))
	cancel.pressed.connect(_close_picker)
	buttons.add_child(cancel)
	var ok := Button.new()
	ok.text = "Confirmar personagem"
	UiStyle.style_button(ok, Color(0.25, 0.65, 0.35))
	_big_button(ok, Vector2(260.0, 54.0), _fs(15))
	ok.pressed.connect(_on_picker_confirm)
	buttons.add_child(ok)


## Entradas do seletor: {id, name, face, full} (+ description nos goleiros). Goleiro usa o KeeperRoster (uma imagem só).
func _entries_for(keeper: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if keeper:
		for k in KeeperRoster.KEEPERS:
			var art: Texture2D = KeeperRoster.art_for(k["id"])
			out.append({"id": k["id"], "name": k["name"], "face": art, "full": art,
				"description": KeeperRoster.description_for(k["id"])})
	else:
		for c in CharacterRoster.available():
			out.append({"id": c["id"], "name": c["name"],
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
	card.custom_minimum_size = Vector2(142.0, float(PICK_FACE_SIZE) + 56.0)
	card.pressed.connect(_on_pick_card_pressed.bind(String(entry["id"])))

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
	var label: Label = UiStyle.make_label(String(entry["name"]), _fs(11))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(label)
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


func _on_pick_card_pressed(id: String) -> void:
	_picker_pending_id = id
	_refresh_pick_selection()
	if _pick_buttons.has(id):
		UiStyle.pop(_picker_name, 1.1, 0.15)


## Abre o seletor para a posição (índice na lista/mapa; a última é o goleiro)
func _open_picker(index: int) -> void:
	if _modal_open or index < 0 or index >= _slot_targets.size():
		return
	var target: Node2D = _slot_targets[index]
	if not is_instance_valid(target):
		return
	_finish_move()
	_dragging = null

	_picker_index = index
	_picker_is_keeper = target is Goalkeeper
	_picker_entries = _entries_for(_picker_is_keeper)
	_picker_current_id = (target as Goalkeeper).keeper_id if _picker_is_keeper \
		else (target as Player).character_id
	_picker_pending_id = _picker_current_id
	_picker_title.text = ("Goleiro" if _picker_is_keeper else "Posição %d" % (index + 1)) \
		+ " — escolha o personagem"

	for child in _picker_grid.get_children():
		_picker_grid.remove_child(child)
		child.queue_free()
	_pick_buttons.clear()
	for entry in _picker_entries:
		var card: Button = _make_pick_card(entry)
		_picker_grid.add_child(card)
		_pick_buttons[String(entry["id"])] = card
	_refresh_pick_selection()

	_picker.visible = true
	_modal_open = true
	UiStyle.pop(_picker_title, 1.08, 0.2)


func _close_picker() -> void:
	_picker.visible = false
	_modal_open = false


func _on_picker_confirm() -> void:
	var entry: Dictionary = _entry_by_id(_picker_pending_id)
	if entry.is_empty():
		return
	var id: String = _picker_pending_id
	var target: Node2D = _slot_targets[_picker_index] if _picker_index < _slot_targets.size() else null
	_close_picker()

	if is_instance_valid(target) and id != _picker_current_id:
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
	UiStyle.pop(_side_badge, 1.4, 0.3)
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
	for badge in [_icon_badge, _side_badge, _banner_badge]:
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
	_formation_name = ""
	_update_formation_label()
	_place_panels(team)
	_keeper_retried = false
	_rebuild_positions()


## Próximo time que ainda não confirmou (-1 = ninguém, ou seja, este é o último)
func _next_team_after(team: int) -> int:
	for t in _confirmed.size():
		if t != team and not _confirmed[t]:
			return t
	return -1


func _on_confirm_pressed() -> void:
	_finish_move()
	_dragging = null
	_confirmed[_team] = true
	var next: int = _next_team_after(_team)
	if next == -1:
		finished.emit()
		queue_free()
	else:
		_begin_team(next)


# ---------- FORMAÇÕES PRONTAS ----------

func _apply_preset(formation: String) -> void:
	_finish_move()
	var players: Array[Player] = manager.get_team_players(_team)
	var slot_positions: Array[Vector2] = Formations.slots(formation, _team, _field)
	_targets = Formations.assign(players, slot_positions)
	_formation_name = formation
	_update_formation_label()

	_overlay.slots.clear()
	for s in slot_positions:
		_overlay.slots.append(_field.to_local(s))
	_start_move()


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


# ---------- ARRASTAR ----------

func _mouse_world() -> Vector2:
	return _field.get_global_mouse_position()


## Jogador do time atual debaixo do mouse (o mais próximo)
func _player_at(pos: Vector2) -> Player:
	var best: Player = null
	var best_dist: float = INF
	for p in manager.get_team_players(_team):
		var d: float = p.global_position.distance_to(pos)
		if d <= p.body_radius + 12.0 and d < best_dist:
			best = p
			best_dist = d
	return best


func _unhandled_input(event: InputEvent) -> void:
	if _team < 0:
		return
	# Esc fecha o seletor de personagem
	if _picker != null and _picker.visible and event.is_action_pressed("ui_cancel"):
		_close_picker()
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
	if _modal_open:
		return   # seletor/revelação na tela: o campo não recebe cliques

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_name_edit.release_focus()   # clicar no campo tira o cursor do campo de nome
			var p: Player = _player_at(_mouse_world())
			if p != null:
				_finish_move()
				_dragging = p
				_formation_name = ""   # mexeu na mão: deixa de ser uma formação pronta
				_update_formation_label()
				_drag_offset = p.global_position - _mouse_world()
				_overlay.slots.clear()   # o guia some quando você começa a mexer na mão
				get_viewport().set_input_as_handled()
		elif _dragging != null:
			_dragging = null
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging != null:
		_dragging.global_position = _constrain(_mouse_world() + _drag_offset, _dragging)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _field == null or _team < 0:
		return
	# O mapa acompanha os jogadores (arrastar, formação deslizando) e a função de cada posição
	if _mini != null:
		_mini.queue_redraw()
	_role_timer -= delta
	if _role_timer <= 0.0:
		_role_timer = 0.15
		for i in _role_labels.size():
			if i < _slot_targets.size() and is_instance_valid(_slot_targets[i]) \
					and is_instance_valid(_role_labels[i]):
				_role_labels[i].text = _role_for(_slot_targets[i])
	if _modal_open:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if _dragging == null:
		_hover = _player_at(_mouse_world())
	Input.set_default_cursor_shape(
		Input.CURSOR_DRAG if _dragging != null
		else (Input.CURSOR_POINTING_HAND if _hover != null else Input.CURSOR_ARROW))
	_overlay.hover = _hover
	_overlay.dragging = _dragging
	_overlay.queue_redraw()


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
