extends MinijuegoLunar
## MINIJUEGO: Lunar PlanetVac (un jugador)
## Mueves la boquilla del PlanetVac y disparas ráfagas de nitrógeno que levantan
## las piedras pequeñas hasta el contenedor de muestras.
## - E rápido: ráfaga normal.
## - Mantén E y suelta: ráfaga POTENTE (más gas) que rompe las rocas medianas.
## - Las rocas grandes no se pueden levantar (PlanetVac solo toma regolito y piedritas).

const RADIO := 20.0            # alcance de una ráfaga normal
const RADIO_POTENTE := 26.0    # alcance de la ráfaga potente
const COSTO_GAS := 4.0         # nitrógeno por ráfaga normal
const COSTO_POTENTE := 10.0    # nitrógeno por ráfaga potente
const CARGA_POTENTE := 0.6     # segundos manteniendo E para la ráfaga potente
const VELOCIDAD := 95.0
const META := {"basalto": 4, "anortosita": 4, "brecha": 2}
const NOMBRES := {"basalto": "BASALTO", "anortosita": "ANORTOSITA", "brecha": "BRECHA"}
const CAMPO := Rect2(16, 60, 448, 200)

var gas := 100.0
var cabeza: Sprite2D
var carga := 0.0
var cargando := false
var anillo: AnilloCarga
var rocas: Array = []                   # [{nodo, tipo, tam}]
var volando := 0
var recolectadas := {"basalto": 0, "anortosita": 0, "brecha": 0}
var contenedor: Sprite2D
var barra_gas: ColorRect
var lbl_cuentas: Label
var avisos_dados := {}


func _preparar() -> void:
	id_minijuego = "planetvac"
	titulo = "LUNAR PLANETVAC"
	tiempo_limite = 70.0
	datos = [
		"El Lunar PlanetVac de Honeybee Robotics voló a la Luna en 2025 en el módulo Blue Ghost. No usa palas ni brazos: lanza un chorro de gas nitrógeno que levanta el regolito hacia un contenedor.",
		"Los científicos quieren 3 tipos de roca: BASALTO (oscura, de los mares lunares), ANORTOSITA (clara, de las tierras altas) y BRECHA (pedacitos soldados por impactos de meteoritos).",
	]
	objetivo = "Juntar 4 basaltos, 4 anortositas y 2 brechas antes de que se acabe el nitrógeno. Las rocas medianas se rompen con una ráfaga POTENTE."
	controles = "WASD: mover la boquilla.   E: ráfaga de nitrógeno.\nMantén E y suelta: ráfaga potente (gasta más gas)."

	crear_suelo(Rect2(0, 0, ANCHO, ALTO), 11)
	contenedor = sprite(A + "contenedor_muestras.png", Vector2(240, 40))
	contenedor.scale = Vector2(2, 2)
	var lc := etiqueta(mundo, "MUESTRAS", Vector2(190, 52), C_DORADO, 100.0, true)
	lc.z_index = 5

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for tipo in META:
		for i in META[tipo] + 3:
			_nueva_roca(tipo, "chica", _posicion_libre(rng, 14.0))
	for i in 4:
		_nueva_roca("", "mediana", _posicion_libre(rng, 22.0))
	for i in 3:
		_nueva_roca("", "grande", _posicion_libre(rng, 30.0))

	cabeza = sprite(A + "planetvac_cabeza_p1.png", Vector2(240, 170))
	cabeza.z_index = 10
	anillo = AnilloCarga.new()
	anillo.z_index = 11
	cabeza.add_child(anillo)


func _posicion_libre(rng: RandomNumberGenerator, separacion: float) -> Vector2:
	for intento in 60:
		var p := Vector2(rng.randf_range(CAMPO.position.x + 8, CAMPO.end.x - 8), rng.randf_range(CAMPO.position.y + 18, CAMPO.end.y - 6))
		if p.distance_to(Vector2(240, 40)) < 40.0 or p.distance_to(Vector2(240, 170)) < 20.0:
			continue
		var libre := true
		for r in rocas:
			if (r.nodo as Node2D).position.distance_to(p) < separacion:
				libre = false
				break
		if libre:
			return p
	return Vector2(rng.randf_range(40, 440), rng.randf_range(90, 250))


func _nueva_roca(tipo: String, tam_roca: String, pos: Vector2) -> void:
	var ruta := ""
	match tam_roca:
		"chica":
			ruta = A + "roca_%s.png" % tipo
		"mediana":
			ruta = A + "roca_mediana.png"
		_:
			ruta = A + "roca_grande.png"
	var s := sprite(ruta, pos)
	s.z_index = 1
	rocas.append({"nodo": s, "tipo": tipo, "tam": tam_roca})


func _crear_hud() -> void:
	super._crear_hud()
	etiqueta(hud, "N2", Vector2(300, 2), C_TEXTO)
	barra_gas = barra(hud, Rect2(316, 4, 70, 8), Color("73eff7"))
	lbl_cuentas = etiqueta(hud, "", Vector2(6, 18), C_TEXTO, 300.0)


func _refrescar_hud() -> void:
	super._refrescar_hud()
	llenar_barra(barra_gas, gas / 100.0)
	var partes := []
	for tipo in META:
		var marca := " OK" if recolectadas[tipo] >= META[tipo] else ""
		partes.append("%s %d/%d%s" % [NOMBRES[tipo], mini(recolectadas[tipo], META[tipo]), META[tipo], marca])
	lbl_cuentas.text = "   ".join(partes)


func _actualizar(delta: float) -> void:
	mover_con_controles(cabeza, 1, VELOCIDAD, CAMPO, delta)
	# Solo cuenta si E se presionó ya dentro del juego (no la E de "empezar")
	if Input.is_action_just_pressed("p1_interact"):
		cargando = true
		carga = 0.0
	if cargando and Input.is_action_pressed("p1_interact"):
		carga += delta
	if cargando and Input.is_action_just_released("p1_interact"):
		_rafaga(carga >= CARGA_POTENTE)
		cargando = false
		carga = 0.0
	anillo.valor = clampf(carga / CARGA_POTENTE, 0.0, 1.0)
	anillo.queue_redraw()

	if _meta_cumplida():
		terminar(true, "¡El contenedor va lleno de muestras para los científicos!")
	elif gas < COSTO_GAS and volando == 0:
		terminar(false, "Se acabó el nitrógeno del PlanetVac.")


func _meta_cumplida() -> bool:
	for tipo in META:
		if recolectadas[tipo] < META[tipo]:
			return false
	return true


func _rafaga(potente: bool) -> void:
	var costo := COSTO_POTENTE if potente else COSTO_GAS
	if gas < costo:
		if gas >= COSTO_GAS:
			potente = false
			costo = COSTO_GAS
		else:
			texto_flotante(cabeza.position, "SIN NITRÓGENO", C_ROJO)
			return
	gas -= costo
	var pos := cabeza.position
	var radio := RADIO_POTENTE if potente else RADIO
	_efecto_rafaga(pos, potente)
	for r in rocas.duplicate():
		var p: Vector2 = (r.nodo as Node2D).position
		var d := p.distance_to(pos)
		match r.tam:
			"chica":
				if d <= radio:
					_levantar(r)
			"mediana":
				if d <= radio + 6.0:
					if potente:
						_romper(r)
					else:
						_aviso_una_vez(p, "mediana_%d" % r.nodo.get_instance_id(), "¡Mantén E para una ráfaga potente!")
			"grande":
				if d <= radio + 10.0:
					_aviso_una_vez(p, "grande_%d" % r.nodo.get_instance_id(), "Muy grande para el PlanetVac")


func _aviso_una_vez(pos: Vector2, clave: String, texto: String) -> void:
	if avisos_dados.get(clave, -10.0) > tiempo_juego - 2.0:
		return
	avisos_dados[clave] = tiempo_juego
	texto_flotante(pos + Vector2(0, -10), texto, C_DORADO)


func _efecto_rafaga(pos: Vector2, potente: bool) -> void:
	var s := sprite(A + "rafaga_nitrogeno.png", pos, null, 4)
	s.z_index = 9
	if potente:
		s.scale = Vector2(1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(s, "frame", 3, 0.25)
	tw.tween_callback(s.queue_free)


func _levantar(r: Dictionary) -> void:
	rocas.erase(r)
	volando += 1
	var s: Sprite2D = r.nodo
	s.z_index = 8
	var inicio := s.position
	var fin := contenedor.position + Vector2(randf_range(-10, 10), 0)
	var tipo: String = r.tipo
	var vuelo := func(t: float) -> void:
		s.position = inicio.lerp(fin, t) + Vector2(0, -sin(t * PI) * 40.0)
		s.rotation = t * 6.0
	var llegar := func() -> void:
		_guardar_muestra(tipo, fin)
		s.queue_free()
	var tw := create_tween()
	tw.tween_method(vuelo, 0.0, 1.0, 0.6)
	tw.tween_callback(llegar)


func _guardar_muestra(tipo: String, pos: Vector2) -> void:
	volando -= 1
	if recolectadas[tipo] < META[tipo]:
		puntos += 100
		texto_flotante(pos, "+1 " + NOMBRES[tipo], C_VERDE)
	else:
		puntos += 20
		texto_flotante(pos, NOMBRES[tipo] + " (extra)", C_TEXTO)
	recolectadas[tipo] += 1


func _romper(r: Dictionary) -> void:
	rocas.erase(r)
	var p: Vector2 = (r.nodo as Node2D).position
	(r.nodo as Node).queue_free()
	texto_flotante(p, "¡ROCA FRAGMENTADA!", C_VERDE)
	puntos += 50
	# Las piedritas que salen son de los tipos que todavía faltan
	var faltan := []
	for tipo in META:
		if recolectadas[tipo] < META[tipo]:
			faltan.append(tipo)
	if faltan.is_empty():
		faltan = META.keys()
	for i in 3:
		var ang := TAU * i / 3.0 + randf() * 0.5
		var destino := (p + Vector2(cos(ang), sin(ang)) * 16.0).clamp(CAMPO.position, CAMPO.end)
		_nueva_roca(faltan[randi() % faltan.size()], "chica", p)
		var nueva: Sprite2D = rocas.back().nodo
		create_tween().tween_property(nueva, "position", destino, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _al_terminar() -> void:
	if exito:
		puntos += int(tiempo_restante) * 5 + int(gas) * 2


## Anillo alrededor de la boquilla que muestra la carga de la ráfaga potente.
class AnilloCarga extends Node2D:
	var valor := 0.0

	func _draw() -> void:
		if valor <= 0.05:
			return
		var col := Color("ffcd75") if valor >= 1.0 else Color("73eff7")
		draw_arc(Vector2.ZERO, 11.0, -PI / 2.0, -PI / 2.0 + TAU * valor, 24, col, 2.0)
