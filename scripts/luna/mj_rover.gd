extends MinijuegoLunar
## MINIJUEGO: Rover lunar en busca de hielo de agua (un jugador)
##   W/S avanzar y reversa, A/D girar.
##   Para analizar una señal: detén el rover encima de ella y mantén E.
## Las señales solo se ven cuando el rover está cerca. Los cráteres gastan batería
## y las rocas grandes bloquean el paso. Se recarga en la base o en el panel solar.

const MUNDO := Rect2(0, 0, 960, 540)
const META_SENALES := 5
const VMAX := 85.0
const VREVERSA := 40.0
const GIRO := 2.4
const RANGO_SENSOR := 150.0
const DISTANCIA_ESCANEO := 22.0
const TIEMPO_ESCANEO := 1.5
const BASE := Vector2(120, 120)
const PANEL := Vector2(850, 440)

var rover: CharacterBody2D
var vel := 0.0
var bateria := 100.0
var bateria_max := 100.0
var anillo: AnilloEscaneo
var flecha: Polygon2D
var crateres: Array[Vector2] = []
var senales: Array = []             # [{nodo, hecha}]
var encontradas := 0
var progreso := 0.0
var golpe_cd := 0.0
var cargando := false
var barra_bat: ColorRect
var lbl_info: Label


func _preparar() -> void:
	id_minijuego = "rover"
	titulo = "ROVER LUNAR"
	tiempo_limite = 110.0
	match LunaEstado.nave_id():
		"artemis2":
			bateria_max = 120.0
		"gemini4":
			bateria_max = 85.0
		_:
			bateria_max = 100.0
	bateria = bateria_max
	datos = [
		"El Rover Lunar del Apollo 15 (1971) fue el primer vehículo manejado en la Luna. Funcionaba con baterías y en esa misión recorrió unos 28 km.",
		"Hoy la NASA busca HIELO DE AGUA en el polo sur lunar: serviría para beber, para producir oxígeno y hasta para hacer combustible de cohete.",
		"Batería de este rover: %d%% (depende de la nave que elegiste)." % int(bateria_max),
	]
	objetivo = "Encontrar y analizar %d señales de hielo antes de quedarte sin batería. Recarga en la base o en el panel solar. La flecha azul apunta a la señal más cercana." % META_SENALES
	controles = "W/S: avanzar y reversa.   A/D: girar.\nE (mantener): analizar la señal que tengas debajo, con el rover detenido."

	crear_suelo(MUNDO, 37)
	crear_paredes(MUNDO)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Base de carga con el módulo de la nave elegida
	var pad := sprite(A + "plataforma.png", BASE)
	pad.z_index = -5
	var modulo := sprite(A + "modulo_%s.png" % LunaEstado.nave_id(), BASE + Vector2(-46, 10))
	if modulo.texture:
		modulo.offset = Vector2(0, -modulo.texture.get_height() / 2.0 + 2.0)
	crear_solido(BASE + Vector2(-46, 4), Vector2(36, 14))
	etiqueta(mundo, "CARGA", BASE + Vector2(-30, 18), C_VERDE, 60.0, true)
	var p := sprite(A + "panel_solar.png", PANEL)
	p.scale = Vector2(2, 2)
	etiqueta(mundo, "CARGA", PANEL + Vector2(-30, 22), C_VERDE, 60.0, true)

	# Cráteres (gastan batería si el rover cae en ellos)
	for i in 9:
		var c := _punto_lejos(rng, 70.0)
		crateres.append(c)
		var s := sprite(A + "crater.png", c)
		s.z_index = -3
	# Rocas grandes (bloquean el paso)
	for i in 12:
		var r := _punto_lejos(rng, 50.0)
		sprite(A + "roca_grande.png", r)
		var cuerpo := StaticBody2D.new()
		cuerpo.position = r
		var col := CollisionShape2D.new()
		var forma := CircleShape2D.new()
		forma.radius = 9.0
		col.shape = forma
		cuerpo.add_child(col)
		mundo.add_child(cuerpo)
	# Señales de hielo de agua
	var puntos_senal: Array[Vector2] = []
	while puntos_senal.size() < META_SENALES:
		var q := _punto_lejos(rng, 60.0)
		var ok := q.distance_to(BASE) > 220.0
		for o in puntos_senal:
			if o.distance_to(q) < 170.0:
				ok = false
		if ok:
			puntos_senal.append(q)
	for q in puntos_senal:
		var s := sprite(A + "senal_hielo.png", q, null, 4)
		s.modulate.a = 0.0
		s.z_index = 2
		senales.append({"nodo": s, "hecha": false})

	# Rover
	rover = CharacterBody2D.new()
	rover.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	rover.position = BASE + Vector2(40, 0)
	var col_r := CollisionShape2D.new()
	var forma_r := CircleShape2D.new()
	forma_r.radius = 9.0
	col_r.shape = forma_r
	rover.add_child(col_r)
	sprite(A + "rover.png", Vector2.ZERO, rover)
	rover.z_index = 5
	mundo.add_child(rover)

	flecha = Polygon2D.new()
	flecha.polygon = PackedVector2Array([Vector2(6, 0), Vector2(-3, -4), Vector2(-3, 4)])
	flecha.color = Color(0.45, 0.94, 0.97, 0.8)
	flecha.z_index = 6
	mundo.add_child(flecha)

	anillo = AnilloEscaneo.new()
	anillo.z_index = 21
	mundo.add_child(anillo)

	camara.limit_left = int(MUNDO.position.x)
	camara.limit_top = int(MUNDO.position.y) - 20
	camara.limit_right = int(MUNDO.end.x)
	camara.limit_bottom = int(MUNDO.end.y)
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 6.0
	camara.position = rover.position
	camara.reset_smoothing()


func _punto_lejos(rng: RandomNumberGenerator, separacion: float) -> Vector2:
	for intento in 80:
		var q := Vector2(rng.randf_range(40, MUNDO.end.x - 40), rng.randf_range(50, MUNDO.end.y - 30))
		if q.distance_to(BASE) < 110.0 or q.distance_to(PANEL) < 60.0:
			continue
		var libre := true
		for c in crateres:
			if c.distance_to(q) < separacion:
				libre = false
				break
		if libre:
			return q
	return Vector2(rng.randf_range(300, 900), rng.randf_range(80, 500))


func _crear_hud() -> void:
	super._crear_hud()
	etiqueta(hud, "BATERÍA", Vector2(236, 2), C_TEXTO)
	barra_bat = barra(hud, Rect2(296, 4, 90, 8), C_VERDE)
	lbl_info = etiqueta(hud, "", Vector2(6, 18), C_TEXTO, 360.0)


func _refrescar_hud() -> void:
	super._refrescar_hud()
	llenar_barra(barra_bat, bateria / bateria_max)
	barra_bat.color = C_VERDE if bateria > bateria_max * 0.5 else (C_DORADO if bateria > bateria_max * 0.25 else C_ROJO)
	var extra := ""
	if cargando:
		extra = "   CARGANDO..."
	lbl_info.text = "HIELO ENCONTRADO %d/%d%s" % [encontradas, META_SENALES, extra]


func _actualizar(delta: float) -> void:
	golpe_cd = maxf(golpe_cd - delta, 0.0)

	# ---- Manejo ----
	var giro := Input.get_axis("p1_left", "p1_right")
	var acel := Input.get_axis("p1_down", "p1_up")
	var tope := VMAX if acel >= 0.0 else VREVERSA
	if bateria <= 0.0:
		acel = 0.0
	vel = move_toward(vel, acel * tope, 140.0 * delta)
	rover.rotation += giro * GIRO * delta
	rover.velocity = Vector2.RIGHT.rotated(rover.rotation) * vel
	rover.move_and_slide()
	camara.position = rover.position

	var gasto := 0.3 + 1.2 * absf(vel) / VMAX
	bateria = maxf(bateria - gasto * delta, 0.0)

	# Recarga
	cargando = rover.position.distance_to(BASE) < 38.0 or rover.position.distance_to(PANEL) < 38.0
	if cargando:
		bateria = minf(bateria + 15.0 * delta, bateria_max)

	# Cráteres
	if golpe_cd <= 0.0:
		for c in crateres:
			if rover.position.distance_to(c) < 11.0:
				bateria = maxf(bateria - 12.0, 0.0)
				vel = -vel * 0.5
				golpe_cd = 1.2
				texto_flotante(c + Vector2(0, -14), "¡CRÁTER! -12% BATERÍA", C_ROJO)
				break

	# ---- Señales: se ven solo cerca del rover ----
	var mas_cercana: Dictionary = {}
	var d_min := INF
	for s in senales:
		var nodo: Sprite2D = s.nodo
		nodo.frame = int(tiempo_juego * 6.0) % 4
		var d := nodo.position.distance_to(rover.position)
		if not s.hecha:
			nodo.modulate.a = clampf(1.0 - (d - (RANGO_SENSOR - 40.0)) / 60.0, 0.0, 1.0)
			if d < d_min:
				d_min = d
				mas_cercana = s
	# Flecha que apunta a la señal más cercana (solo si está lejos)
	if not mas_cercana.is_empty() and d_min > 120.0:
		var dir: Vector2 = ((mas_cercana.nodo as Node2D).position - rover.position).normalized()
		flecha.visible = true
		flecha.position = rover.position + dir * 24.0
		flecha.rotation = dir.angle()
	else:
		flecha.visible = false

	# ---- Escaneo: rover detenido encima de una señal + mantener E ----
	anillo.position = rover.position
	var objetivo_escaneo: Dictionary = {}
	for s in senales:
		if not s.hecha and (s.nodo as Node2D).position.distance_to(rover.position) < DISTANCIA_ESCANEO:
			objetivo_escaneo = s
			break
	if Input.is_action_pressed("p1_interact"):
		if objetivo_escaneo.is_empty():
			if Input.is_action_just_pressed("p1_interact"):
				texto_flotante(rover.position + Vector2(0, -16), "No hay señal aquí", C_TEXTO)
		elif absf(vel) > 12.0:
			if Input.is_action_just_pressed("p1_interact"):
				texto_flotante(rover.position + Vector2(0, -16), "¡Detén el rover para analizar!", C_DORADO)
		else:
			progreso += delta / TIEMPO_ESCANEO
			if progreso >= 1.0:
				_analizar(objetivo_escaneo)
				progreso = 0.0
	else:
		progreso = maxf(progreso - delta * 2.0, 0.0)
	anillo.valor = progreso
	anillo.queue_redraw()

	# ---- Fin ----
	if encontradas >= META_SENALES:
		terminar(true, "¡Mapeaste %d depósitos de hielo de agua!" % encontradas)
	elif bateria <= 0.0 and not cargando:
		terminar(false, "El rover se quedó sin batería lejos de la base.")


func _analizar(s: Dictionary) -> void:
	s.hecha = true
	encontradas += 1
	puntos += 200
	var nodo: Sprite2D = s.nodo
	nodo.modulate.a = 1.0
	var marca := sprite(A + "completado.png", nodo.position + Vector2(0, -10))
	marca.z_index = 3
	texto_flotante(nodo.position + Vector2(0, -16), "¡HIELO DE AGUA! +200", C_VERDE)


func _al_terminar() -> void:
	vel = 0.0
	if exito:
		puntos += int(bateria) * 3 + int(tiempo_restante) * 4


## Anillo de progreso del escaneo.
class AnilloEscaneo extends Node2D:
	var valor := 0.0

	func _draw() -> void:
		if valor <= 0.0:
			return
		draw_arc(Vector2.ZERO, 12.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(valor, 0.0, 1.0), 24, Color("73eff7"), 2.0)
