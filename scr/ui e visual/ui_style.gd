class_name UiStyle
extends RefCounted
## Estilo visual compartilhado da interface (placar, menu de ações, QTE).
## Tudo é estático: basta chamar UiStyle.make_label(...), UiStyle.panel_style() etc.

const TEXT_COLOR := Color(0.93, 0.93, 0.93)          # texto neutro
const MUTED_COLOR := Color(0.93, 0.93, 0.93, 0.65)   # texto secundário
const OUTLINE_COLOR := Color(0.05, 0.05, 0.05)       # contorno das letras
const PANEL_COLOR := Color(0.06, 0.07, 0.10, 0.78)   # fundo dos painéis
const PANEL_BORDER := Color(1, 1, 1, 0.14)
const ACCENT_COLOR := Color(1.0, 0.82, 0.25)         # destaque (habilidade, aviso)
const GOOD_COLOR := Color.LIME_GREEN
const BAD_COLOR := Color.TOMATO

## Cartões "pílula" claros (visual das telas de menu, ex: montagem das formações)
const CARD_COLOR := Color(0.79, 0.82, 0.88)        # cinza-azulado claro
const CARD_HOVER_COLOR := Color(0.88, 0.91, 0.96)
const CARD_TEXT := Color(0.08, 0.09, 0.13)          # texto escuro sobre o cartão
const SCREEN_BG := Color(0.035, 0.05, 0.045, 0.93)  # fundo escuro das telas de menu (esconde o campo)


## Contorno proporcional ao tamanho da fonte (26 pt ≈ 5, 48 pt ≈ 10)
static func outline(control: Control, font_size: int = 16) -> void:
	var size: int = clampi(roundi(font_size * 0.2), 3, 10)
	control.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	control.add_theme_constant_override("outline_size", size)


## Label já com cor neutra, contorno e centralizado. Quem quiser cor de time sobrescreve depois.
static func make_label(text: String, font_size: int, color: Color = TEXT_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	outline(label, font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Painel arredondado, translúcido, com borda fina e sombra leve
static func panel_style(border: Color = PANEL_BORDER, h_margin: float = 16.0, v_margin: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_COLOR
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = h_margin
	sb.content_margin_right = h_margin
	sb.content_margin_top = v_margin
	sb.content_margin_bottom = v_margin
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


## Aplica o painel a um PanelContainer
static func style_panel(panel: PanelContainer, border: Color = PANEL_BORDER) -> StyleBoxFlat:
	var sb := panel_style(border)
	panel.add_theme_stylebox_override("panel", sb)
	return sb


## Botão com visual próprio (normal / hover / pressionado / desativado) e "pulinho" ao passar o mouse
static func style_button(b: Button, accent: Color = Color(0.30, 0.34, 0.45)) -> void:
	b.add_theme_stylebox_override("normal", _button_box(accent.darkened(0.35), accent, 4))
	b.add_theme_stylebox_override("hover", _button_box(accent.darkened(0.1), accent.lightened(0.35), 5))
	b.add_theme_stylebox_override("pressed", _button_box(accent.darkened(0.55), accent, 0))
	b.add_theme_stylebox_override("focus", _button_box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.5), 0))
	b.add_theme_stylebox_override("disabled", _button_box(Color(0.15, 0.15, 0.18, 0.7), Color(1, 1, 1, 0.08), 0))
	b.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED_COLOR.darkened(0.2))
	b.add_theme_font_size_override("font_size", 18)
	outline(b, 18)
	b.mouse_entered.connect(_button_pop.bind(b, 1.06))
	b.mouse_exited.connect(_button_pop.bind(b, 1.0))
	b.pressed.connect(jelly.bind(b, 1.16, 0.5))   # clicou: balança como gelatina
	_hook_button_sfx(b)


## depth = espessura da "borda de baixo" (efeito almofada). Apertado (depth 0) o texto desce um pouco.
static func _button_box(bg: Color, border: Color, depth: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 2 + depth
	sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6 + (3 if depth == 0 else 0)
	sb.content_margin_bottom = 6 - (3 if depth == 0 else 0)
	return sb


## ---------- CARTÕES "PÍLULA" (visual dos menus) ----------

static func card_style(bg: Color = CARD_COLOR, radius: int = 30, depth: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = depth             # "espessura" do cartão, mais escura que o fundo
	sb.border_color = bg.darkened(0.28)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18 - depth * 0.5
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	return sb


## Botão grande e claro, texto escuro, que "afunda" ao apertar e balança ao clicar
static func style_card_button(b: Button, font_size: int = 30, bg: Color = CARD_COLOR) -> void:
	b.add_theme_stylebox_override("normal", card_style(bg))
	b.add_theme_stylebox_override("hover", card_style(bg.lerp(Color.WHITE, 0.35)))
	var pressed_sb: StyleBoxFlat = card_style(bg.darkened(0.08), 30, 2)
	pressed_sb.content_margin_top += 6.0
	pressed_sb.shadow_size = 6
	b.add_theme_stylebox_override("pressed", pressed_sb)
	b.add_theme_stylebox_override("focus", card_style(bg.lerp(Color.WHITE, 0.2)))
	b.add_theme_stylebox_override("disabled", card_style(bg.darkened(0.4)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, CARD_TEXT)
	b.add_theme_color_override("font_disabled_color", CARD_TEXT.lightened(0.5))
	b.add_theme_font_size_override("font_size", font_size)
	b.mouse_entered.connect(_button_pop.bind(b, 1.045))
	b.mouse_exited.connect(_button_pop.bind(b, 1.0))
	b.pressed.connect(jelly.bind(b, 1.2, 0.6))
	_hook_button_sfx(b)


## Balanço natural contínuo e suave (gira alguns décimos de grau, cada elemento em fase diferente).
## Usa só a ROTAÇÃO, então convive com o jelly() (que usa a escala). phase em 0..1.
static func alive(control: Control, phase: float = 0.0, rot_deg: float = 0.55, period: float = 3.8) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	if not control.has_meta("alive_pivot"):
		control.set_meta("alive_pivot", true)
		control.resized.connect(func() -> void:
			if is_instance_valid(control):
				control.pivot_offset = control.size * 0.5)
	if control.has_meta("alive_tween"):
		var old: Tween = control.get_meta("alive_tween") as Tween
		if old and old.is_valid():
			old.kill()
	var amp: float = deg_to_rad(rot_deg)
	var tw := control.create_tween().set_loops()
	tw.tween_interval(phase * period)
	tw.tween_property(control, "rotation", amp, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(control, "rotation", -amp, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	control.set_meta("alive_tween", tw)


## Gelatina em cascata: cada controle balança um pouquinho depois do anterior (a UI toda "responde")
static func jelly_chain(controls: Array, strength: float = 1.08, step: float = 0.045) -> void:
	for i in controls.size():
		var c: Control = controls[i] as Control
		if c == null or not is_instance_valid(c) or not c.is_inside_tree():
			continue
		if i == 0:
			jelly(c, strength, 0.55)
		else:
			c.get_tree().create_timer(step * i).timeout.connect(jelly.bind(c, strength, 0.55))


## Sons dos botões: passar o mouse (hover) e clicar. Todo botão estilizado pelo UiStyle ganha os dois.
static func _hook_button_sfx(b: Button) -> void:
	Sfx.ensure()
	b.mouse_entered.connect(_sfx_hover.bind(b))
	b.pressed.connect(_sfx_click)


static func _sfx_hover(b: Button) -> void:
	if not b.disabled:
		Sfx.play(&"ui_hover", 0.7, 0.03)


static func _sfx_click() -> void:
	Sfx.play(&"ui_click", 1.0, 0.03)


static func _button_pop(b: Button, target: float) -> void:
	if b.disabled:
		target = 1.0
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * target, 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## "Pulinho" de escala (usa o tamanho mínimo como pivô, serve para Labels e painéis centralizados)
static func pop(control: Control, from_scale: float = 1.35, time: float = 0.25) -> void:
	control.pivot_offset = control.get_combined_minimum_size() * 0.5
	control.scale = Vector2.ONE * from_scale
	var tw := control.create_tween()
	tw.tween_property(control, "scale", Vector2.ONE, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## ---------- GELATINA / BALANÇO ----------

## Efeito "gelatina" (squash & stretch): o controle dá um pulinho ao ser tocado. Não
## muda o layout — só a escala visual. Use em qualquer Control após uma interação.
static func jelly(control: Control, strength: float = 1.14, time: float = 0.55) -> void:
	if not is_instance_valid(control):
		return
	if control.pivot_offset == Vector2.ZERO:
		control.pivot_offset = control.size * 0.5
	if control.has_meta("jelly_tween"):
		var old: Tween = control.get_meta("jelly_tween") as Tween
		if old and old.is_valid():
			old.kill()
	var base: Vector2 = control.scale
	var tw := control.create_tween()
	tw.tween_property(control, "scale", Vector2(base.x * strength, base.y / strength), time * 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "scale", Vector2(base.x / strength, base.y * strength), time * 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "scale", base, time * 0.55) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	control.set_meta("jelly_tween", tw)


## Balanço natural contínuo (respiração suave). Chame uma vez; para parar use stop_sway.
## phase (0..1) desencontra o balanço entre vários elementos para não pulsarem juntos.
static func sway(control: Control, amplitude: float = 0.018, period: float = 3.4,
		phase: float = 0.0) -> void:
	if not is_instance_valid(control):
		return
	stop_sway(control)
	if control.pivot_offset == Vector2.ZERO:
		control.pivot_offset = control.size * 0.5
	var base: Vector2 = control.scale
	control.set_meta("sway_base", base)
	# Um pequeno "delay" inicial para as fases divergirem
	if phase > 0.0:
		var setup := control.create_tween()
		setup.tween_interval(phase * period)
		setup.tween_callback(_start_sway_loop.bind(control, base, amplitude, period))
		control.set_meta("sway_setup", setup)
	else:
		_start_sway_loop(control, base, amplitude, period)


static func _start_sway_loop(control: Control, base: Vector2, amplitude: float, period: float) -> void:
	if not is_instance_valid(control):
		return
	var tw := control.create_tween().set_loops()
	tw.tween_property(control, "scale", base * (1.0 + amplitude), period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(control, "scale", base * (1.0 - amplitude * 0.5), period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	control.set_meta("sway_tween", tw)


static func stop_sway(control: Control) -> void:
	if not is_instance_valid(control):
		return
	for meta in ["sway_tween", "sway_setup"]:
		if control.has_meta(meta):
			var tw: Tween = control.get_meta(meta) as Tween
			if tw and tw.is_valid():
				tw.kill()
			control.remove_meta(meta)
	if control.has_meta("sway_base"):
		control.scale = control.get_meta("sway_base") as Vector2
		control.remove_meta("sway_base")
