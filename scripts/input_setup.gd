# Autoload: registra los controles de ambos jugadores al iniciar el juego.
# Así nadie del equipo tiene que configurarlos a mano en Project Settings
# (y se evitan conflictos de git en project.godot).
extends Node

const BINDINGS := {
	# Jugador 1: WASD + E
	"p1_up": KEY_W,
	"p1_down": KEY_S,
	"p1_left": KEY_A,
	"p1_right": KEY_D,
	"p1_interact": KEY_E,
	# Jugador 2: flechas + Shift
	"p2_up": KEY_UP,
	"p2_down": KEY_DOWN,
	"p2_left": KEY_LEFT,
	"p2_right": KEY_RIGHT,
	"p2_interact": KEY_SHIFT,
}

func _ready() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		# physical_keycode = posición física de la tecla (funciona igual en teclado español o inglés)
		ev.physical_keycode = BINDINGS[action]
		InputMap.action_add_event(action, ev)
