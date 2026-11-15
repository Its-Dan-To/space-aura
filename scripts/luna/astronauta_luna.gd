# Astronauta de la Luna (copia de player.gd sin class_name, para no chocar con el del juego).
# Jugador top-down con solo dos animaciones mirando a la derecha (idleR y walkR).
# Al ir a la izquierda se refleja con flip_h, y al detenerse se queda
# mirando hacia el último lado al que caminó.
#
# Escena:
#   CharacterBody2D  ← este script va AQUÍ (en la raíz, no en el sprite)
#   ├── AnimatedSprite2D
#   ├── CollisionShape2D
#   └── InteractArea (Area2D, opcional por ahora)
#       └── CollisionShape2D
extends CharacterBody2D

signal interacted(player: CharacterBody2D)

@export_range(1, 2) var player_id: int = 1
@export var speed: float = 80.0
@export var idle_anim := "idleR"
@export var walk_anim := "walkR"

var can_move := true
var facing_left := false   # recuerda hacia dónde miró por última vez

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Controles de ambos jugadores. Si las acciones no existen en el InputMap,
# el jugador las crea solo (así funciona aunque no esté el autoload InputSetup).
const BINDINGS := {
	"p1_up": KEY_W, "p1_down": KEY_S, "p1_left": KEY_A, "p1_right": KEY_D, "p1_interact": KEY_E,
	"p2_up": KEY_UP, "p2_down": KEY_DOWN, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_interact": KEY_SHIFT,
}

static func _ensure_inputs() -> void:
	for action in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = BINDINGS[action]
		InputMap.action_add_event(action, ev)

func _ready() -> void:
	_ensure_inputs()
	add_to_group("players")   # para que las cámaras encuentren a los jugadores
	# Sin gravedad ni piso: movimiento libre en 8 direcciones (top-down).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	anim.play(idle_anim)

func _action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]

func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if can_move:
		dir = Input.get_vector(_action("left"), _action("right"), _action("up"), _action("down"))

	velocity = dir * speed
	move_and_slide()

	# Solo cambiamos el lado al que mira si hay movimiento horizontal.
	# Si camina solo arriba/abajo o se detiene, conserva el último lado.
	if dir.x < 0:
		facing_left = true
	elif dir.x > 0:
		facing_left = false
	anim.flip_h = facing_left

	var target := walk_anim if dir != Vector2.ZERO else idle_anim
	if anim.animation != target:
		anim.play(target)

	# ---------- Interacción (E / Shift) ----------
	# Se lee con Input (no con _unhandled_input) para que funcione
	# también dentro de la pantalla dividida (SubViewports).
	if can_move and Input.is_action_just_pressed(_action("interact")):
		interacted.emit(self)
		_interact_with_nearby()

func _interact_with_nearby() -> void:
	var area := get_node_or_null("InteractArea") as Area2D
	if area == null:
		return
	for a in area.get_overlapping_areas():
		if a.has_method("interact"):
			a.interact(self)
			return
	for b in area.get_overlapping_bodies():
		if b != self and b.has_method("interact"):
			b.interact(self)
			return
