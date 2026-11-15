extends MinijuegoLunar
## MINIJUEGO: Mantenimiento del módulo lunar (un jugador)
## El astronauta camina alrededor del módulo de la nave que eligió.
## Van apareciendo fallas y hay que repararlas antes de que el estado del módulo llegue a 0.
##   POLVO EN PANEL  -> mantener la tecla 1.5 s
##   TORNILLO FLOJO  -> presionar la tecla 6 veces
##   CABLE SUELTO    -> mantener la tecla 2.5 s
##   FUGA DE OXÍGENO -> mantener la tecla 3 s (¡y hace mucho daño!)

const META_REPARACIONES := 8
const DISTANCIA := 26.0
const MAX_FALLAS := 3

const TIPOS := {
	"polvo": {"nombre": "POLVO EN PANEL", "tiempo": 1.5, "golpes": 0, "dano": 1.2, "icono": "falla_polvo.png", "pista": "MANTÉN E"},
	"tornillo": {"nombre": "TORNILLO FLOJO", "tiempo": 0.0, "golpes": 6, "dano": 1.0, "icono": "falla_tornillo.png", "pista": "PRESIONA E 6 veces"},
	"cable": {"nombre": "CABLE SUELTO", "tiempo": 2.5, "golpes": 0, "dano": 1.4, "icono": "falla_cable.png", "pista": "MANTÉN E"},
	"fuga": {"nombre": "¡FUGA DE O2!", "tiempo": 3.0, "golpes": 0, "dano": 2.6, "icono": "falla_fuga.png", "pista": "¡MANTÉN E, rápido!"},
}

# Lugares donde puede aparecer una falla y qué tipos le tocan
const LUGARES := [
	[Vector2(88, 140), ["polvo"]],
	[Vector2(392, 140), ["polvo"]],
	[Vector2(110, 238), ["cable"]],
	[Vector2(370, 238), ["cable", "tornillo"]],
	[Vector2(176, 192), ["tornillo", "fuga"]],
	[Vector2(304, 192), ["tornillo", "fuga"]],
	[Vector2(214, 216), ["cable", "tornillo"]],
	[Vector2(266, 216), ["fuga", "tornillo"]],
]

var jugador: Node2D
var fallas: Array = []          # [{tipo, lugar, prog, golpes, nodo, anillo, pista}]
var lugares_ocupados := {}
var estado_modulo := 100.0
var reparadas := 0
var siguiente_falla := 1.5
var intervalo := 3.2
var barra_estado: ColorRect
var lbl_info: Label


func _preparar() -> void:
	id_minijuego = "mantenimiento"
	titulo = "MANTENIMIENTO DEL MÓDULO"
	tiempo_limite = 90.0
	var nave := LunaEstado.nave_id()
	var extra := ""
	match nave:
		"gemini4":
			intervalo = 3.2
			extra = "La GEMINI IV es pequeña y antigua: sus fallas aparecen más seguido."
		"artemis2":
			intervalo = 4.3
			extra = "ARTEMIS II es la más moderna: sus fallas aparecen más despacio."
		_:
			intervalo = 3.7
			extra = "El APOLLO 11 es resistente, pero el polvo lunar se mete en todo."
	datos = [
		"El polvo lunar es fino, filoso y se pega a todo: tapa los paneles solares, desgasta los sellos y ensucia los trajes.",
		"En el Apollo 17 (1972) los astronautas repararon la salpicadera rota de su rover con cinta adhesiva y mapas plastificados. En la Luna, saber reparar es vital.",
		extra,
	]
	objetivo = "Reparar %d fallas antes de que el estado del módulo llegue a 0. Atiende primero las fugas de oxígeno: son las que más daño hacen." % META_REPARACIONES
	controles = "WASD: caminar.   E: reparar (mantener o presionar, según la falla)."

	crear_suelo(Rect2(0, 0, ANCHO, ALTO), 23)
	crear_paredes(Rect2(4, 22, ANCHO - 8, ALTO - 26))

	var pad := sprite(A + "plataforma.png", Vector2(240, 196))
	pad.scale = Vector2(2, 2)
	pad.z_index = -5
	var sombra := sprite(A + "sombra_modulo.png", Vector2(240, 198))
	sombra.scale = Vector2(2, 2)
	sombra.z_index = -4
	var modulo := sprite(A + "modulo_%s.png" % nave, Vector2(240, 196))
	if modulo.texture:
		modulo.offset = Vector2(0, -modulo.texture.get_height() / 2.0 + 2.0)
	modulo.scale = Vector2(2, 2)
	crear_solido(Vector2(240, 188), Vector2(84, 22))
	etiqueta(mundo, LunaEstado.nave_nombre(), Vector2(190, 224), C_DORADO, 100.0, true)

	for x in [88, 392]:
		var p := sprite(A + "panel_solar.png", Vector2(x, 118))
		p.scale = Vector2(2, 2)
		crear_solido(Vector2(x, 128), Vector2(10, 8))
	sprite(A + "antena.png", Vector2(110, 222))
	crear_solido(Vector2(110, 232), Vector2(14, 6))
	var b := sprite(A + "baliza.png", Vector2(370, 226), null, 2)
	b.scale = Vector2(1.5, 1.5)

	mundo.y_sort_enabled = true
	jugador = crear_jugador(Vector2(160, 210))


func _crear_hud() -> void:
	super._crear_hud()
	etiqueta(hud, "MÓDULO", Vector2(250, 2), C_TEXTO)
	barra_estado = barra(hud, Rect2(296, 4, 90, 8), C_VERDE)
	lbl_info = etiqueta(hud, "", Vector2(6, 18), C_TEXTO, 300.0)


func _refrescar_hud() -> void:
	super._refrescar_hud()
	llenar_barra(barra_estado, estado_modulo / 100.0)
	barra_estado.color = C_VERDE if estado_modulo > 50.0 else (C_DORADO if estado_modulo > 25.0 else C_ROJO)
	lbl_info.text = "REPARADAS %d/%d" % [reparadas, META_REPARACIONES]


func _actualizar(delta: float) -> void:
	siguiente_falla -= delta
	if siguiente_falla <= 0.0:
		_nueva_falla()
		# Con el tiempo, las fallas llegan cada vez más rápido
		siguiente_falla = maxf(intervalo - tiempo_juego * 0.015, 2.2)

	for f in fallas.duplicate():
		var info: Dictionary = TIPOS[f.tipo]
		var pos: Vector2 = f.nodo.position
		var cerca := jugador.global_position.distance_to(pos) <= DISTANCIA
		if cerca:
			if int(info.golpes) > 0:
				if Input.is_action_just_pressed("p1_interact"):
					f.golpes += 1
				f.prog = float(f.golpes) / float(info.golpes)
			elif Input.is_action_pressed("p1_interact"):
				f.prog += delta / float(info.tiempo)
		f.anillo.valor = f.prog
		f.anillo.queue_redraw()
		f.pista.visible = cerca
		# Bamboleo del icono para llamar la atención
		f.icono.position.y = -14.0 + sin(tiempo_juego * 5.0 + f.lugar) * 1.5
		estado_modulo -= float(info.dano) * delta
		if f.prog >= 1.0:
			_reparar(f)

	if reparadas >= META_REPARACIONES:
		terminar(true, "¡El módulo quedó listo para el regreso a casa!")
	elif estado_modulo <= 0.0:
		estado_modulo = 0.0
		terminar(false, "El módulo sufrió demasiados daños.")


func _nueva_falla() -> void:
	if fallas.size() >= MAX_FALLAS:
		return
	var libres := []
	for i in LUGARES.size():
		if not lugares_ocupados.has(i):
			libres.append(i)
	if libres.is_empty():
		return
	var lugar: int = libres[randi() % libres.size()]
	var tipos: Array = LUGARES[lugar][1]
	var tipo: String = tipos[randi() % tipos.size()]
	var info: Dictionary = TIPOS[tipo]

	var nodo := Node2D.new()
	nodo.position = LUGARES[lugar][0]
	nodo.z_index = 30
	mundo.add_child(nodo)
	var anillo := AnilloProgreso.new()
	anillo.position = Vector2(0, -14)
	nodo.add_child(anillo)
	var icono := sprite(A + String(info.icono), Vector2(0, -14), nodo)
	var nombre := etiqueta(nodo, String(info.nombre), Vector2(-50, -36), C_ROJO if tipo == "fuga" else C_DORADO, 100.0, true)
	nombre.z_index = 31
	var pista := etiqueta(nodo, String(info.pista), Vector2(-60, 4), C_TEXTO, 120.0, true)
	pista.visible = false
	lugares_ocupados[lugar] = true
	fallas.append({"tipo": tipo, "lugar": lugar, "prog": 0.0, "golpes": 0, "nodo": nodo, "anillo": anillo, "icono": icono, "pista": pista})
	# Pequeño "pop" al aparecer
	nodo.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(nodo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reparar(f: Dictionary) -> void:
	fallas.erase(f)
	lugares_ocupados.erase(f.lugar)
	reparadas += 1
	var bono := 250 if f.tipo == "fuga" else 150
	puntos += bono
	estado_modulo = minf(estado_modulo + 4.0, 100.0)
	texto_flotante(f.nodo.position + Vector2(0, -20), "¡REPARADO! +%d" % bono, C_VERDE)
	(f.nodo as Node).queue_free()


func _al_terminar() -> void:
	if exito:
		puntos += int(estado_modulo) * 5 + int(tiempo_restante) * 3


## Anillo que se va llenando mientras se repara.
class AnilloProgreso extends Node2D:
	var valor := 0.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.45))
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.25), 2.0)
		if valor > 0.0:
			draw_arc(Vector2.ZERO, 11.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(valor, 0.0, 1.0), 24, Color("38b764"), 2.0)
