class_name ReactionSacrifice
extends ChemicalReaction
## SACRIFICE (Karasu + Hiori). Recarga: 12 rodadas (a definição não dizia: ajuste à vontade).
##
## Condições (todas ao mesmo tempo):
##  1. O Karasu fez um passe (qualquer um: comum, Aerial Pass, Raven Assault...) para o Hiori;
##  2. DEPOIS desse passe, o Karasu usou o Wings Block e ainda está segurando algum inimigo;
##  3. O Hiori está com a Coldest Metavision ativa, no lado do ATAQUE (onde existe o Cryo Shot),
##     com a bola ao alcance (no chão ou Suspensa) e é o turno do time deles;
##  4. Ninguém tocou na bola depois do passe.
##
## Efeito: o botão do Cryo Shot do Hiori vira "Loud Crow". Se ele MIRAR NO KARASU, roda a cutscene e
## o chute sai mais forte, com 90% de chance de gol; a bola ignora a colisão do Karasu e dos
## inimigos (passa por cima deles). Se ele mirar para outro lado, sai o Cryo Shot normal e a
## reação NÃO é gasta. A parte do chute está no hiori.gd (_use_cryo_shot / _ghost_flight); o registro
## do passe e do Wings Block está no karasu.gd (last_pass_info); os efeitos de gelo, vidro e asas
## estão no sacrifice_fx.gd. Aqui ficam só os dados e as condições.


func _init() -> void:
	id = &"sacrifice"
	display_name = "Sacrifice"
	trigger_id = "hiori"         # quem executa o movimento (o chute)
	partner_id = "karasu"        # quem passou e segura os inimigos
	cooldown_rounds = 12
	accent = Color(0.62, 0.35, 1.0)   # roxo do Karasu
	description = "Reação Química com o Karasu: o Cryo Shot vira o Loud Crow."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/sacrifice.ogv"
	colors = {
		"karasu": Color(0.55, 0.25, 0.85),   # roxo de corvo
		"hiori": Color(0.55, 0.85, 1.0),     # azul gelo
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_add_speaker("ego", "Ego", "res://img/rostinhos/ego.png", Color(0.27, 0.27, 0.27, 1.0))
	_say("karasu", "Shoot dammit.")
	_say("ego", "The path to victory lies in self-sacrifice.")
	_say("karasu", "Aim for...")
	_say("karasu", "...My head.")
	_say("hiori", "I'm trustin' ya, extraordinary...")


func find_partner(trigger: Player) -> Player:
	var hiori := trigger as Hiori
	if hiori == null:
		return null

	var m: MatchManager = hiori._get_manager()
	var ball: Ball = hiori._get_ball()
	if m == null or ball == null or m.match_over or m.current_team != hiori.team:
		return null

	# Metavision ativa e lado do ataque (o Cryo Shot só existe aí); bola livre e ao alcance
	if not hiori.is_metavision_active() or hiori._is_on_defense_side():
		return null
	if ball.is_held() or ball.is_locked_for(hiori.team):
		return null
	var kind: Player.KickType = hiori.get_kick_type(ball)
	if kind != Player.KickType.GROUND and kind != Player.KickType.VOLLEY \
			and kind != Player.KickType.HIGH_BALL:
		return null

	for p: Player in m.get_team_players(hiori.team):
		var karasu := p as Karasu
		if karasu == null or karasu.is_down:
			continue
		# 1) O último passe dele foi para o Hiori, e 2) o Wings Block veio DEPOIS e ainda segura alguém
		var info: Dictionary = karasu.last_pass_info
		if info.is_empty() or info.get("target") != hiori or not bool(info.get("wings", false)):
			continue
		if not karasu.is_grabbing():
			continue
		# 4) Ninguém tocou na bola depois do passe
		if int(info.get("touches", -1)) != ball.interaction_count:
			continue
		if ball.last_toucher != karasu and ball.last_toucher != hiori:
			continue
		return karasu
	return null
