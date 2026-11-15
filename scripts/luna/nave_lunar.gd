extends Node2D
## Pone en el mapa el módulo lunar de la nave que se eligió al inicio del juego
## (Mision.nave_elegida): Apollo 11, Artemis II o Gemini IV.
## Hijos esperados: Modulo (Sprite2D) y, opcional, Nombre (Label).

const RUTA := "res://assets/luna/modulo_%s.png"

@onready var modulo: Sprite2D = $Modulo
@onready var nombre: Label = get_node_or_null("Nombre")

var luz: ColorRect
var t := 0.0


func _ready() -> void:
	var id := LunaEstado.nave_id()
	var ruta := RUTA % id
	if ResourceLoader.exists(ruta):
		modulo.texture = load(ruta)
	if modulo.texture == null:
		return
	# Que la base del módulo quede justo en el origen del nodo
	modulo.centered = true
	modulo.offset = Vector2(0, -modulo.texture.get_height() / 2.0 + 2.0)
	if nombre:
		nombre.text = LunaEstado.nave_nombre()
	# Lucecita roja que parpadea en la punta del módulo
	luz = ColorRect.new()
	luz.color = Color("ff6b6b")
	luz.size = Vector2(2, 2)
	luz.position = modulo.position + Vector2(-1, -modulo.texture.get_height() + 1.0)
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(luz)


func _process(delta: float) -> void:
	t += delta
	if luz:
		luz.visible = int(t * 2.0) % 2 == 0
