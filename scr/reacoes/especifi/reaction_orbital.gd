class_name ReactionOrbital
extends ChemicalReaction
## ORBITAL RESONANCE; Kurona X Isagi. Quem executa o movimento (trigger) é o ISAGI (é ele que chuta);
## o parceiro é o Kurona (deu o passe). Efeito: o Backheel Shot do Isagi vira o DOMINATION (veja isagi.gd).

func _init() -> void:
	id = &"orbital"
	display_name = "Orbital Resonance"
	trigger_id = "isagi"
	partner_id = "kurona"
	cooldown_rounds = 12
	accent = Color(0.45, 0.55, 1.0)   # azul do Isagi (o rosa do Kurona aparece nos efeitos)
	description = "Reação com o Kurona: com o Underwater sobre o Isagi e o passe do Moon/Satellite, o Backheel Shot vira o Domination."

	video_path = ""
	colors = {
		"isagi": Color(0.25, 0.5, 1.0),
		"kurona": Color(0.93, 0.42, 0.66),
	}

	_say("kurona", "I've decided...")
	_say("kurona", "...To follow you, Isagi.")
	_say("isagi", "This is our orbital resonance!!")
	_say("kurona", "Domination...")
	_say("kurona", "Domination...")
	_say("isagi", "Let's dominate.")


## Condições (TODAS): o efeito UNDERWATER do Kurona está sobre o Isagi; o Kurona usou o Moon ou o Satellite
## passando para o Isagi (o Kurona grava isso em Isagi.get_meta("orbital_pass") quando o passe chega, veja
## kurona.gd), na mesma rodada e sem ninguém de fora da dupla tocar na bola depois; é o turno do time deles; e o
## Isagi está na situação do Backheel Shot (os dois no chão, a bola ao alcance).
## Quem confere isto é o próprio Isagi, ANTES do chute.
func find_partner(trigger: Player) -> Player:
	var isagi := trigger as Isagi
	if isagi == null:
		return null

	var m: MatchManager = isagi._get_manager()
	var ball: Ball = isagi._get_ball()
	if m == null or ball == null or m.current_team != isagi.team:
		return null

	# 1) O Isagi está na situação do Backheel Shot (que a reação transforma)
	if isagi.get_shot_variant() != Isagi.ShotVariant.BACKHEEL:
		return null

	# 2) O Kurona passou para ele nesta rodada (Moon ou Satellite)
	var info: Dictionary = isagi.get_meta("orbital_pass", {}) as Dictionary
	var kurona := info.get("kurona") as Kurona
	if kurona == null or not is_instance_valid(kurona) or kurona.is_down:
		return null
	if int(info.get("round", -1)) != m.round_number:
		return null

	# 3) O Underwater do Kurona continua sobre o Isagi
	if not kurona._uw_active or kurona._uw_partner != isagi or not kurona._uw_valid():
		return null

	# 4) Ninguém de fora da dupla tocou na bola depois do passe (não dá para contar toques: a bola encostada
	#    no Isagi soma um toque a cada quadro)
	var last: Player = ball.last_toucher
	if last != null and last != kurona and last != isagi:
		return null
	return kurona
