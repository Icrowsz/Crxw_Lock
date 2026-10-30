class_name ReactionWorld
extends ChemicalReaction
## Reação Química WORLD: Bachira X Otoya.
##
## COMO ACONTECE
## 1. O Bachira usa o BON (qualquer variante: Bon!, Bee Shot ou Monster Leap) com um Otoya do time dele em modo
##    FURTIVO (e a reação fora de recarga). O monstro do Bachira aparece MAIOR, com uma animação, e a bola sai
##    com a aura da reação (o Bachira guarda isso em last_bon["world"]).
## 2. Ninguém toca na bola e, NA MESMA RODADA, o Otoya (ainda furtivo) usa o Shuriken: ele vira o "GOTCHA":
##    cutscene + chute com força 2.1x, a bola sobe durante a trajetória (até Voando) e 75% de chance de gol,
##    acompanhado de um Shuriken gigante cortando o campo (find_partner confere tudo).
##
## Quem EXECUTA é o Otoya (trigger); o Bachira é o parceiro (partner), como no Weirdos (Charles + Shidou).
##
## NÃO precisa ser registrada no ReactionManager: o Otoya confere as condições aqui mesmo (find_partner) e só usa o
## ReactionManager.get_for(...).play(...) para tocar a cutscene. A recarga é controlada neste arquivo.
##
## Os números de balanceamento do chute (força, chance) ficam no Inspector do Otoya; o tamanho do monstro, no do Bachira.

## Recarga da reação (rodadas, por time). Fica aqui porque o Bachira precisa saber se a reação está pronta
## ANTES de existir uma instância (veja bon_target).
static var default_cooldown: int = 12

## Rodada em que cada time usou a reação (a recarga conta a partir dela)
static var _used_round: Dictionary = {}


func _init() -> void:
	id = &"world"
	display_name = "World"
	trigger_id = "otoya"
	partner_id = "bachira"
	cooldown_rounds = default_cooldown
	accent = Color(0.85, 1.0, 0.20)   # meio caminho entre o amarelo do Bachira e o verde limão do Otoya
	description = "Bon do Bachira com o Otoya furtivo: o Shuriken do Otoya vira o Gotcha."
	colors = {
		"bachira": Color(1.0, 0.85, 0.10),   # amarelo (como as labaredas dele)
		"otoya": Color(0.70, 1.0, 0.20),     # verde limão (como o furtivo dele)
	}
	_add_speaker("ego", "Ego", "res://img/rostinhos/ego.png", Color(0.27, 0.27, 0.27, 1.0))
	_say("bachira", "The monster is here!")
	_say("bachira", "Go-Go!")
	_say("otoya", "Can you see me, monster??")
	_say("ego", "That's the fire of those who believe to be the center of the world.")
	_say("otoya", "We are...")
	_say("bachira", "GODS!") 


## O Bachira acabou de usar o Bon: tem um Otoya do time dele em modo furtivo e a reação está pronta?
## Devolve esse Otoya (ou null). O Bachira guarda isso em last_bon["world"].
static func bon_target(bachira: Player) -> Player:
	if bachira == null or not ready_for(bachira.team, bachira.get_current_round()):
		return null
	for p: Player in bachira.get_tree().get_nodes_in_group("players"):
		if p.team != bachira.team or p.character_id != "otoya" or p.is_down:
			continue
		if p.has_method("is_stealth_active") and p.is_stealth_active():
			return p
	return null


## Devolve o BACHIRA se TODAS as condições estão cumpridas agora (senão null):
##  - o trigger é o Otoya, em modo furtivo, e a reação não está em recarga para o time dele;
##  - o Bachira fez o Bon NESTA rodada, armado para ESTE Otoya;
##  - ninguém tocou na bola depois do Bon.
## (Que o Otoya alcance a bola e o Shuriken esteja liberado, quem confere é o próprio Otoya.)
func find_partner(trigger: Player) -> Player:
	if trigger == null or trigger.character_id != trigger_id:
		return null
	if not trigger.has_method("is_stealth_active") or not trigger.is_stealth_active():
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
		var bon: Variant = p.get("last_bon")
		if not (bon is Dictionary) or (bon as Dictionary).is_empty():
			continue
		var info: Dictionary = bon
		if info.get("world") == trigger and int(info.get("round", -1)) == round_now \
				and int(info.get("touches", -1)) == ball.interaction_count:
			return p
	return null


## A reação está fora de recarga para este time? (versão sem instância; usa default_cooldown)
static func ready_for(team: int, round_now: int) -> bool:
	if not _used_round.has(team):
		return true
	var used: int = int(_used_round[team])
	if round_now < used:
		return true   # partida nova: a contagem de rodadas recomeçou
	return round_now - used >= default_cooldown


func is_ready(team: int, round_now: int) -> bool:
	return ready_for(team, round_now)


## Chame quando a reação for usada (começa a recarga)
func mark_used(team: int, round_now: int) -> void:
	_used_round[team] = round_now


## Rodadas que faltam para poder usar de novo (0 = disponível)
func rounds_left(team: int, round_now: int) -> int:
	if not _used_round.has(team) or round_now < int(_used_round[team]):
		return 0
	return maxi(0, default_cooldown - (round_now - int(_used_round[team])))
