class_name ReactionHerbivicus
extends ChemicalReaction
## HERBIVICUS (Ness + Kaiser). Recarga: 12 rodadas.
##
## Condições (todas ao mesmo tempo):
##  1. O Ness está sob o efeito do Garçom do Empire do Kaiser (é o Servo Garçom dele);
##  2. O Ness usou o Alohomora no Kaiser NESTE turno e ninguém tocou na bola depois;
##  3. Tem um inimigo perto do Kaiser (ENEMY_RANGE);
##  4. O Kaiser usa o Kaiser Impact (ele suspenso + bola suspensa). O botão vira "Emperor Impact".
##
## Efeito: cutscene + diálogo e o Kaiser Impact sai como Emperor Impact: mais forte e rápido,
## com 75% de chance de gol e uma rosa azul translúcida gigante no momento do chute. O Alohomora
## do Ness que cumpre as condições já sai brilhando muito mais (veja is_pass_charged).
## A parte do chute e dos efeitos está no kaiser.gd (_use_shot_skill) e no herbivicus_fx.gd;
## aqui ficam só os dados e as condições.

## Distância máxima (em pixels) do Kaiser até um inimigo para a reação valer
const ENEMY_RANGE: float = 250.0


func _init() -> void:
	id = &"herbivicus"
	display_name = "Herbivicus"
	trigger_id = "kaiser"
	partner_id = "ness"
	cooldown_rounds = 12
	accent = Color(0.25, 0.55, 1.0)   # azul da rosa
	description = "Reação Química com o Ness: o Kaiser Impact vira o Emperor Impact."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/herbivicus.ogv"
	colors = {
		"ness": Color(1.0, 0.45, 0.85),     # rosa mágico
		"kaiser": Color(0.15, 0.35, 1.0),   # azul imperial
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_say("ness", "Okay, Kaiser.")
	_say("ness", "Public execution it is.")
	_say("base", "The magician will always have your back.")
	_say("kaiser", "Kniet nieder, ihr Knechte.")
	_say("kaiser", "Executed.")


func find_partner(trigger: Player) -> Player:
	var kaiser := trigger as Kaiser
	if kaiser == null:
		return null
	var m: MatchManager = kaiser._get_manager()
	var ball: Ball = kaiser._get_ball()
	if m == null or ball == null:
		return null

	# 3) Tem um inimigo perto do Kaiser
	if not has_enemy_near(kaiser):
		return null

	for p: Player in m.get_team_players(kaiser.team):
		var ness := p as Ness
		# 1) O Ness é o Servo Garçom do Empire do Kaiser
		if ness == null or not kaiser.is_waiter(ness):
			continue

		# 2) O último Alohomora do Ness foi neste turno, para o Kaiser, e a bola não foi tocada depois
		var ap: Dictionary = ness.last_alohomora_pass
		if ap.is_empty():
			continue
		if ap.get("target") != kaiser or int(ap.get("round", -1)) != m.round_number:
			continue
		if int(ap.get("touches", -1)) != ball.interaction_count or ball.last_toucher != ness:
			continue
		return ness

	# 4) (Kaiser suspenso + bola suspensa) é conferido pelo próprio Kaiser: só aí o botão é o Emperor Impact
	return null


## Tem algum inimigo perto do Kaiser?
static func has_enemy_near(kaiser: Kaiser) -> bool:
	for other: Player in kaiser.get_tree().get_nodes_in_group("players"):
		if other.team == kaiser.team:
			continue
		if kaiser.global_position.distance_to(other.global_position) <= ENEMY_RANGE:
			return true
	return false


## O Ness usa isto no Alohomora: este passe cumpre as condições da reação (Garçom do Kaiser,
## inimigo perto e reação fora de recarga)? Se sim, o passe sai brilhando muito mais.
static func is_pass_charged(ness: Ness, target: Player) -> bool:
	var kaiser := target as Kaiser
	if kaiser == null or not kaiser.is_waiter(ness):
		return false
	if not has_enemy_near(kaiser):
		return false
	var rm: ReactionManager = ReactionManager.get_for(ness)
	if rm == null:
		return false
	for reaction in rm.reactions:
		if reaction is ReactionHerbivicus:
			return rm.is_ready(reaction, ness.team)
	return false
