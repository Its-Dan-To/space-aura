extends Node
## Cerebro del mapa de la Luna. Ponlo como hijo de la escena del mapa (Luna.tscn).
##  - Recuerda la escena del mapa para regresar desde los minijuegos.
##  - Regresa al astronauta donde estaba antes de entrar a un minijuego.
##  - Muestra el panel "MISIONES EN LA LUNA" con las estaciones completadas.
##  - Cuando se completan todas, muestra "¡BASE LUNAR OPERATIVA!".

## Si se activa, ordena por profundidad TODA la escena del mapa (pone el suelo
## en z_index -1). Normalmente no hace falta: BaseLunar ya ordena sus cosas.
@export var ordenar_profundidad := false
## Escena a la que se pasa al terminar las 3 estaciones (vacío = solo mostrar el mensaje).
@export_file("*.tscn") var escena_al_terminar := "res://scenes/AterrizajeTierra/AterrizajeTierra.tscn"
## Si en el mapa no hay astronauta, lo crea junto a la nave.
@export var crear_jugadores_si_faltan := true
## Si en el mapa no hay cámara, crea una que sigue al astronauta.
@export var crear_camara_si_falta := true
@export var zoom_camara := 1.0

const ANCHO := 480.0
const ALTO := 270.0
const RUTA_FUENTE := "res://fuentes/pixel.ttf"

var ui: CanvasLayer
var fuente: Font
var lbl_lista: Label
var panel_final: Control
var todo_listo := false
var camara: Camera2D


func _ready() -> void:
	LunaEstado.asegurar_controles()
	var escena := get_tree().current_scene
	if escena and escena.scene_file_path != "":
		LunaEstado.escena_mapa = escena.scene_file_path
	if ordenar_profundidad and escena is Node2D:
		_ordenar(escena)
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font
	_crear_hud()
	get_viewport().size_changed.connect(_ajustar_escala)
	_ajustar_escala()
	# Esperar a que los jugadores estén listos antes de moverlos
	await get_tree().process_frame
	if crear_jugadores_si_faltan:
		_crear_jugadores()
	_restaurar_posiciones()
	if crear_camara_si_falta:
		_crear_camara()
	_refrescar()


func _crear_jugadores() -> void:
	var existentes := {}
	for p in get_tree().get_nodes_in_group("players"):
		existentes[int(p.get("player_id"))] = true
	var origen: Vector2 = (get_parent() as Node2D).global_position if get_parent() is Node2D else Vector2.ZERO
	if existentes.has(1):
		return
	var escena := LunaEstado.escena_jugador(1)
	if escena == null:
		push_warning("[Luna] No encontré la escena del jugador (res://scenes/Player.tscn).")
		return
	var j := escena.instantiate() as Node2D
	j.set("player_id", 1)
	get_tree().current_scene.add_child(j)
	j.global_position = origen + Vector2(-24, 48)


func _crear_camara() -> void:
	var vp := get_viewport()
	if vp.get_camera_2d() != null:
		return
	camara = Camera2D.new()
	camara.zoom = Vector2(zoom_camara, zoom_camara)
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 5.0
	get_tree().current_scene.add_child(camara)
	camara.make_current()
	_seguir_jugadores()
	camara.reset_smoothing()


func _seguir_jugadores() -> void:
	var lista := get_tree().get_nodes_in_group("players")
	if lista.is_empty():
		return
	var centro := Vector2.ZERO
	for p in lista:
		centro += (p as Node2D).global_position
	camara.global_position = centro / lista.size()


func _ordenar(escena: Node2D) -> void:
	escena.y_sort_enabled = true
	for c in escena.get_children():
		if (c is TileMap or c is TileMapLayer) and c.z_index == 0:
			c.z_index = -1


func _restaurar_posiciones() -> void:
	if LunaEstado.posiciones.is_empty():
		return
	for p in get_tree().get_nodes_in_group("players"):
		var pid := int(p.get("player_id"))
		if LunaEstado.posiciones.has(pid):
			(p as Node2D).global_position = LunaEstado.posiciones[pid]
	LunaEstado.posiciones = {}


func _ajustar_escala() -> void:
	var vp := get_viewport().get_visible_rect().size
	var f := maxf(1.0, floorf(minf(vp.x / ANCHO, vp.y / ALTO)))
	ui.scale = Vector2(f, f)


func _etiqueta(padre: Node, pos: Vector2, color: Color, ancho := 0.0) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos
	if ancho > 0.0:
		l.size.x = ancho
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	padre.add_child(l)
	return l


func _caja(padre: Node, r: Rect2, borde: Color) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.85)
	sb.border_color = borde
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(p)


func _crear_hud() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_caja(ui, Rect2(4, 4, 150, 62), Color("ffcd75"))
	var cab := _etiqueta(ui, Vector2(10, 7), Color("ffcd75"))
	cab.text = "BASE LUNAR - " + LunaEstado.nave_nombre()
	lbl_lista = _etiqueta(ui, Vector2(10, 19), Color("f4f4f4"))


func _refrescar() -> void:
	var estaciones := get_tree().get_nodes_in_group("estaciones_luna")
	var lineas := []
	var hechas := 0
	for e in estaciones:
		var ok := LunaEstado.completado(String(e.get("id_minijuego")))
		if ok:
			hechas += 1
		lineas.append(("[OK] " if ok else "[  ] ") + String(e.get("titulo")))
	lineas.append("PUNTOS: %d" % LunaEstado.puntos_totales())
	lbl_lista.text = "\n".join(lineas)
	if estaciones.size() > 0 and hechas == estaciones.size():
		_mostrar_final()


func _mostrar_final() -> void:
	todo_listo = true
	panel_final = Control.new()
	ui.add_child(panel_final)
	_caja(panel_final, Rect2(130, 196, 220, 52), Color("38b764"))
	var l1 := _etiqueta(panel_final, Vector2(130, 202), Color("38b764"), 220.0)
	l1.text = "¡BASE LUNAR OPERATIVA!"
	var l2 := _etiqueta(panel_final, Vector2(130, 216), Color("f4f4f4"), 220.0)
	l2.text = "Completaste todas las tareas en la Luna."
	if escena_al_terminar != "":
		var l3 := _etiqueta(panel_final, Vector2(130, 230), Color("ffcd75"), 220.0)
		l3.text = "E: continuar la misión"


func _process(_delta: float) -> void:
	if camara:
		_seguir_jugadores()
	if todo_listo and escena_al_terminar != "" and ResourceLoader.exists(escena_al_terminar):
		if Input.is_action_just_pressed("p1_interact"):
			set_process(false)
			get_tree().change_scene_to_file.call_deferred(escena_al_terminar)
