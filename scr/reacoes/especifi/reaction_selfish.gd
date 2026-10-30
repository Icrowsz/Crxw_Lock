class_name ReactionSelfish
extends ChemicalReaction
## Reação Química SELFISH: Aiku X Sae.
##
## COMO ACONTECE
## 1. O Sae, com a ULTRA VISION ATIVA, usa o PERFECT PASS para o Aiku e a bola CHEGA SUSPENSA nele (o estado de chegada
##    escolhido no painel do Perfect Pass). Durante a trajetória do passe, números rosas e pretos acompanham a bola.
##    O Sae anota isso em last_perfect_pass (com "level" e "uv").
## 2. Ninguém toca na bola e, NA MESMA RODADA, o Aiku usa o SNAKE LUNGE: ele vira o "STRIKER": cutscene + chute com força
##    2.0x, a bola sobe durante a trajetória (até Voando) e 75% de chance de gol, e uma serpente sai do chute do Aiku e
##    acompanha a bola (find_partner confere tudo).
##
## Quem EXECUTA é o Aiku (trigger); o Sae é o parceiro (partner), como no Weirdos (Charles + Shidou).
##
## NÃO precisa ser registrada no ReactionManager: o Aiku confere as condições aqui mesmo (find_partner) e só usa o
## ReactionManager.get_for(...).play(...) para tocar a cutscene. A recarga é controlada neste arquivo.
##
## Os números do chute (força, chance) ficam no Inspector do Aiku.

## Recarga da reação (rodadas, por time). Fica aqui porque o Sae precisa saber se a reação está pronta
## ANTES de existir uma instância (veja pass_armed).
static var default_cooldown: int = 12

## Rodada em que cada time usou a reação (a recarga conta a partir dela)
static var _used_round: Dictionary = {}


func _init() -> void:
	id = &"selfish"
	display_name = "Selfish"
	trigger_id = "aiku"
	partner_id = "sae"
	cooldown_rounds = default_cooldown
	accent = Color(1.0, 0.10, 0.60)   # rosa-choque (o do Sae); o verde-veneno do Aiku aparece na cobra
	description = "Perfect Pass suspenso do Sae (Ultra Vision) no Aiku: o Snake Lunge vira o Striker."
	colors = {
		"sae": Color(1.0, 0.10, 0.60),       # rosa-choque
		"aiku": Color(0.55, 0.85, 0.15),     # verde-veneno
	}
	_say("sae", "Nice sense of smell...")
	_say("sae", "...Selfish captain.")
	_say("aiku", "Sorry, but I...")
	_say("aiku", "...Used to be a striker, after all.")
	_say("aiku", "This is the end, FOR YOU!")


## O Sae está passando para o Aiku nas condições da Selfish? (Ultra Vision ativa, bola chegando SUSPENSA, reação pronta)
## O Sae usa isto para mostrar os números rosas e pretos durante o passe.
static func pass_armed(sae: Player, target: Player, level: int) -> bool:
	if sae == null or target == null or target.team != sae.team or target.character_id != "aiku":
		return false
	if level != Heights.Level.SUSPENDED:
		return false
	if not sae.has_method("_uv_active") or not sae.call("_uv_active"):
		return false
	return ready_for(sae.team, sae.get_current_round())


## Devolve o SAE se TODAS as condições estão cumpridas agora (senão null):
##  - o trigger é o Aiku e a reação não está em recarga para o time dele;
##  - o Sae fez o Perfect Pass NESTA rodada para ESTE Aiku, com a Ultra Vision ativa e a bola chegando SUSPENSA;
##  - ninguém tocou na bola depois do passe e ela continua suspensa.
## (Que o Aiku alcance a bola, quem confere é o próprio Aiku.)
func find_partner(trigger: Player) -> Player:
	if trigger == null or trigger.character_id != trigger_id:
		return null
	var round_now: int = trigger.get_current_round()
	if not is_ready(trigger.team, round_now):
		return null
	var ball: Ball = trigger._get_ball()
	if ball == null or ball.get_level() != Heights.Level.SUSPENDED:
		return null
	for p: Player in trigger.get_tree().get_nodes_in_group("players"):
		if p.team != trigger.team or p.character_id != partner_id:
			continue
		var raw: Variant = p.get("last_perfect_pass")
		if not (raw is Dictionary) or (raw as Dictionary).is_empty():
			continue
		var info: Dictionary = raw
		if info.get("target") == trigger and int(info.get("round", -1)) == round_now \
				and int(info.get("touches", -1)) == ball.interaction_count \
				and int(info.get("level", -1)) == Heights.Level.SUSPENDED \
				and bool(info.get("uv", false)):
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
