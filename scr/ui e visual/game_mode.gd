class_name GameMode
extends RefCounted
## Modo de jogo escolhido no menu inicial (main_menu.gd) e o que ele liga na partida.
##
## - "Jogar": partida normal (a tela de formação abre antes de começar).
## - "Modo treino": partida de teste. Sem formação, sem fim de jogo, e o painel de debug (training_mode.gd) na tela.
##
## Quem usa: o MatchManager chama GameMode.apply_to(self) UMA vez, no começo do _setup().
## Se o jogo for aberto direto pela cena Main (F6, sem passar pelo menu), nada muda: vale o que está no Inspector.
## Os status do topo (status_hud.gd) aparecem nos dois modos (desligue com GameMode.show_status_hud = false).

## true = o jogo foi aberto pelo menu inicial (aí o menu manda se tem formação ou não)
static var from_menu: bool = false
static var training: bool = false

## Opções do modo treino (o painel muda isto na hora)
static var no_cooldowns: bool = true       # recargas desativadas
static var infinite_actions: bool = true   # ações sempre sobrando (o turno não acaba sozinho)

static var show_status_hud: bool = true

## FUTEBOL MEDONHO: 11 por time (10 na linha + o goleiro), campo gigante e mais ações por turno.
## Só vale quando o menu inicial escolhe esse modo; o jogo normal nunca mexe nisso.
static var medonho: bool = false
const MEDONHO_PLAYERS: int = 10   # jogadores de LINHA por time; o goleiro (criado pelo Field) faz o 11º
const MEDONHO_PITCH_SIZE := Vector2(3800.0, 2150.0)
const MEDONHO_PROTAGONIST_GENERAL: int = 5
const MEDONHO_PROTAGONIST_SKILL: int = 2
const MEDONHO_SECONDARY_GENERAL: int = 11
const MEDONHO_SECONDARY_SKILL: int = 4
const MEDONHO_RESERVES: int = 7     # personagens no banco de cada time
const MEDONHO_MAX_SUBS: int = 6     # substituições por time na partida inteira

## Caminho da cena do menu inicial (o MainMenu preenche); o botão "Menu inicial" do treino volta para ela
static var menu_scene: String = ""


## Chamado pelo menu: começa uma partida normal ou de treino
static func start(is_training: bool, is_medonho: bool = false) -> void:
	from_menu = true
	training = is_training
	medonho = is_medonho and not is_training
	no_cooldowns = true
	infinite_actions = true
	BenchManager.apply_mode_limits()   # banco maior no Medonho


## Volta ao estado "aberto direto pela cena Main"
static func reset() -> void:
	from_menu = false
	training = false
	medonho = false
	BenchManager.apply_mode_limits()


## Futebol Medonho: ações maiores e 10 jogadores de linha + goleiro por time (o campo grande é montado pelo próprio Field)
static func _apply_medonho(m: MatchManager) -> void:
	m.protagonist_general_actions = MEDONHO_PROTAGONIST_GENERAL
	m.protagonist_skill_actions = MEDONHO_PROTAGONIST_SKILL
	m.secondary_general_actions = MEDONHO_SECONDARY_GENERAL
	m.secondary_skill_actions = MEDONHO_SECONDARY_SKILL
	_spawn_medonho_players(m)


## Completa cada time até MEDONHO_PLAYERS clonando um jogador que já está na cena
## e já posiciona todo mundo na primeira formação do modo.
static func _spawn_medonho_players(m: MatchManager) -> void:
	var field := m.get_tree().get_first_node_in_group("field") as Field
	if field == null:
		push_warning("GameMode: Field não encontrado; Futebol Medonho sem jogadores extras.")
		return
	var used_ids: Dictionary = {}
	for p: Player in m.get_tree().get_nodes_in_group("players"):
		used_ids[p.character_id] = true

	for t in m.team_count:
		var team_players: Array[Player] = m.get_team_players(t)
		if team_players.is_empty():
			continue
		var template: Player = team_players[0]
		while team_players.size() < MEDONHO_PLAYERS:
			var clone := template.duplicate() as Player
			clone.team = t
			template.get_parent().add_child(clone)
			clone.add_to_group("players")
			team_players.append(clone)
		# Personagens diferentes nos clones (se o replace_player falhar, o clone fica como está)
		var pool: Array = CharacterRoster.available().duplicate()
		pool.shuffle()
		for i in range(1, team_players.size()):
			var cur: Player = team_players[i]
			if cur.character_id != template.character_id and not used_ids.has(cur.character_id):
				continue
			for entry in pool:
				var id: String = String(entry["id"])
				if used_ids.has(id):
					continue
				var fresh: Player = CharacterRoster.replace_player(cur, id)
				if fresh != null:
					team_players[i] = fresh
					used_ids[id] = true
				break
		# Posição inicial: primeira formação do modo
		var slots: Array[Vector2] = Formations.slots(Formations.presets_for(MEDONHO_PLAYERS)[0], t, field)
		var assigned: Dictionary = Formations.assign(team_players, slots)
		for key in assigned:
			(key as Player).global_position = assigned[key]
			(key as Player).home_position = assigned[key]


## O MatchManager chama no começo do _setup(), antes de decidir se abre a tela de formação.
static func apply_to(m: MatchManager) -> void:
	if from_menu:
		m.use_formation_setup = not training
	if medonho:
		_apply_medonho(m)
	if training:
		# Treino não acaba: nem por gols, nem por tempo
		m.goals_to_win = 99999
		m.rounds_per_half = 99999
		m.extra_time_rounds = 99999
		if m.get_node_or_null("TrainingMode") == null:
			var panel := TrainingMode.new()
			panel.name = "TrainingMode"
			panel.manager = m
			m.add_child(panel)
	FieldAtmosphere.ensure(m)   # clima e horário escolhidos na tela de formação
	if show_status_hud and m.get_node_or_null("StatusHud") == null:
		var hud := StatusHud.new()
		hud.name = "StatusHud"
		hud.manager = m
		m.add_child(hud)
