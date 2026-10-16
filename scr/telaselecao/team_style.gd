class_name TeamStyle
extends RefCounted
## Nome, cor e ÍCONE (logo) de cada time. É daqui que o jogo inteiro (jogadores, goleiros,
## placar, menus) lê a identidade do time, para a escolha feita na tela de formação valer em
## todo lugar.
##
## Ícones: coloque as imagens (png, webp, jpg, jpeg ou svg) na pasta ICON_DIR. Elas aparecem
## sozinhas na escolha de ícone da tela de formação (o nome do arquivo vira o nome do ícone).
## Para mostrar o ícone no placar, na tela final etc., use o TeamBadge (team_badge.gd):
##     add_child(TeamBadge.make(team, 40))
## Ele já usa o ícone do time (ou um emblema com a inicial do nome) e se atualiza sozinho.
##
## Os valores escolhidos ficam guardados enquanto o jogo está aberto (inclusive se a cena
## for recarregada); ao fechar e abrir o jogo, volta tudo ao padrão.

const MAX_NAME_LENGTH: int = 16

## Cor padrão de cada time (índice = número do time)
const DEFAULT_COLORS: Array[Color] = [
	Color(0.9, 0.22, 0.27),   # Time 0: vermelho
	Color(0.11, 0.44, 0.88),  # Time 1: azul
]

## Cores prontas da formação (nenhuma verde, para não sumir no gramado). O jogador também pode
## escolher QUALQUER cor no seletor de cor personalizada.
const PALETTE: Array[Dictionary] = [
	{"name": "Vermelho", "color": Color(0.9, 0.22, 0.27)},
	{"name": "Vinho", "color": Color(0.55, 0.08, 0.20)},
	{"name": "Coral", "color": Color(0.98, 0.45, 0.40)},
	{"name": "Laranja", "color": Color(0.97, 0.52, 0.15)},
	{"name": "Amarelo", "color": Color(0.98, 0.82, 0.18)},
	{"name": "Dourado", "color": Color(0.85, 0.65, 0.12)},
	{"name": "Rosa", "color": Color(0.95, 0.45, 0.70)},
	{"name": "Magenta", "color": Color(0.85, 0.12, 0.60)},
	{"name": "Roxo", "color": Color(0.58, 0.33, 0.85)},
	{"name": "Índigo", "color": Color(0.30, 0.25, 0.75)},
	{"name": "Azul", "color": Color(0.11, 0.44, 0.88)},
	{"name": "Azul-marinho", "color": Color(0.08, 0.18, 0.45)},
	{"name": "Ciano", "color": Color(0.12, 0.78, 0.85)},
	{"name": "Marrom", "color": Color(0.45, 0.28, 0.16)},
	{"name": "Cinza", "color": Color(0.60, 0.62, 0.66)},
	{"name": "Grafite", "color": Color(0.16, 0.17, 0.20)},
	{"name": "Branco", "color": Color(0.96, 0.96, 0.96)},
]

## Pasta dos ícones dos times. Ajuste para onde estão as suas imagens.
const ICON_DIR: String = "res://img/logos/"
const ICON_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg", "svg"]

## Sobe a cada mudança (cor, nome, ícone): quem desenha a identidade do time (TeamBadge) compara
## este número para saber quando precisa redesenhar.
static var version: int = 0

static var _colors: Dictionary = {}   # time -> cor escolhida
static var _names: Dictionary = {}    # time -> nome escolhido
static var _icons: Dictionary = {}    # time -> id do ícone ("" ou ausente = emblema padrão)
static var _icon_list: Array[Dictionary] = []
static var _icon_list_loaded: bool = false
static var _icon_textures: Dictionary = {}   # id -> Texture2D


static func color_of(team: int) -> Color:
	if _colors.has(team):
		return _colors[team]
	return DEFAULT_COLORS[team % DEFAULT_COLORS.size()]


static func set_color(team: int, color: Color) -> void:
	_colors[team] = color
	version += 1


## Nome escolhido pelo jogador, ou "fallback" (o nome padrão do MatchManager) se não escolheu
static func name_of(team: int, fallback: String) -> String:
	return _names.get(team, fallback)


## Texto vazio = volta ao nome padrão
static func set_team_name(team: int, text: String) -> void:
	var clean: String = text.strip_edges()
	if clean == "":
		_names.erase(team)
	else:
		_names[team] = clean.substr(0, MAX_NAME_LENGTH)
	version += 1


## Há nome escolhido para este time? (a tela de formação usa para preencher o campo)
static func has_custom_name(team: int) -> bool:
	return _names.has(team)


# ---------- ÍCONE (LOGO) ----------

## Ícones encontrados em ICON_DIR: [{"id", "name", "path"}], em ordem alfabética.
## force_reload = true procura de novo (se você acabou de colocar imagens na pasta).
static func available_icons(force_reload: bool = false) -> Array[Dictionary]:
	if _icon_list_loaded and not force_reload:
		return _icon_list
	_icon_list = []
	_icon_textures.clear()
	var seen: Dictionary = {}
	var dir: DirAccess = DirAccess.open(ICON_DIR)
	if dir != null:
		for f in dir.get_files():
			var file: String = f
			# Em jogo exportado os arquivos aparecem como "x.png.import" / "x.png.remap"
			for suffix in [".import", ".remap"]:
				if file.ends_with(suffix):
					file = file.trim_suffix(suffix)
			if not ICON_EXTENSIONS.has(file.get_extension().to_lower()):
				continue
			var id: String = file.get_basename()
			if seen.has(id):
				continue
			seen[id] = true
			_icon_list.append({"id": id, "name": _pretty(id), "path": ICON_DIR + file})
	_icon_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"]))
	_icon_list_loaded = true
	return _icon_list


## "flame_wolves" -> "Flame wolves"
static func _pretty(id: String) -> String:
	var text: String = id.replace("_", " ").replace("-", " ").strip_edges()
	return text.substr(0, 1).to_upper() + text.substr(1)


static func icon_by_id(id: String) -> Texture2D:
	if id == "":
		return null
	if _icon_textures.has(id):
		return _icon_textures[id] as Texture2D
	for entry in available_icons():
		if entry["id"] == id:
			var tex := load(entry["path"]) as Texture2D
			_icon_textures[id] = tex
			return tex
	return null


## Id do ícone escolhido pelo time ("" = emblema padrão)
static func icon_id_of(team: int) -> String:
	return String(_icons.get(team, ""))


## Imagem do ícone do time (null = não escolheu: use o emblema padrão, veja TeamBadge)
static func icon_of(team: int) -> Texture2D:
	return icon_by_id(icon_id_of(team))


## id vazio = volta ao emblema padrão
static func set_icon(team: int, id: String) -> void:
	if id == "":
		_icons.erase(team)
	else:
		_icons[team] = id
	version += 1


# ---------- CORES: UTILIDADES ----------

## As duas cores são parecidas demais para distinguir dois times? (distância no RGB, 0 a ~1.7)
static func similar(a: Color, b: Color, tolerance: float = 0.25) -> bool:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < tolerance


## A cor é parecida com o verde do gramado (o jogador some no campo)?
static func is_grassy(color: Color) -> bool:
	return color.g > 0.35 and color.g > color.r * 1.2 and color.g > color.b * 1.2


## Cor viva aleatória (sem verde)
static func random_color() -> Color:
	for i in 20:
		var c: Color = Color.from_hsv(randf(), randf_range(0.55, 0.95), randf_range(0.7, 1.0))
		if not is_grassy(c):
			return c
	return DEFAULT_COLORS[0]
