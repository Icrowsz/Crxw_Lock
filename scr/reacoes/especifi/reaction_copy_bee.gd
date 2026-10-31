class_name ReactionCopyBee
extends ChemicalReaction

func _init() -> void:
	id = &"copy_bee"
	display_name = "Copy-Bee"
	trigger_id = "reo"
	partner_id = "bachira"
	cooldown_rounds = 12
	accent = Color(0.65, 0.3, 0.95)
	description = "Reação com o Bachira: o Step Overs copiado libera o Model: Panther."
	
	video_path = ""
	colors = {
		"reo": Color(0.65, 0.3, 0.95),
		"bachira": Color(1.0, 0.85, 0.2),
	}
	
	_say("bachira", "Let's go! Buzz, Buzz!")
	_say("bachira", "Double-Bachira formation!!!")
	_say("reo", "Copy...")
	_say("reo", "...And change.")
	_say("reo", "I'll win... BY MYSELF.")

func find_partner(trigger: Player) -> Player:
	# Verifica pelo ID em vez de usar "as Reo" para evitar erro de dependência circular
	if trigger == null or trigger.character_id != "reo":
		return null
	
	# Pega a habilidade copiada dinamicamente
	if trigger.get("_copy_skill_id") != &"step_overs":
		return null
		
	var m := trigger._get_manager()
	if m == null: return null
	
	for p in m.get_team_players(trigger.team):
		if p.character_id == "bachira":
			return p
			
	return null
