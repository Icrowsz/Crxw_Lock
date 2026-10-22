class_name KickSpinPicker
extends CanvasLayer
## Telinha do "Chutar": a bola aparece grande no centro e o jogador clica no PONTO dela que quer acertar.
## Quanto mais longe do centro, mais efeito (centro = chute reto):
##   lado esquerdo/direito = curva (esquerda da bola curva para a direita e vice-versa; canhoto espelha)
##   embaixo = a bola sobe (meio caminho = Suspensa, borda de baixo = Voando, e fica mais tempo no ar)
##   em cima = a bola desce e vai menos longe
## Efeito gasta alcance: chute com curva, subida ou descida vai sempre menos longe que o reto (ver Player.spin_power_mult).
## A imagem da bola é ampliada para a parte visível dela preencher o círculo todo (o clique vale dentro do círculo).
## Tem um cronômetro; se acabar o tempo sem clicar, a bola vai reta. Mostra também o pé dominante.
##
## Quem abre é o MatchManager (ação geral Chutar, depois da mira e do QTE):
##     var point: Vector2 = await KickSpinPicker.new().pick(actor, ball, 5.0)
## O ponto (x e y de -1 a 1, y para baixo) vira actor.pending_spin_point, que o Player.kick_ball() gasta.
## Toda a regra (curva, subida, perda de força, espelho do canhoto) fica no Player: aqui só se escolhe o ponto.

signal chosen(point: Vector2)

## Tamanho da telinha: a área da bola ocupa quase toda a altura da janela (no máximo MAX_AREA_H px)
const MAX_AREA_H: float = 620.0
const MIN_AREA_H: float = 380.0
const CHROME_H: float = 230.0   # altura de tudo que não é a área da bola (título, nome do efeito, cronômetro, margens)

var _actor: Player
var _left_footed: bool = false
var _time_total: float = 5.0
var _time_left: float = 5.0
var _done: bool = false
var _tex: Texture2D
var _tex_src: Rect2 = Rect2()   # parte visível da imagem da bola (sem a margem transparente)
var _ball: Ball
var _kind: Player.KickType = Player.KickType.GROUND

var _panel: PanelContainer
var _area: _BallArea
var _name_label: Label
var _time_label: Label
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat


## Abre a telinha e espera a escolha. Devolve o ponto da bola (Vector2.ZERO = centro = reta, se o tempo acabar).
func pick(actor: Player, ball: Ball, seconds: float = 5.0) -> Vector2:
	_actor = actor
	_left_footed = actor != null and actor.dominant_foot == Player.Foot.LEFT
	_time_total = maxf(seconds, 0.5)
	_time_left = _time_total
	_ball = ball
	if actor != null and ball != null:
		_kind = actor.get_kick_type(ball)
		if _kind == Player.KickType.NONE:
			_kind = Player.KickType.GROUND
	if ball != null and ball.sprite != null:
		_tex = ball.sprite.texture
		_tex_src = _visible_rect(_tex)
	layer = 9   # acima do menu de ações, abaixo das telas grandes (formação, pausa)
	_build()
	var result: Vector2 = await chosen
	queue_free()
	return result


# ---------- DESCRIÇÃO DO EFEITO ----------

static func _word(amount: float) -> String:
	if amount < 0.34:
		return "leve"
	if amount < 0.67:
		return "média"
	return "forte"


## Texto do que o ponto escolhido faz com a bola
func describe(point: Vector2) -> String:
	if _actor == null:
		return "Reta"
	var curve: float = _actor.spin_curve_amount(point)
	var rise: float = _actor.spin_rise_amount(point)
	var down: float = _actor.spin_down_amount(point)
	var parts: Array[String] = []
	if absf(curve) > 0.0:
		parts.append("Curva %s para a %s" % [_word(absf(curve)), "direita" if curve > 0.0 else "esquerda"])
	if rise > 0.0:
		parts.append("sobe %s (%s)" % [_word(rise), Heights.level_name(Heights.from_height(peak_height(point)))])
	if down > 0.0:
		parts.append("desce, %s" % ("bem menos alcance" if down >= 0.67 else "menos alcance"))
	if parts.is_empty():
		return "Reta"
	return " · ".join(parts)


## Retângulo da imagem que tem a bola de verdade (sem a margem transparente), para ela poder
## preencher o círculo. Sem alfa ou sem como ler a imagem, usa a imagem toda.
func _visible_rect(t: Texture2D) -> Rect2:
	if t == null:
		return Rect2()
	var whole: Rect2 = Rect2(Vector2.ZERO, t.get_size())
	var img: Image = t.get_image()
	if img == null or img.is_empty():
		return whole
	if img.is_compressed():
		if img.decompress() != OK:
			return whole
	var used: Rect2i = img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return whole
	return Rect2(used)


## Altura máxima do arco com esse ponto (a mesma conta do Player.kick_ball)
func peak_height(point: Vector2) -> float:
	if _actor == null or _ball == null:
		return 0.0
	return _actor.spin_peak_height(point, _ball, _kind)


## Tempo no ar com esse ponto: Vector2(subida, descida) em segundos
func air_times(point: Vector2) -> Vector2:
	if _actor == null or _ball == null:
		return Vector2.ZERO
	return _actor.spin_air_times(point, _ball, _kind)


## Para onde cada lado da bola curva (o texto das bordas muda com o pé dominante)
func side_word(left_side: bool) -> String:
	if _actor == null:
		return ""
	var curve: float = _actor.spin_curve_amount(Vector2(-1.0 if left_side else 1.0, 0.0))
	return "direita" if curve > 0.0 else "esquerda"


# ---------- MONTAGEM DA TELA ----------

func _build() -> void:
	# Fundo escuro que também segura os cliques (nada do jogo recebe o clique enquanto a telinha está aberta)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	UiStyle.style_panel(_panel, Color(UiStyle.ACCENT_COLOR, 0.55))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Linha de cima: pé dominante | título | tempo
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	vbox.add_child(top_row)

	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 10)
	foot_row.custom_minimum_size = Vector2(210.0, 0.0)
	top_row.add_child(foot_row)
	var icon := _FootIcon.new()
	icon.left_footed = _left_footed
	icon.custom_minimum_size = Vector2(84.0, 56.0)
	foot_row.add_child(icon)
	var foot_box := VBoxContainer.new()
	foot_box.add_theme_constant_override("separation", 0)
	foot_row.add_child(foot_box)
	var who: String = _actor.display_name if _actor != null else ""
	foot_box.add_child(UiStyle.make_label(who if who != "" else "Pé dominante", 16, UiStyle.MUTED_COLOR))
	foot_box.add_child(UiStyle.make_label("Pé esquerdo" if _left_footed else "Pé direito", 28))

	var title: Label = UiStyle.make_label("Onde você vai acertar a bola?", 28, UiStyle.ACCENT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)

	_time_label = UiStyle.make_label("", 28, UiStyle.MUTED_COLOR)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.custom_minimum_size = Vector2(210.0, 0.0)
	top_row.add_child(_time_label)

	# A bola: ocupa a altura que sobra na janela
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	var area_h: float = clampf(viewport_h - CHROME_H, MIN_AREA_H, MAX_AREA_H)
	_area = _BallArea.new()
	_area.picker = self
	_area.tex = _tex
	_area.tex_src = _tex_src
	_area.ball_radius = area_h * 0.39
	_area.custom_minimum_size = Vector2(area_h * 1.4, area_h)
	_area.point_hovered.connect(_on_point_hovered)
	_area.point_clicked.connect(_on_point_clicked)
	vbox.add_child(_area)

	# O que o ponto escolhido faz (e quanto alcance sobra)
	_name_label = UiStyle.make_label("Reta", 26)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size = Vector2(0.0, 36.0)
	vbox.add_child(_name_label)

	# Cronômetro
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = _time_total
	_bar.value = _time_total
	_bar.custom_minimum_size = Vector2(0.0, 14.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(7)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = UiStyle.ACCENT_COLOR
	_bar_fill.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	vbox.add_child(_bar)

	var hint: Label = UiStyle.make_label(
		"Clique no ponto da bola que quer acertar: mais perto do centro = menos efeito. Sem escolher, a bola vai reta.",
		15, UiStyle.MUTED_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	_on_point_hovered(Vector2.INF)
	_open_anim.call_deferred()


## A telinha "abre" balançando como gelatina (espera um quadro: o tamanho só é conhecido depois do layout)
func _open_anim() -> void:
	await get_tree().process_frame
	if _panel == null or not is_instance_valid(_panel):
		return
	_panel.pivot_offset = _panel.size * 0.5
	UiStyle.jelly(_panel, 1.06, 0.55)


# ---------- LOOP ----------

func _process(delta: float) -> void:
	if _done:
		return
	if _actor == null or not is_instance_valid(_actor):
		_finish(Vector2.ZERO)
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finish(Vector2.ZERO)   # acabou o tempo: reta
		return
	_bar.value = _time_left
	_time_label.text = "%.1f s" % _time_left
	# Amarelo -> vermelho nos últimos 2 segundos
	var urgency: float = clampf(1.0 - _time_left / 2.0, 0.0, 1.0)
	_bar_fill.bg_color = UiStyle.ACCENT_COLOR.lerp(UiStyle.BAD_COLOR, urgency)
	_time_label.add_theme_color_override("font_color", UiStyle.MUTED_COLOR.lerp(UiStyle.BAD_COLOR, urgency))


func _unhandled_key_input(event: InputEvent) -> void:
	# Atalho: Enter / Espaço = reta
	if _done or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
		_finish(Vector2.ZERO)


## point = Vector2.INF quando o mouse não está sobre a bola
func _on_point_hovered(point: Vector2) -> void:
	if _done:
		return
	_name_label.text = _effect_text(point)


## "Curva média para a direita · sobe leve · Alcance 78%" (sem ponto = reta, alcance total)
func _effect_text(point: Vector2) -> String:
	if point == Vector2.INF or _actor == null:
		return "Reta · Alcance 100%"
	var text: String = "%s · Alcance %d%%" % [describe(point), int(round(_actor.spin_power_mult(point) * 100.0))]
	if _actor.spin_rise_amount(point) > 0.0:
		var t: Vector2 = air_times(point)
		text += " · No ar %.1f s" % (t.x + t.y)
	return text


func _on_point_clicked(point: Vector2) -> void:
	_finish(point)


## Fecha: mostra o ponto escolhido piscando um instante e devolve o ponto
func _finish(point: Vector2) -> void:
	if _done:
		return
	_done = true
	_name_label.text = _effect_text(point)
	_area.flash(point)
	await get_tree().create_timer(0.3).timeout
	chosen.emit(point)


# ---------- ÁREA DA BOLA (desenho + mouse) ----------

class _BallArea extends Control:
	signal point_hovered(point: Vector2)
	signal point_clicked(point: Vector2)

	var picker: KickSpinPicker
	var tex: Texture2D
	var tex_src: Rect2 = Rect2()
	var ball_radius: float = 235.0
	var _point: Vector2 = Vector2.INF      # ponto sob o mouse (fração do raio; INF = fora da bola)
	var _flash_point: Vector2 = Vector2.INF
	var _flash_t: float = 0.0
	var _locked: bool = false
	var _ret_scale: float = 1.0            # mola do alvo (efeito de gelatina)
	var _ret_vel: float = 0.0
	var _smooth_point: Vector2 = Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(_on_mouse_exited)

	func _on_mouse_exited() -> void:
		if _locked or _point == Vector2.INF:
			return
		_point = Vector2.INF
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		point_hovered.emit(Vector2.INF)

	func flash(point: Vector2) -> void:
		_locked = true
		_flash_point = point
		_flash_t = 0.0
		_point = point
		_ret_vel += 6.0   # o alvo "estoura" ao clicar

	func _ball_center() -> Vector2:
		return size * 0.5

	func _to_point(p: Vector2) -> Vector2:
		return (p - _ball_center()) / ball_radius

	func _process(delta: float) -> void:
		# O alvo segue o mouse com um pouquinho de suavidade
		if _point != Vector2.INF:
			_smooth_point = _smooth_point.lerp(_point, 1.0 - exp(-24.0 * delta))
		# Mola amortecida: o alvo balança quando aparece / quando clica
		var target: float = 1.0 if _point != Vector2.INF else 0.0
		_ret_vel += (target - _ret_scale) * 300.0 * delta
		_ret_vel *= exp(-9.0 * delta)
		_ret_scale += _ret_vel * delta
		if _flash_point != Vector2.INF:
			_flash_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if _locked:
			return
		if event is InputEventMouseMotion:
			var p: Vector2 = _to_point((event as InputEventMouseMotion).position)
			if p.length() <= 1.0:
				if _point == Vector2.INF:
					_smooth_point = p
				_point = p
				mouse_default_cursor_shape = Control.CURSOR_CROSS
				point_hovered.emit(p)
			elif _point != Vector2.INF:
				_point = Vector2.INF
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				point_hovered.emit(Vector2.INF)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var p2: Vector2 = _to_point((event as InputEventMouseButton).position)
			if p2.length() <= 1.0:
				point_clicked.emit(p2)

	func _draw() -> void:
		var c: Vector2 = _ball_center()
		var r: float = ball_radius
		var accent: Color = UiStyle.ACCENT_COLOR
		var font: Font = ThemeDB.fallback_font

		# Brilho atrás da bola
		draw_circle(c, r + 26.0, Color(accent, 0.06))
		draw_circle(c, r + 14.0, Color(accent, 0.11))
		# Sombra no chão
		draw_set_transform(c + Vector2(0.0, r + 14.0), 0.0, Vector2(1.0, 0.2))
		draw_circle(Vector2.ZERO, r * 0.85, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# A bola: a imagem do próprio jogo (ou uma bola desenhada, se não tiver)
		if tex != null:
			# A parte visível da bola preenche o círculo todo (a margem transparente da imagem fica de fora)
			var src: Rect2 = tex_src if tex_src.size.x > 0.0 else Rect2(Vector2.ZERO, tex.get_size())
			var fit: float = (r * 2.0) / maxf(src.size.x, src.size.y)
			var dest_size: Vector2 = src.size * fit
			draw_texture_rect_region(tex, Rect2(c - dest_size * 0.5, dest_size), src)
		else:
			_draw_fallback_ball(c, r)
		draw_arc(c, r, 0.0, TAU, 96, Color(1, 1, 1, 0.3), 2.0)

		# Guias bem fraquinhas: cruz no centro e anéis (centro = sem efeito)
		var guide: Color = Color(0.0, 0.0, 0.0, 0.28)
		draw_line(c + Vector2(-r, 0.0), c + Vector2(r, 0.0), guide, 1.5)
		draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, r), guide, 1.5)
		draw_arc(c, r * 0.34, 0.0, TAU, 48, guide, 1.5)
		draw_arc(c, r * 0.67, 0.0, TAU, 64, guide, 1.5)

		# Texto nas bordas: o que cada lado faz (muda com o pé dominante)
		var label_color: Color = Color(1, 1, 1, 0.8)
		var gap: float = 14.0
		var side_w: float = (size.x - r * 2.0) * 0.5 - gap
		_text(font, "Desce · menos alcance", Vector2(c.x, c.y - r - gap), size.x, HORIZONTAL_ALIGNMENT_CENTER, 20, label_color, true)
		_text(font, "Sobe · mais alta e mais tempo no ar", Vector2(c.x, c.y + r + gap + 18.0), size.x, HORIZONTAL_ALIGNMENT_CENTER, 20, label_color, true)
		_text(font, "Curva para\na %s" % picker.side_word(true), Vector2(gap * 0.5, c.y - 10.0), side_w,
			HORIZONTAL_ALIGNMENT_CENTER, 20, label_color, false)
		_text(font, "Curva para\na %s" % picker.side_word(false), Vector2(c.x + r + gap * 0.5, c.y - 10.0), side_w,
			HORIZONTAL_ALIGNMENT_CENTER, 20, label_color, false)

		_draw_height_preview(c, r, font)

		# O alvo: onde o jogador vai acertar a bola
		if _point != Vector2.INF and _ret_scale > 0.02:
			var pos: Vector2 = c + _smooth_point * r
			var flashing: bool = _flash_point != Vector2.INF
			var ring: Color = accent
			var s: float = _ret_scale
			if flashing:
				var pulse: float = 0.5 + 0.5 * sin(_flash_t * 30.0)
				ring = Color(1, 1, 1).lerp(accent, pulse)
			# Linha fininha do centro até o ponto (mostra o "tamanho" do efeito)
			draw_line(c, pos, Color(accent, 0.55), 2.0)
			draw_circle(pos, 26.0 * s + 3.0, Color(0, 0, 0, 0.35))
			draw_circle(pos, 22.0 * s, Color(accent, 0.28))
			draw_arc(pos, 22.0 * s, 0.0, TAU, 32, ring, 4.0)
			draw_circle(pos, 6.0 * s, ring)
		# Centro marcado
		draw_circle(c, 3.0, Color(0, 0, 0, 0.45))

	## Caixinha de lado no canto: o arco que a bola vai fazer com o ponto sob o mouse
	## (linhas do Chão / Suspensa / Voando) e quanto tempo ela fica no ar
	func _draw_height_preview(c: Vector2, r: float, font: Font) -> void:
		var pt: Vector2 = _smooth_point if _point != Vector2.INF else Vector2.ZERO
		var w: float = minf(maxf(size.x - (c.x + r) - 30.0, 96.0), 230.0)
		var h: float = w * 0.8
		var box: Rect2 = Rect2(Vector2(size.x - w - 14.0, 14.0), Vector2(w, h))
		draw_rect(box, Color(0, 0, 0, 0.34))
		draw_rect(box, Color(1, 1, 1, 0.16), false, 1.5)

		var pad: float = 8.0
		var ground_y: float = box.end.y - pad - 14.0
		var top: float = box.position.y + pad + 4.0
		var scale: float = (ground_y - top) / (Heights.FLYING_HEIGHT * 1.15)
		var x0: float = box.position.x + pad
		var x1: float = box.end.x - pad
		var accent: Color = UiStyle.ACCENT_COLOR
		var faint: Color = Color(1, 1, 1, 0.22)

		# Linhas dos níveis
		draw_line(Vector2(x0, ground_y), Vector2(x1, ground_y), Color(1, 1, 1, 0.55), 2.0)
		draw_dashed_line(Vector2(x0, ground_y - Heights.SUSPENDED_HEIGHT * scale), Vector2(x1, ground_y - Heights.SUSPENDED_HEIGHT * scale), faint, 1.5, 6.0)
		draw_dashed_line(Vector2(x0, ground_y - Heights.FLYING_HEIGHT * scale), Vector2(x1, ground_y - Heights.FLYING_HEIGHT * scale), faint, 1.5, 6.0)
		var fs: int = 12
		draw_string(font, Vector2(x0 + 2.0, ground_y - Heights.SUSPENDED_HEIGHT * scale - 3.0), "Suspensa", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(x0 + 2.0, ground_y - Heights.FLYING_HEIGHT * scale - 3.0), "Voando", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.6))

		# O arco: sobe até o pico e desce (a proporção subida/descida vem do tempo de voo real)
		var peak: float = picker.peak_height(pt)
		var times: Vector2 = picker.air_times(pt)
		var total: float = maxf(times.x + times.y, 0.001)
		var ta: float = clampf(times.x / total, 0.05, 0.95)
		var start_h: float = 0.0
		if picker._ball != null:
			start_h = picker._ball.height
		var span: float = (x1 - x0) * 0.92
		var pts := PackedVector2Array()
		var steps: int = 28
		for i in steps + 1:
			var t: float = float(i) / float(steps)
			var hgt: float
			if t <= ta:
				var u: float = 1.0 - t / ta
				hgt = start_h + (peak - start_h) * (1.0 - u * u)
			else:
				var d: float = (t - ta) / (1.0 - ta)
				hgt = peak * (1.0 - d * d)
			pts.append(Vector2(x0 + 4.0 + span * t, ground_y - hgt * scale))
		draw_polyline(pts, Color(accent, 0.9), 3.0, true)
		# Bolinha no pico + tempo no ar
		var apex: Vector2 = Vector2(x0 + 4.0 + span * ta, ground_y - peak * scale)
		draw_circle(apex, 5.0, Color.WHITE)
		var air: String = "Reta" if peak <= start_h + 1.0 else "No ar %.1f s" % total
		draw_string(font, Vector2(x0, box.end.y - 6.0), air, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 13, Color(1, 1, 1, 0.85))

	func _text(font: Font, text: String, pos: Vector2, width: float, align: int, font_size: int,
			color: Color, centered_at_x: bool) -> void:
		var origin: Vector2 = pos
		if centered_at_x:
			origin.x = pos.x - width * 0.5
		var outline: Color = Color(0, 0, 0, 0.85)
		draw_multiline_string_outline(font, origin, text, align, width, font_size, -1, 5, outline)
		draw_multiline_string(font, origin, text, align, width, font_size, -1, color)

	func _draw_fallback_ball(c: Vector2, r: float) -> void:
		draw_circle(c, r, Color(0.96, 0.96, 0.96))
		draw_circle(c, r * 0.34, Color(0.1, 0.1, 0.1))
		for i in 5:
			var a: float = TAU * float(i) / 5.0 - PI * 0.5
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.82, r * 0.16, Color(0.1, 0.1, 0.1))


# ---------- ÍCONE DO PÉ ----------

class _FootIcon extends Control:
	var left_footed: bool = false

	func _draw() -> void:
		# Uma chuteira de lado; o pé esquerdo é o espelho do direito
		var c: Vector2 = size * 0.5
		var m: float = -1.0 if left_footed else 1.0
		var pts := PackedVector2Array()
		for p: Vector2 in [Vector2(-30, 8), Vector2(-30, -19), Vector2(-11, -24), Vector2(3, -11),
				Vector2(27, -3), Vector2(35, 11), Vector2(24, 18), Vector2(-25, 18)]:
			pts.append(c + Vector2(p.x * m, p.y))
		draw_colored_polygon(pts, UiStyle.ACCENT_COLOR)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.1, 0.1, 0.8), 2.5)
		# Travas na sola
		for i in 4:
			var x: float = -20.0 + 15.0 * float(i)
			draw_line(c + Vector2(x * m, 18), c + Vector2(x * m, 25), Color(1, 1, 1, 0.9), 4.0)
