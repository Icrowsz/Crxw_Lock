class_name FormationExtras
extends Node
## Extras da TELA DE FORMAÇÃO (formation_setup.gd), todos só visuais:
##
##  1. Painel "Campo" no menu da esquerda: HORÁRIO (Dia / Entardecer / Noite) e CLIMA
##     (Limpo / Chuva / Neblina / Neve). A escolha vale para a partida (veja field_atmosphere.gd)
##     e já tinge o campo em perspectiva da própria tela.
##  2. INDICADOR DE QUÍMICA: quando dois personagens do MESMO time formam uma Reação Química,
##     uma ligação brilhante na cor da reação aparece entre as bolinhas deles (com o nome da
##     reação), e o painel da esquerda lista os pares do time da vez. As reações são descobertas
##     sozinhas (chemistry_scan.gd): reação nova = nada para editar aqui.
##
## Como ligar: UMA linha no FormationSetup._ready(), logo depois de _build_ui():
##     FormationExtras.attach(self)
## O resto é por "duck typing": usa _left_col, _pitch, _team, manager e _big_panel do FormationSetup.

@export var show_atmosphere_panel: bool = true
@export var show_chemistry: bool = true
@export var link_width: float = 3.5

var host: Node
var _pitch: Control
var _links: _Links
var _atmo_panel: PanelContainer
var _chem_panel: PanelContainer
var _chem_box: VBoxContainer
var _time_buttons: Array[Button] = []
var _weather_buttons: Array[Button] = []
var _pairs: Array[Dictionary] = []
var _signature: String = ""
var _shown_team: int = -99
var _poll: float = 0.0


static func attach(setup: Node) -> FormationExtras:
	var e := FormationExtras.new()
	e.name = "FormationExtras"
	e.host = setup
	setup.add_child(e)
	return e


func _ready() -> void:
	var left := host.get("_left_col") as Control
	_pitch = host.get("_pitch") as Control
	var manager: Node = host.get("manager") as Node
	if manager != null:
		FieldAtmosphere.ensure(manager)   # o efeito vive na partida; aqui só escolhemos
	if show_atmosphere_panel and left != null:
		_build_atmosphere_panel(left)
	if show_chemistry:
		if left != null:
			_build_chemistry_panel(left)
		if _pitch != null:
			_links = _Links.new()
			_links.extras = self
			_links.pitch = _pitch
			_links.set_anchors_preset(Control.PRESET_FULL_RECT)
			_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pitch.add_child(_links)
	_apply_pitch_tint()
	_refresh_pairs(true)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.2
	_refresh_pairs(false)


# ---------- CLIMA E HORÁRIO ----------

func _build_atmosphere_panel(left: Control) -> void:
	_atmo_panel = PanelContainer.new()
	_style_panel(_atmo_panel)
	left.add_child(_atmo_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_atmo_panel.add_child(col)
	col.add_child(_title("Campo"))
	col.add_child(_caption("Horário"))
	col.add_child(_choice_row(FieldAtmosphere.TIME_NAMES, _time_buttons, _on_time))
	col.add_child(_caption("Clima"))
	col.add_child(_choice_row(FieldAtmosphere.WEATHER_NAMES, _weather_buttons, _on_weather))
	_mark_selected(_time_buttons, FieldAtmosphere.time_of_day)
	_mark_selected(_weather_buttons, FieldAtmosphere.weather)


func _choice_row(names: Array[String], store: Array[Button], on_pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(110.0, 44.0)
		UiStyle.style_button(b)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
		store.append(b)
	return row


func _on_time(i: int) -> void:
	FieldAtmosphere.set_time(i, self)
	_mark_selected(_time_buttons, i)
	_apply_pitch_tint()


func _on_weather(i: int) -> void:
	FieldAtmosphere.set_weather(i, self)
	_mark_selected(_weather_buttons, i)
	_apply_pitch_tint()


func _mark_selected(buttons: Array[Button], index: int) -> void:
	for i in buttons.size():
		var on: bool = i == index
		var accent: Color = UiStyle.ACCENT_COLOR if on else Color(0.30, 0.34, 0.45)
		buttons[i].add_theme_stylebox_override("normal", UiStyle._button_box(accent.darkened(0.45 if on else 0.35), accent, 4))
		buttons[i].add_theme_color_override("font_color", Color.WHITE if on else UiStyle.TEXT_COLOR)


## O campo em perspectiva da tela de formação ganha a cor do horário/clima escolhido
## (precisa da variável "tint" no _PerspectivePitch: veja as instruções)
func _apply_pitch_tint() -> void:
	if _pitch != null and "tint" in _pitch:
		_pitch.set("tint", FieldAtmosphere.pitch_tint())
	if _links != null:
		_links.queue_redraw()


# ---------- QUÍMICA ----------

func _build_chemistry_panel(left: Control) -> void:
	_chem_panel = PanelContainer.new()
	_style_panel(_chem_panel)
	_chem_panel.visible = false
	left.add_child(_chem_panel)
	_chem_box = VBoxContainer.new()
	_chem_box.add_theme_constant_override("separation", 8)
	_chem_panel.add_child(_chem_box)


func _all_team_players() -> Array[Array]:
	var out: Array[Array] = []
	var manager: Node = host.get("manager") as Node
	if manager == null:
		return out
	var count: int = int(manager.get("team_count"))
	for t in count:
		var list: Array = manager.call("get_team_players", t)
		out.append(list)
	return out


func _refresh_pairs(force: bool) -> void:
	var teams: Array[Array] = _all_team_players()
	var found: Array[Dictionary] = []
	var sig: String = ""
	for t in teams.size():
		for pr in ChemistryScan.pairs_in(teams[t], host.get("manager") as Node):
			pr["team"] = t
			found.append(pr)
			sig += "%d:%s:%d:%d|" % [t, String((pr["reaction"] as ChemicalReaction).id),
				(pr["trigger"] as Object).get_instance_id(), (pr["partner"] as Object).get_instance_id()]
	var team_now: int = int(host.get("_team"))
	sig += "t%d" % team_now
	if not force and sig == _signature:
		return
	_signature = sig
	_pairs = found
	if _links != null:
		_links.queue_redraw()
	_rebuild_list(team_now)


func _rebuild_list(team: int) -> void:
	if _chem_box == null:
		return
	for c in _chem_box.get_children():
		c.queue_free()
	var mine: Array[Dictionary] = []
	for pr in _pairs:
		if int(pr["team"]) == team:
			mine.append(pr)
	_chem_panel.visible = not mine.is_empty()
	if mine.is_empty():
		return
	_chem_box.add_child(_title("Química do time"))
	for pr in mine:
		var r: ChemicalReaction = pr["reaction"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_face(r.trigger_id, r.accent))
		var plus := UiStyle.make_label("+", 26, r.accent)
		row.add_child(plus)
		row.add_child(_face(r.partner_id, r.accent))
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := UiStyle.make_label(r.display_name.to_upper(), 22, r.accent.lightened(0.25))
		text.add_child(name_label)
		if r.description != "":
			var d := UiStyle.make_label(r.description, 14, UiStyle.MUTED_COLOR)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 160.0
			text.add_child(d)
		row.add_child(text)
		_chem_box.add_child(row)


func _face(character_id: String, border: Color) -> Control:
	var holder := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_border_width_all(3)
	sb.border_color = border
	sb.set_corner_radius_all(26)
	sb.set_content_margin_all(0)
	holder.add_theme_stylebox_override("panel", sb)
	holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	holder.custom_minimum_size = Vector2(52.0, 52.0)
	var tex := TextureRect.new()
	tex.texture = CharacterRoster.face_for(character_id)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.custom_minimum_size = Vector2(52.0, 52.0)
	holder.add_child(tex)
	return holder


# ---------- visual ----------

func _style_panel(panel: PanelContainer) -> void:
	if host.has_method("_big_panel"):
		host.call("_big_panel", panel)
	else:
		UiStyle.style_panel(panel)


func _title(text: String) -> Label:
	return UiStyle.make_label(text, 26, UiStyle.ACCENT_COLOR)


func _caption(text: String) -> Label:
	return UiStyle.make_label(text, 18, UiStyle.MUTED_COLOR)


## Desenha, em cima do campo em perspectiva, a ligação entre os dois personagens de cada química
class _Links extends Control:
	var extras: FormationExtras
	var pitch: Control
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if extras != null and not extras._pairs.is_empty():
			queue_redraw()

	func _draw() -> void:
		if extras == null or pitch == null or not pitch.has_method("_geometry"):
			return
		var editable: int = int(pitch.get("editable_team"))
		for pr in extras._pairs:
			var a := pr["trigger"] as Node2D
			var b := pr["partner"] as Node2D
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var r := pr["reaction"] as ChemicalReaction
			var mine: bool = int(pr["team"]) == editable
			var fade: float = 1.0 if mine else 0.4
			var ga: Dictionary = pitch.call("_geometry", a)
			var gb: Dictionary = pitch.call("_geometry", b)
			var ca: Vector2 = ga["center"]
			var cb: Vector2 = gb["center"]
			var ra: float = ga["r"]
			var rb: float = gb["r"]
			var pulse: float = 0.5 + 0.5 * sin(_t * 3.2)
			var col: Color = r.accent.lightened(0.2)

			# Anéis pulsando em volta das duas bolinhas
			draw_arc(ca, ra * (1.35 + 0.1 * pulse), 0.0, TAU, 32, Color(col, (0.5 + 0.4 * pulse) * fade), 3.0)
			draw_arc(cb, rb * (1.35 + 0.1 * pulse), 0.0, TAU, 32, Color(col, (0.5 + 0.4 * pulse) * fade), 3.0)

			# Ligação curva (sobe no meio) com brilho
			var mid: Vector2 = (ca + cb) * 0.5
			var lift: float = -clampf(ca.distance_to(cb) * 0.28, 14.0, 80.0)
			var ctrl: Vector2 = mid + Vector2(0.0, lift * 2.0)
			var pts := PackedVector2Array()
			for i in 25:
				var k: float = float(i) / 24.0
				pts.append(ca.lerp(ctrl, k).lerp(ctrl.lerp(cb, k), k))
			draw_polyline(pts, Color(col, 0.18 * fade), extras.link_width * 3.0, true)
			draw_polyline(pts, Color(col, 0.85 * fade), extras.link_width, true)
			# Faísca correndo pela ligação
			var spark_k: float = fposmod(_t * 0.6, 1.0)
			var sp: Vector2 = ca.lerp(ctrl, spark_k).lerp(ctrl.lerp(cb, spark_k), spark_k)
			draw_circle(sp, 5.0, Color(1, 1, 1, 0.9 * fade))

			# Estrelinha e nome no meio da ligação
			var top: Vector2 = ca.lerp(ctrl, 0.5).lerp(ctrl.lerp(cb, 0.5), 0.5)
			_star(top, 11.0 + 2.0 * pulse, Color(col, fade))
			var font: Font = ThemeDB.fallback_font
			var label: String = r.display_name.to_upper()
			var fs: int = 16
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var pos: Vector2 = top + Vector2(-w * 0.5, -18.0)
			draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.85 * fade))
			draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, fade))

	func _star(c: Vector2, radius: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			var a: float = TAU * float(i) / 8.0 - PI * 0.5
			var rr: float = radius if i % 2 == 0 else radius * 0.42
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, color)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.6 * color.a), 1.5)
