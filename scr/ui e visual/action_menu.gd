extends CanvasLayer
## Interface da partida. Monta tudo por código:
## basta adicionar um CanvasLayer com este script e apontar o "manager".
## Visual compartilhado (cores neutras, contorno, painéis, botões) vem do UiStyle.

@export var manager: MatchManager
## true = lista de habilidades na direita da tela; false = na esquerda (no meio da altura)
@export var skills_on_right: bool = true
## Distância do painel "Rodada N" até o topo da tela (ele fica logo abaixo do placar)
@export var turn_top_offset: float = 78.0

var turn_label: Label
var info_label: Label
var general_buttons: Dictionary = {}  # MatchManager.GeneralAction -> Button
var skill_box: VBoxContainer          # botões de habilidade (mudam conforme quem está agindo)
var _skill_buttons: Array[Button] = []
var _skill_ids: Array[StringName] = []
var _skill_chips: Array[Label] = []   # "recarga N" de cada botão de habilidade
var _skill_bars: Array[Control] = []  # barrinha de progresso da recarga de cada botão
var _skill_block: PanelContainer      # bloco da lista de habilidades
var end_turn_button: Button
var pass_box: HBoxContainer
var pass_variant_buttons: Dictionary = {}  # MatchManager.PassVariant -> Button

var _turn_style: StyleBoxFlat   # a borda do painel do topo leva a cor do time da vez
var _last_team: int = -1
var _last_team_color: Color = Color.TRANSPARENT
var _color_tween: Tween

# Troca de turno: vinheta suave na cor do time + painéis balançando em cascata
const VIGNETTE_REST: float = 0.10    # brilho da vinheta no dia a dia (dá para perceber)
const VIGNETTE_PEAK: float = 1.0     # brilho no instante da troca de turno
var _vignette: TextureRect
var _vignette_tween: Tween
var _turn_panel: PanelContainer
var _actions_block: PanelContainer
# "Habilidade pronta": recarga restante vista da última vez ("idJogador:idHabilidade" -> int)
var _recharge_seen: Dictionary = {}
var _recharge_total: Dictionary = {}   # maior recarga vista de cada habilidade (a barrinha usa)

## Pasta com as imagens das ações gerais (run.png, jump.png, slide.png, shoot.png, pass.png,
## stand_up.png). Imagem que não existir é só pulada: o balão aparece sem figura.
@export var general_icon_dir: String = "res://img/actions/"

const GENERAL_ICON_FILES := {
	MatchManager.GeneralAction.RUN: "run",
	MatchManager.GeneralAction.JUMP: "jump",
	MatchManager.GeneralAction.SLIDE: "slide",
	MatchManager.GeneralAction.SHOOT: "shoot",
	MatchManager.GeneralAction.PASS: "pass",
	MatchManager.GeneralAction.STAND_UP: "stand_up",
}

# Balão de descrição (aparece quando o mouse passa por cima de um botão de ação)
var _tip_panel: PanelContainer
var _tip_icon: TextureRect
var _tip_title: Label
var _tip_desc: Label
var _hover_button: Button = null
var _hover_kind: StringName = &""    # &"general" ou &"skill"
var _hover_key: Variant = null       # GeneralAction ou id da habilidade
var _tip_hash: int = 0
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_build_ui()
	manager.state_changed.connect(_refresh)
	_refresh()


## Vinheta: escurece/colore só as bordas da tela. A cor vem do modulate (cor do time da vez).
func _build_vignette() -> void:
	var grad := Gradient.new()
	# Só nas PONTAS (cantos) da tela: o meio das bordas fica limpo
	grad.offsets = PackedFloat32Array([0.0, 0.74, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.85)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)   # raio até o canto: o gradiente só "pega" nos cantos
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 1, 1, 0)
	add_child(_vignette)   # primeiro filho: fica por baixo de todos os painéis


## Efeito da troca de turno: a vinheta acende na cor do time e some devagar; os painéis dão
## um balanço em cascata (a gelatina do UiStyle)
func _play_turn_change(color: Color) -> void:
	_vignette.modulate = Color(color.r, color.g, color.b, _vignette.modulate.a)
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", VIGNETTE_PEAK, 0.12)
	_vignette_tween.tween_property(_vignette, "modulate:a", VIGNETTE_REST, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	UiStyle.jelly_chain([_turn_panel, _actions_block, _skill_block], 1.05, 0.06)


## Barrinha fina no pé do botão de habilidade: enche conforme a recarga passa
func _make_recharge_bar(b: Button) -> Control:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = -11
	bar.offset_bottom = -6
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	for fill in [false, true]:
		var panel := Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.bg_color = UiStyle.ACCENT_COLOR if fill else Color(1, 1, 1, 0.16)
		panel.add_theme_stylebox_override("panel", sb)
		bar.add_child(panel)
	b.add_child(bar)
	return bar


## fraction 0..1 = quanto da recarga já passou; visible_bar = false esconde a barrinha
func _set_recharge_bar(bar: Control, fraction: float, visible_bar: bool) -> void:
	bar.visible = visible_bar
	if visible_bar:
		(bar.get_child(1) as Control).anchor_right = clampf(fraction, 0.0, 1.0)


## Habilidade que acabou de ficar disponível: brilho dourado único + gelatina
func _flash_ready(b: Button) -> void:
	UiStyle.jelly(b, 1.12, 0.5)
	b.modulate = Color(1.9, 1.7, 1.0)
	var tw := b.create_tween()
	tw.tween_property(b, "modulate", Color.WHITE, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_ui() -> void:
	_build_vignette()
	# Topo: rodada e time da vez. O texto é neutro; quem indica o time é a borda do painel.
	var turn_panel := PanelContainer.new()
	turn_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	turn_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	turn_panel.offset_top = turn_top_offset
	turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_style = UiStyle.style_panel(turn_panel)
	_turn_style.set_border_width_all(3)
	add_child(turn_panel)
	_turn_panel = turn_panel

	turn_label = UiStyle.make_label("", 20)
	turn_panel.add_child(turn_label)

	# Bloco das AÇÕES (embaixo, à esquerda): informações + botões cilíndricos em linha
	var actions_block := PanelContainer.new()
	actions_block.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	actions_block.grow_horizontal = Control.GROW_DIRECTION_END
	actions_block.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actions_block.offset_left = 16
	actions_block.offset_bottom = -16
	actions_block.add_theme_stylebox_override("panel", _block_style())
	add_child(actions_block)
	_actions_block = actions_block

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	actions_block.add_child(vbox)

	info_label = UiStyle.make_label("", 16)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(620, 0)
	vbox.add_child(info_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	for action in MatchManager.GENERAL_ACTION_NAMES:
		var b := Button.new()
		b.text = MatchManager.GENERAL_ACTION_NAMES[action]
		b.pressed.connect(manager.do_general_action.bind(action))
		_pill(b, Color(0.30, 0.34, 0.45))
		hbox.add_child(b)
		general_buttons[action] = b
		_hook_hover(b, &"general", action)

	end_turn_button = Button.new()
	end_turn_button.text = "Encerrar turno"
	end_turn_button.pressed.connect(manager.request_end_turn)
	_pill(end_turn_button, Color(0.75, 0.30, 0.30))  # avermelhado: passa a vez
	hbox.add_child(end_turn_button)

	# Linha extra do Passe: variantes + cancelar (só aparece durante a escolha)
	pass_box = HBoxContainer.new()
	pass_box.add_theme_constant_override("separation", 8)
	pass_box.visible = false
	vbox.add_child(pass_box)

	for variant in MatchManager.PASS_VARIANT_NAMES:
		var vb := Button.new()
		vb.text = MatchManager.PASS_VARIANT_NAMES[variant]
		vb.pressed.connect(manager.choose_pass_variant.bind(variant))
		_pill(vb, Color(0.30, 0.34, 0.45))
		pass_box.add_child(vb)
		pass_variant_buttons[variant] = vb

	var cancel_button := Button.new()
	cancel_button.text = "Cancelar passe"
	cancel_button.pressed.connect(manager.cancel_pass)
	_pill(cancel_button, Color(0.75, 0.30, 0.30))
	pass_box.add_child(cancel_button)

	# Bloco das HABILIDADES (lista vertical, cada uma com a sua recarga): à direita ou à esquerda
	_skill_block = PanelContainer.new()
	if skills_on_right:
		_skill_block.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_skill_block.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_skill_block.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_skill_block.offset_right = -16
		_skill_block.offset_bottom = -16
	else:
		_skill_block.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		_skill_block.grow_horizontal = Control.GROW_DIRECTION_END
		_skill_block.grow_vertical = Control.GROW_DIRECTION_BOTH
		_skill_block.offset_left = 16
	_skill_block.add_theme_stylebox_override("panel", _block_style(UiStyle.ACCENT_COLOR.darkened(0.45)))
	_skill_block.visible = false   # só aparece quando alguém está agindo
	add_child(_skill_block)

	var skill_vbox := VBoxContainer.new()
	skill_vbox.add_theme_constant_override("separation", 8)
	_skill_block.add_child(skill_vbox)
	skill_vbox.add_child(UiStyle.make_label("Habilidades", 15, UiStyle.ACCENT_COLOR))

	skill_box = VBoxContainer.new()  # os botões dourados são criados em _update_skill_buttons
	skill_box.add_theme_constant_override("separation", 8)
	skill_vbox.add_child(skill_box)

	_build_tooltip()


## Bloco "quadrado" que guarda os botões (cantos só levemente arredondados)
func _block_style(border: Color = UiStyle.PANEL_BORDER) -> StyleBoxFlat:
	var sb: StyleBoxFlat = UiStyle.panel_style(border, 18.0, 14.0)
	sb.set_corner_radius_all(18)
	return sb


## Botão "cilíndrico" (pílula). Usa o UiStyle.style_button, então o pulinho no hover e a
## gelatina ao clicar continuam iguais; aqui só arredondamos os cantos e aumentamos o botão.
func _pill(b: Button, accent: Color, font_size: int = 17, min_height: float = 46.0) -> void:
	UiStyle.style_button(b, accent)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state) as StyleBoxFlat
		if sb != null:
			sb.set_corner_radius_all(int(min_height * 0.5))
			sb.content_margin_left = 22
			sb.content_margin_right = 22
	b.add_theme_font_size_override("font_size", font_size)
	UiStyle.outline(b, font_size)
	b.custom_minimum_size = Vector2(0.0, min_height)
	b.focus_mode = Control.FOCUS_NONE


## Separa "Nome (recarga 2)" em [nome, 2]. Sem recarga: [nome, 0]
func _split_recharge(label: String) -> Array:
	var i: int = label.rfind(" (recarga ")
	if i < 0 or not label.ends_with(")"):
		return [label, 0]
	var num: String = label.substr(i + 10, label.length() - i - 11)
	return [label.substr(0, i), int(num) if num.is_valid_int() else 0]


func _refresh() -> void:
	# Na montagem das formações a tela de formação ocupa o lugar deste menu
	visible = manager.phase != MatchManager.Phase.FORMATION
	if manager.phase == MatchManager.Phase.FORMATION:
		_recharge_seen.clear()   # partida nova: ninguém "acabou de ficar pronto"
		_recharge_total.clear()
	turn_label.text = "Rodada %d" % manager.round_number   # a borda do painel mostra o time da vez
	_update_team_border()

	var p: Player = manager.active_player

	_update_general_buttons()

	var choosing_variant: bool = manager.phase == MatchManager.Phase.CHOOSING_PASS_VARIANT
	var choosing_target: bool = manager.phase == MatchManager.Phase.CHOOSING_PASS_TARGET
	pass_box.visible = choosing_variant or choosing_target
	for variant in pass_variant_buttons:
		var vb: Button = pass_variant_buttons[variant]
		vb.visible = choosing_variant
		vb.disabled = not manager.can_choose_pass_variant(variant)

	_update_skill_buttons()
	end_turn_button.disabled = manager.phase != MatchManager.Phase.CHOOSING_ACTION

	match manager.phase:
		MatchManager.Phase.CHOOSING_PROTAGONIST:
			info_label.text = "Time %s: clique em um jogador para ser o Protagonista" % \
				manager.get_team_name(manager.current_team)
		MatchManager.Phase.CHOOSING_ACTION:
			var role_text: String = "Protagonista" if p == manager.protagonist else "Secundário"
			var status: String = "Altura: %s" % Heights.level_name(p.height_level)
			if p.is_down:
				status += " | DERRUBADO (só pode Levantar)"
			if p.is_confused():
				status += " | CONFUSO (habilidades embaralhadas)"
			if p.is_generals_suppressed():
				status += " | AÇÕES GERAIS BLOQUEADAS"
			if p.is_skills_suppressed():
				status += " | HABILIDADES BLOQUEADAS"
			for blocked in MatchManager.GENERAL_ACTION_NAMES:
				if p.is_general_action_blocked(blocked):
					status += " | SEM %s" % MatchManager.GENERAL_ACTION_NAMES[blocked]
			if p.extra_skill_left > 0:
				status += " | +%d habilidade extra" % p.extra_skill_left
			status += " | Correr %d/%d | Carrinho %d/%d" % [
				p.runs_this_turn, p.max_runs_per_turn, p.slides_this_turn, p.max_slides_per_turn]
			info_label.text = "Agindo: %s (%s) — %s\nProtagonista — gerais: %d | habilidade: %d\nSecundários — gerais: %d | habilidade: %d\nClique em um companheiro de time para trocar quem age" % [
				p.get_display_name(), role_text, status,
				manager.protagonist_general_left, manager.protagonist_skill_left,
				manager.secondary_general_left, manager.secondary_skill_left]
		MatchManager.Phase.CHOOSING_PASS_VARIANT:
			info_label.text = "%s: escolha o tipo de passe" % p.get_display_name()
		MatchManager.Phase.CHOOSING_PASS_TARGET:
			var variant_name: String = MatchManager.PASS_VARIANT_NAMES[manager.pass_variant]
			info_label.text = "%s: clique num companheiro dentro do alcance (anel verde)\nDireito ou Esc cancela" % variant_name
			if manager.pass_hint != "":
				info_label.text += "\n" + manager.pass_hint
		MatchManager.Phase.AIMING:
			info_label.text = "Mire com o mouse — clique esquerdo confirma, direito ou Esc cancela"
		MatchManager.Phase.EXECUTING:
			info_label.text = "%s em ação..." % p.get_display_name()
		MatchManager.Phase.MATCH_OVER:
			info_label.text = "Fim de jogo!"
		MatchManager.Phase.KEEPERS_ACTING:
			info_label.text = "Os goleiros estão agindo..."
		MatchManager.Phase.TEAM_EFFECTS:
			info_label.text = "Fim de turno: efeitos em andamento..."
		MatchManager.Phase.FORMATION:
			info_label.text = ""


## A borda do painel do topo muda (suavemente) para a cor do time da vez
func _update_team_border() -> void:
	var team: int = manager.current_team
	var color: Color = TeamStyle.color_of(team)
	if team == _last_team and color == _last_team_color:
		return
	var first: bool = _last_team == -1
	_last_team = team
	_last_team_color = color
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	if first:
		_turn_style.border_color = color
		_vignette.modulate = Color(color.r, color.g, color.b, VIGNETTE_REST)
		return
	_color_tween = create_tween()
	_color_tween.tween_property(_turn_style, "border_color", color, 0.25)
	UiStyle.pop(turn_label, 1.12, 0.25)
	_play_turn_change(color)


## Botões das ações gerais (Levantar só aparece para jogador derrubado).
## Também roda a cada frame na escolha de ação, porque a bola continua rolando
## e "Chutar" depende da distância até ela.
func _update_general_buttons() -> void:
	var p: Player = manager.active_player
	for action in general_buttons:
		var b: Button = general_buttons[action]
		b.disabled = not manager.can_use_general(action)
		if action == MatchManager.GeneralAction.STAND_UP:
			b.visible = p != null and p.is_down


## Um botão dourado por habilidade de quem está agindo. Reconstrói quando troca o jogador
## e atualiza nome/disponibilidade sempre (a bola rola e as alturas mudam).
func _update_skill_buttons() -> void:
	var p: Player = manager.active_player
	var skills: Array[Dictionary] = []
	if p:
		skills = p.get_skills()
	# Confuso (Confundo do Ness): a ordem dos botões é embaralhada e os nomes viram "???"
	var confused: bool = p != null and p.is_confused()
	if confused:
		skills = _shuffle_for_confusion(p, skills)

	var ids: Array[StringName] = []
	for s in skills:
		ids.append(s["id"])
	if ids != _skill_ids:
		_hide_tip()   # os botões vão ser recriados
		for b in _skill_buttons:
			b.queue_free()
		_skill_buttons.clear()
		_skill_chips.clear()
		_skill_bars.clear()
		_skill_ids = ids
		for id in ids:
			var b := Button.new()
			b.pressed.connect(manager.do_skill_action.bind(id))
			_pill(b, UiStyle.ACCENT_COLOR.darkened(0.25))  # dourado: ação especial
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.x = 330.0
			# Recarga: etiqueta no canto direito do botão
			var chip: Label = UiStyle.make_label("", 14, UiStyle.MUTED_COLOR)
			chip.set_anchors_preset(Control.PRESET_FULL_RECT)
			chip.offset_right = -20
			chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(chip)
			_skill_chips.append(chip)
			_skill_bars.append(_make_recharge_bar(b))
			skill_box.add_child(b)
			_skill_buttons.append(b)
			_hook_hover(b, &"skill", id)

	for i in skills.size():
		if confused:
			_skill_buttons[i].text = "★ ???"
			_skill_chips[i].text = ""
			_skill_bars[i].visible = false
			# Habilitado até quando a habilidade não pode ser usada: não entrega qual é qual.
			# Apertar uma que não dá simplesmente não faz nada (o MatchManager confere).
			_skill_buttons[i].disabled = not (manager.can_act() and manager.skill_left_for(p) > 0)
		else:
			var parts: Array = _split_recharge(String(skills[i]["name"]))
			_skill_buttons[i].text = "★ " + String(parts[0])
			_skill_chips[i].text = ("recarga %d" % int(parts[1])) if int(parts[1]) > 0 else ""
			# Recarga que acabou desde a última vez que vimos: brilha uma vez
			var seen_key: String = "%d:%s" % [p.get_instance_id(), String(skills[i]["id"])]
			if int(_recharge_seen.get(seen_key, 0)) > 0 and int(parts[1]) == 0:
				_flash_ready(_skill_buttons[i])
			_recharge_seen[seen_key] = int(parts[1])
			# Barrinha: a maior recarga vista é o "total"; ao acabar, o total é esquecido
			var left: int = int(parts[1])
			if left > 0:
				_recharge_total[seen_key] = maxi(int(_recharge_total.get(seen_key, 0)), left)
				var total: int = maxi(int(_recharge_total[seen_key]), 1)
				_set_recharge_bar(_skill_bars[i], 1.0 - float(left) / float(total), true)
			else:
				_recharge_total.erase(seen_key)
				_set_recharge_bar(_skill_bars[i], 1.0, false)
			_skill_buttons[i].disabled = not manager.can_use_skill(skills[i]["id"])
	_skill_block.visible = p != null and not skills.is_empty()


## Ordem embaralhada de quem está confuso (sorteada uma vez por confusão, não a cada frame)
func _shuffle_for_confusion(p: Player, skills: Array[Dictionary]) -> Array[Dictionary]:
	var order: Array[int] = p.get_confusion_order(skills.size())
	var shuffled: Array[Dictionary] = []
	for index in order:
		shuffled.append(skills[index])
	return shuffled


func _process(_delta: float) -> void:
	if manager.phase == MatchManager.Phase.CHOOSING_ACTION:
		_update_general_buttons()
		_update_skill_buttons()

	# Mostra o tempo restante enquanto alguém corre
	var p: Player = manager.active_player
	if manager.phase == MatchManager.Phase.EXECUTING and p and p.state == Player.State.RUNNING:
		info_label.text = "%s correndo (WASD)... %.1fs" % [p.get_display_name(), p.run_time_left]

	_update_tip()


# ---------- BALÃO DE DESCRIÇÃO (hover) ----------

func _build_tooltip() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.visible = false
	UiStyle.style_panel(_tip_panel)
	add_child(_tip_panel)   # por último: fica por cima do resto da interface

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_tip_panel.add_child(row)

	_tip_icon = TextureRect.new()
	_tip_icon.custom_minimum_size = Vector2(72, 72)
	_tip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_tip_icon)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	_tip_title = UiStyle.make_label("", 18)
	_tip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_tip_title)

	_tip_desc = UiStyle.make_label("", 14)
	_tip_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(300, 0)
	col.add_child(_tip_desc)


func _hook_hover(b: Button, kind: StringName, key: Variant) -> void:
	b.mouse_entered.connect(_show_tip.bind(b, kind, key))
	b.mouse_exited.connect(_hide_tip)
	b.pressed.connect(_hide_tip)


func _show_tip(b: Button, kind: StringName, key: Variant) -> void:
	_hover_button = b
	_hover_kind = kind
	_hover_key = key
	_tip_hash = 0
	_update_tip()


func _hide_tip() -> void:
	_hover_button = null
	if _tip_panel:
		_tip_panel.visible = false


## Mantém o balão atualizado enquanto o mouse está no botão (a variante de uma habilidade
## pode mudar com a situação) e posicionado acima dele.
func _update_tip() -> void:
	if _tip_panel == null or _hover_button == null:
		return
	if not is_instance_valid(_hover_button) or not _hover_button.is_visible_in_tree():
		_hide_tip()
		return
	var data: Dictionary = _tip_data()
	if data.is_empty() or String(data.get("description", "")) == "":
		_tip_panel.visible = false
		return

	var h: int = hash(data)
	if h != _tip_hash:
		_tip_hash = h
		_tip_title.text = String(data.get("title", ""))
		_tip_desc.text = String(data["description"])
		var icon: Texture2D = data.get("icon") as Texture2D
		_tip_icon.texture = icon
		_tip_icon.visible = icon != null

	_tip_panel.visible = true
	_tip_panel.reset_size()
	var r: Rect2 = _hover_button.get_global_rect()
	var view_w: float = get_viewport().get_visible_rect().size.x
	var x: float = clampf(r.position.x + r.size.x * 0.5 - _tip_panel.size.x * 0.5,
		8.0, maxf(8.0, view_w - _tip_panel.size.x - 8.0))
	if _hover_kind == &"skill":
		# Lista vertical: o balão aparece ao lado do bloco (para dentro da tela)
		var view_h: float = get_viewport().get_visible_rect().size.y
		var tip_x: float = (r.position.x - _tip_panel.size.x - 12.0) if skills_on_right else (r.end.x + 12.0)
		var tip_y: float = clampf(r.position.y + r.size.y * 0.5 - _tip_panel.size.y * 0.5,
				8.0, maxf(8.0, view_h - _tip_panel.size.y - 8.0))
		_tip_panel.position = Vector2(maxf(tip_x, 8.0), tip_y)
	else:
		_tip_panel.position = Vector2(x, r.position.y - _tip_panel.size.y - 10.0)


## {"title", "description", "icon"} do botão em foco. Vazio = sem balão.
func _tip_data() -> Dictionary:
	var p: Player = manager.active_player
	if _hover_kind == &"general":
		return _general_tip(int(_hover_key), p)
	# Habilidade: quem descreve é o próprio personagem (get_skill_info). Quem não tiver essa
	# função fica sem balão. Confuso (Confundo): não entrega qual botão é qual.
	if p == null or p.is_confused() or not p.has_method("get_skill_info"):
		return {}
	return p.get_skill_info(_hover_key)


func _general_icon(action: int) -> Texture2D:
	if _icon_cache.has(action):
		return _icon_cache[action]
	var tex: Texture2D = null
	var path: String = "%s/%s.png" % [general_icon_dir, GENERAL_ICON_FILES.get(action, "")]
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icon_cache[action] = tex
	return tex


## Descrição das ações gerais (usa os números de quem está agindo, quando há alguém)
func _general_tip(action: int, p: Player) -> Dictionary:
	var text: String = ""
	match action:
		MatchManager.GeneralAction.RUN:
			var secs: float = (p.run_duration + p.run_time_bonus) if p else 1.5
			var uses: int = p.max_runs_per_turn if p else 2
			text = "Corre livremente com WASD por %.1f s. Só no chão, até %d vezes por turno." % [secs, uses]
		MatchManager.GeneralAction.JUMP:
			text = "Sobe ao nível Suspenso (só a partir do chão) e fica no ar até o turno do seu time voltar. Quem está suspenso passa por baixo de carrinhos e alcança a bola voando."
		MatchManager.GeneralAction.SLIDE:
			var dist: int = int(p.slide_distance) if p else 220
			var uses_s: int = p.max_slides_per_turn if p else 1
			text = "Mire e deslize até %d px. Derruba inimigos no chão e empurra a bola rasteira na direção do carrinho. Quem está suspenso desvia. Só no chão, %d vez por turno." % [dist, uses_s]
		MatchManager.GeneralAction.SHOOT:
			var reach: int = int(p.kick_range) if p else 70
			text = "Chuta a bola se ela estiver a até %d px e num nível alcançável. Chute no chão não tem QTE; bola alta, voleio e bola voando têm. Errar o QTE enfraquece o chute e derruba." % reach
		MatchManager.GeneralAction.PASS:
			text = "Passa para um companheiro, com a bola ao alcance. Rasteiro: alcance %d px, e inimigo no chão no caminho intercepta. Alto: alcance %d px, a bola paira e chega no seu próximo turno." % [
				int(manager.ground_pass_range), int(manager.high_pass_range)]
		MatchManager.GeneralAction.STAND_UP:
			text = "Levanta o jogador derrubado. Se ninguém levantar, ele se levanta sozinho depois de %d rodadas." % manager.auto_stand_up_rounds
	return {
		"title": MatchManager.GENERAL_ACTION_NAMES.get(action, ""),
		"description": text,
		"icon": _general_icon(action),
	}
