extends Node
class_name BossState

var boss
var state_machine: StateMachine
var state_timer: float = 0.0

func init(boss_ref, sm_ref: StateMachine):
	boss = boss_ref
	state_machine = sm_ref

func enter():
	state_timer = 0.0

func exit():
	pass

func process_frame(delta: float):
	state_timer += delta
