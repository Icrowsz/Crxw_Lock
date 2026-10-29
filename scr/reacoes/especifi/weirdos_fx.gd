class_name WeirdosFX
extends RefCounted
## Efeitos visuais da reação WEIRDOS (Charles + Shidou): a MISTURA do Carnival (rosa-choque, dragão, números) com o
## Cruel (dourado/azul, demônio do Charles, círculo mágico), com o demônio MENOR que o do Cruel.
##
## Este arquivo não cria desenhos novos: reaproveita o que já existe (CruelFX.GiantDemon, CruelFX.MagicCircle,
## CruelFX.sparkle_burst, CarnivalFX...), então herda a mesma otimização deles (desenho único, nada redesenha por quadro).
##
##  - summon_small_demon(): o demônio do Charles em tamanho reduzido, com as cores misturadas (corpo violeta escuro,
##    contorno dourado, olhos e brilho rosa) e um círculo mágico dourado/rosa atrás;
##  - rabona_armed(): no Rabona Cross que arma a reação: halo dourado/azul na bola + brilhos rosa;
##  - result_burst(): no instante do cabeceio do The Result: brilhos rosa e dourados, clarão e tremida.
## Quem chama passa um nó que já esteja na árvore (ex: self) em "from".

const GOLD: Color = Color(1.0, 0.85, 0.2)
const PINK: Color = Color(1.0, 0.10, 0.60)
const PINK_LIGHT: Color = Color(1.0, 0.65, 0.85)
const ROYAL: Color = Color(0.2, 0.5, 1.0)
const VIOLET_DEEP: Color = Color(0.10, 0.02, 0.18)

## Tamanho do demônio do Cruel (summon_charles_demon): serve de referência para o círculo mágico acompanhar o tamanho
const CRUEL_DEMON_SIZE: float = 430.0


## O demônio do Charles, menor que o do Cruel. "ground" = onde a pessoa pisa (global); "body_height" = altura dela.
static func summon_small_demon(from: Node, ground: Vector2, body_height: float, size: float = 250.0) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var center: Vector2 = ground + Vector2(0.0, -body_height)
	var k: float = size / CRUEL_DEMON_SIZE   # quanto menor que o do Cruel
	var parent: Node = CruelFX._ground_parent(from)

	var demon := CruelFX.GiantDemon.new()
	demon.size = size
	demon.horned = true
	demon.body_col = VIOLET_DEEP
	demon.edge_col = GOLD
	demon.eye_col = PINK_LIGHT
	demon.glow_col = PINK
	demon.horn_col = Color(0.95, 0.75, 0.35)
	parent.add_child(demon)
	demon.global_position = center
	demon.z_index = int(ground.y) - 3   # atrás de quem está na frente, como no Cruel

	var circle := CruelFX.MagicCircle.new()
	circle.vertical = true
	circle.radius = 140.0 * k
	circle.main = GOLD
	circle.alt = PINK
	circle.life = 2.0
	parent.add_child(circle)
	circle.global_position = center + Vector2(0.0, -20.0 * k)
	circle.z_index = int(ground.y) - 2

	CruelFX.sparkle_burst(from, center, GOLD, 18, 220.0, 0.6, 0.9)
	CruelFX.sparkle_burst(from, center, PINK, 18, 200.0, 0.55, 0.9)
	CruelFX.flash(from, PINK_LIGHT, 0.18, 0.4)
	CruelFX.shake(from, 5.0, 0.5)


## O Rabona Cross que ARMA a reação: halo dourado/azul que segue a bola enquanto ela paira + brilhos rosa
static func rabona_armed(from: Node, ball: Ball, pos: Vector2) -> void:
	if ball == null:
		return
	CruelFX.attach_ball_aura(ball, CruelFX.Style.RABONA)
	CruelFX.sparkle_burst(from, pos, PINK, 16, 260.0, 0.55, 0.9)
	CruelFX.sparkle_burst(from, pos, GOLD, 14, 220.0, 0.5, 0.9)
	CruelFX.shake(from, 4.0, 0.3)


## No instante do cabeceio do The Result
static func result_burst(from: Node, pos: Vector2) -> void:
	CruelFX.sparkle_burst(from, pos, PINK, 26, 300.0, 0.6, 1.0)
	CruelFX.sparkle_burst(from, pos, GOLD, 20, 260.0, 0.5, 1.0)
	CruelFX.sparkle_burst(from, pos, ROYAL, 12, 200.0, 0.45, 0.9)
	CruelFX.flash(from, PINK_LIGHT, 0.22, 0.45)
