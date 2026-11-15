extends Area2D
## Estación del mapa lunar que abre un minijuego.
## Cuando el astronauta está cerca y presiona E, entra al minijuego.
## Muestra un "!" mientras falta hacerlo y una palomita verde cuando ya se completó.
##
## Debe tener un CollisionShape2D hijo (la zona donde se puede interactuar).
## Si no lo tiene, se crea uno circular automáticamente.

@export var id_minijuego := "planetvac"
@export var titulo := "PlanetVac"
@export_file("*.tscn") var escena := ""
@export var radio_auto := 30.0
## Altura del letrero, para colocar encima el "!" y el texto.
@export var altura := 44.0

const RUTA_FUENTE := "res://fuentes/pixel.ttf"

var cerca := {}          # player_id -> nodo del jugador
var t := 0.0
var alerta: Sprite2D
var palomita: Sprite2D
var aviso: Label


func _ready() -> void:
	LunaEstado.asegurar_controles()
	add_to_group("estaciones_luna")
	monitoring = true
	if find_children("*", "CollisionShape2D", false, false).is_empty():
		var col := CollisionShape2D.new()
		var forma := CircleShape2D.new()
		forma.radius = radio_auto
		col.shape = forma
		add_child(col)
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)

	alerta = Sprite2D.new()
	alerta.texture = load("res://assets/luna/alerta.png")
	alerta.hframes = 2
	alerta.z_index = 20
	add_child(alerta)

	palomita = Sprite2D.new()
	palomita.texture = load("res://assets/luna/completado.png")
	palomita.position = Vector2(0, -altura - 8)
	palomita.z_index = 20
	add_child(palomita)

	aviso = Label.new()
	var fuente: Font = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font
	aviso.add_theme_font_override("font", fuente)
	aviso.add_theme_font_size_override("font_size", 8)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 3)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.size = Vector2(160, 12)
	aviso.position = Vector2(-80, 16)
	aviso.z_index = 20
	aviso.visible = false
	add_child(aviso)
	_refrescar()


func _refrescar() -> void:
	var hecho := LunaEstado.completado(id_minijuego)
	alerta.visible = not hecho
	palomita.visible = hecho


func _es_jugador(b: Node) -> bool:
	return b.is_in_group("players") or ("player_id" in b and b is CharacterBody2D)


func _al_entrar(b: Node) -> void:
	if _es_jugador(b):
		cerca[int(b.get("player_id"))] = b


func _al_salir(b: Node) -> void:
	if _es_jugador(b):
		cerca.erase(int(b.get("player_id")))


func _process(delta: float) -> void:
	t += delta
	alerta.frame = int(t * 3.0) % 2
	alerta.position = Vector2(0, -altura - 10 + sin(t * 4.0) * 2.0)
	aviso.visible = not cerca.is_empty()
	if aviso.visible:
		var accion := "Repetir" if LunaEstado.completado(id_minijuego) else "Entrar"
		aviso.text = "[E] %s: %s" % [accion, titulo]
		if Input.is_action_just_pressed("p1_interact"):
			_entrar()


func _entrar() -> void:
	if escena == "" or not ResourceLoader.exists(escena):
		push_error("[Luna] La estación '%s' no encuentra su escena: '%s'" % [id_minijuego, escena])
		aviso.text = "Falta la escena del minijuego"
		return
	set_process(false)
	# Recordar dónde estaban los astronautas para regresarlos ahí (un poco abajo del letrero)
	for p in get_tree().get_nodes_in_group("players"):
		LunaEstado.posiciones[int(p.get("player_id"))] = (p as Node2D).global_position + Vector2(0, 10)
	LunaEstado.escena_mapa = get_tree().current_scene.scene_file_path
	LunaEstado.estacion_activa = id_minijuego
	get_tree().change_scene_to_file.call_deferred(escena)
