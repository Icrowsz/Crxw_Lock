class_name ReactionWeirdos
extends ChemicalReaction
## Reação Química WEIRDOS: Charles X Shidou.
##
## COMO ACONTECE
## 1. O Charles, com a Tricheur's Metavision ATIVA, faz um Rabona Cross cujo ponto de chegada fica perto do Shidou
##    (rabona_target). Nesse momento um demônio pequeno cobre o Charles e a bola sai com a aura da reação.
## 2. O Shidou usa o Demonic Rush até a bola (que paira Suspensa no ponto) e o Draconic Header vira "THE RESULT":
##    cutscene + um cabeceio (peixinho) com força 2.3x e 80% de chance de gol (find_partner confere tudo).
##
## Quem EXECUTA é o Shidou (trigger); o Charles é o parceiro (partner), como no Carnival (Shidou X Sae).
##
## NÃO precisa ser registrada no ReactionManager: o Shidou confere as condições aqui mesmo (find_partner) e só usa o
## ReactionManager.get_for(...).play(...) para tocar a cutscene. A recarga é controlada neste arquivo (mark_used / find_partner).
##
## Os números de balanceamento do chute (força, chance, tamanho do demônio) ficam no Inspector do Shidou e do Charles.

## Distância máxima (px) entre o ponto do Rabona e o Shidou para a reação ficar "armada"
static var target_radius: float = 200.0

## Rodada em que cada time usou a reação (a recarga conta a partir dela)
static var _used_round: Dictionary = {}


func _init() -> void:
	id = &"weirdos"
	display_name = "Weirdos"
	trigger_id = "shidou"
	partner_id = "charles"
	cooldown_rounds = 12
	accent = Color(1.0, 0.45, 0.65)   # meio caminho entre o rosa do Carnival e o dourado do Cruel
	description = "Rabona Cross do Charles (Metavision ativa) para o Shidou, que usa o Draconic Header: vira o The Result."
	colors = {
		"shidou": Color(1.0, 0.10, 0.60),    # rosa-choque (como no Carnival)
		"charles": Color(1.0, 0.85, 0.20),   # amarelo (como no Cruel)
	}
	_add_speaker("ego", "Ego", "res://img/rostinhos/ego.png", Color(0.27, 0.27, 0.27, 1.0))
	_say("charles", "Huh?! Somebody's there...")
	_say("charles", "...In my ultimate contrarian spot! ♪")
	_say("shidou", "Oh! For real? It came...")
	_say("shidou", "...To my ultimate feel-good spot!")
	_say("ego", "...The only goals possible...")
	_say("ego", "...Are those born from a collision peak performances.")


## O Charles (com a Metavision ativa) está mandando um Rabona para perto de um Shidou do time dele?
## Devolve o Shidou "alvo" (ou null). O Charles guarda isso em last_rabona["weirdos"].
static func rabona_target(charles: Player, landing: Vector2) -> Player:
	if charles == null or not charles.has_method("is_metavision_active") or not charles.is_metavision_active():
		return null
	var best: Player = null
	var best_dist: float = target_radius
	for p: Player in charles.get_tree().get_nodes_in_group("players"):
		if p.team != charles.team or p.character_id != "shidou" or p.is_down:
			continue
		var d: float = p.global_position.distance_to(landing)
		if d <= best_dist:
			best = p
			best_dist = d
	return best


## Devolve o CHARLES se TODAS as condições estão cumpridas agora (senão null):
##  - o trigger é o Shidou e a reação não está em recarga para o time dele;
##  - o Charles fez um Rabona Cross NESTA rodada, armado (Metavision ativa, ponto perto do Shidou) e para ESTE Shidou;
##  - ninguém tocou na bola depois do Rabona (ela ainda paira onde ele a deixou).
## (Que o Shidou esteja ao alcance da bola, no chão e com o Draconic Header liberado, quem confere é o próprio Shidou.)
func find_partner(trigger: Player) -> Player:
	if trigger == null or trigger.character_id != trigger_id:
		return null
	var round_now: int = trigger.get_current_round()
	if not is_ready(trigger.team, round_now):
		return null
	var ball: Ball = trigger._get_ball()
	if ball == null:
		return null
	for p: Player in trigger.get_tree().get_nodes_in_group("players"):
		if p.team != trigger.team or p.character_id != partner_id:
			continue
		var rabona: Variant = p.get("last_rabona")
		if not (rabona is Dictionary) or (rabona as Dictionary).is_empty():
			continue
		var info: Dictionary = rabona
		if info.get("weirdos") == trigger and int(info.get("round", -1)) == round_now \
				and int(info.get("touches", -1)) == ball.interaction_count:
			return p
	return null


## A reação está fora de recarga para este time?
func is_ready(team: int, round_now: int) -> bool:
	if not _used_round.has(team):
		return true
	var used: int = int(_used_round[team])
	if round_now < used:
		return true   # partida nova: a contagem de rodadas recomeçou
	return round_now - used >= cooldown_rounds


## Chame quando a reação for usada (começa a recarga)
func mark_used(team: int, round_now: int) -> void:
	_used_round[team] = round_now


## Rodadas que faltam para poder usar de novo (0 = disponível)
func rounds_left(team: int, round_now: int) -> int:
	if not _used_round.has(team) or round_now < int(_used_round[team]):
		return 0
	return maxi(0, cooldown_rounds - (round_now - int(_used_round[team])))
