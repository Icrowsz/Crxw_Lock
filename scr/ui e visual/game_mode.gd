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

## Caminho da cena do menu inicial (o MainMenu preenche); o botão "Menu inicial" do treino volta para ela
static var menu_scene: String = ""


## Chamado pelo menu: começa uma partida normal ou de treino
static func start(is_training: bool) -> void:
	from_menu = true
	training = is_training
	no_cooldowns = true
	infinite_actions = true


## Volta ao estado "aberto direto pela cena Main"
static func reset() -> void:
	from_menu = false
	training = false


## O MatchManager chama no começo do _setup(), antes de decidir se abre a tela de formação.
static func apply_to(m: MatchManager) -> void:
	if from_menu:
		m.use_formation_setup = not training
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
	if show_status_hud and m.get_node_or_null("StatusHud") == null:
		var hud := StatusHud.new()
		hud.name = "StatusHud"
		hud.manager = m
		m.add_child(hud)
