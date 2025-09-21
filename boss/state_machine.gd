extends Node2D
class_name StateMachine

var current_state: BossState
var states: Dictionary = {}
var boss

func _ready():
	# Alt state'leri topla
	for child in get_children():
		if child is BossState:
			states[child.name] = child

func init(boss_ref):
	boss = boss_ref
	
	# Tüm state'lere boss referansını ver
	for state in states.values():
		state.init(boss_ref, self)
	
	# İlk state'i başlat
	change_state("IdleState")

func process_frame(delta: float):
	if current_state:
		current_state.process_frame(delta)

func change_state(state_name: String):
	if current_state:
		current_state.exit()
	
	current_state = states.get(state_name)
	if current_state:
		current_state.enter()
