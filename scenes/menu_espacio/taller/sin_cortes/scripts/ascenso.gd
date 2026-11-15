extends Control
## FASE DE LANZAMIENTO Y ASCENSO
## La nave elegida despega sola desde el Centro Espacial Kennedy y sube por las
## capas de la atmósfera. El jugador solo se mueve a los lados (flechas) para
## esquivar obstáculos. Albertsahur explica cada capa (datos de NOAA JetStream).
## La resistencia y la maniobra dependen de la nave (ver mision.gd).

# ---------- Cosas que puedes cambiar fácilmente ----------
const FONDO := "res://assets/atmosfera/atmosfera.png"
const RUTA_OBST := "res://assets/obstaculos/"
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const ESCENA_SIGUIENTE := "res://scenes/orbita.tscn"   # al ganar se pasa sola a esta escena
const ESCENA_SELECCION := "res://scenes/seleccion_nave.tscn"
const ESCENA_TALLER := "res://scenes/taller.tscn"
const ESCENA_MENU := "res://scenes/menu_principal.tscn"
const POSICION_NAVE := 0.62      # altura de la nave en pantalla mientras sube (0 arriba, 1 abajo)
const ALTURA_NAVE := 130.0       # alto de la nave en pantalla (con pantalla de 648 px)
const PLATAFORMA := Vector2(0.506, 0.0263)   # dónde se para la nave: x (fracción del ancho), y (fracción desde abajo)
const DIFICULTAD := 0.9          # más alto = obstáculos más seguido, más bajo = más espaciados
const RITMO := 0.45              # velocidad de subida (1.0 = la más rápida)

# Capas de abajo hacia arriba. "hasta" = fracción de la imagen (desde abajo).
# Datos de altura y temperatura: NOAA JetStream, "Layers of the Atmosphere".
# obstaculos: [tipo, cada cuántos segundos, desde qué fracción aparecen]
const CAPAS := [
	{"nombre": "TROPOSFERA", "hasta": 0.3754, "km": [0.0, 12.0], "temp": [17.0, -51.0],
		"color": Color("b8c7d6"), "obstaculos": [["avion", 3.0, 0.09], ["rayo", 3.4, 0.22]]},
	{"nombre": "ESTRATOSFERA", "hasta": 0.5129, "km": [12.0, 50.0], "temp": [-51.0, -15.0],
		"color": Color("9b9dff"), "obstaculos": [["globos", 1.9, 0.0]]},
	{"nombre": "MESOSFERA", "hasta": 0.6755, "km": [50.0, 85.0], "temp": [-15.0, -120.0],
		"color": Color("9fd0ff"), "obstaculos": [["meteoro", 0.85, 0.0]]},
	{"nombre": "TERMOSFERA", "hasta": 0.8288, "km": [85.0, 600.0], "temp": [-120.0, 2000.0],
		"color": Color("5ee39a"), "obstaculos": [["satelite", 2.6, 0.0], ["escudo", 3.2, 0.0]]},
	{"nombre": "EXOSFERA", "hasta": 1.0, "km": [600.0, 10000.0], "temp": [2000.0, 2000.0],
		"color": Color("f5c542"), "obstaculos": [["satelite", 2.0, 0.0]]},
]

# Lo que dice Albertsahur (información de NOAA JetStream)
const DIALOGOS := {
	"inicio": [
		"Plataforma lista, director. Estamos en el Centro Espacial Kennedy, en Florida.",
		"La nave sube sola: tú usa las flechas IZQUIERDA y DERECHA para esquivar. ¡Comienza la cuenta!",
	],
	"TROPOSFERA": [
		"Esta es la troposfera: empieza en el suelo y aquí ocurre casi todo el clima.",
		"Entre más subimos, más frío: de unos 17 °C abajo a -51 °C arriba. ¡Ojo con aviones y rayos!",
	],
	"ESTRATOSFERA": [
		"¡Pasamos la tropopausa! Esta es la estratosfera y llega hasta unos 50 km.",
		"Aquí se forma el ozono, y eso calienta el aire: la temperatura SUBE con la altura. ¡Esquiva los globos!",
	],
	"MESOSFERA": [
		"Mesosfera: de 50 a 85 km. Aquí vuelve a hacer más frío conforme subimos.",
		"El aire todavía frena a los meteoros: se queman y dejan estelas de fuego. ¡Cuidado con los meteoritos!",
	],
	"TERMOSFERA": [
		"Termosfera: de 85 a 600 km. Absorbe rayos X y ultravioleta del Sol y llega hasta 2,000 °C.",
		"Pero el aire es tan delgado que no sentiríamos ese calor. ¡Agarra los escudos para reparar la nave!",
	],
	"EXOSFERA": [
		"¡Exosfera! Va de unos 600 hasta 10,000 km. Aquí los átomos escapan al espacio.",
		"Es la capa donde orbitan los satélites. ¡No choques con ellos!",
	],
	"exito": ["¡Lo logramos, director! Atravesamos toda la atmósfera. ¡Estamos en el espacio!"],
	"fallo": ["La nave no aguantó... Revisemos el diseño e intentémoslo otra vez."],
	"ultima": ["¡Cuidado! Nos queda un solo punto de resistencia."],
	"escudo": ["¡Escudo recuperado! Eso repara un punto de resistencia."],
}
# ---------------------------------------------------------

const CORAZON := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]

var k := 1.0
var pantalla := Vector2.ZERO
var fuente: Font
var tiempo := 0.0

# Mundo (todo lo que se mueve con la cámara)
var mundo: Node2D
var fondo: TextureRect
var alto_fondo := 0.0
var camara := 0.0          # posición (en el mundo) del borde de arriba de la pantalla
var texturas := {}
var obstaculos := []

# Nave
var id_nave := "apollo11"
var datos_nave: Dictionary
var nave: Sprite2D
var humo: CPUParticles2D
var alto_nave := 0.0
var ancho_nave := 0.0
var vida := 3
var vida_max := 3
var maniobra := 250.0
var vel_crucero := 100.0
var velocidad := 0.0
var estado := "cuenta"      # cuenta, subiendo, exito, fallo
var invulnerable := 0.0
var temblor := 0.0
var golpes := 0
var escudo_proteccion := 0      # golpes que absorbe el escudo de energía
var burbuja: Sprite2D
var aviso_rayo := 0.9           # segundos de aviso antes del rayo (comunicaciones)
var datos := 0                  # datos científicos juntados (ciencia)
var avisos_escudo := 0
var lbl_datos: Label
var escudos := 0
var altitud_max := 0.0
var capa_actual := -1
var f_suelo := 0.0          # fracción de la punta de la nave sobre la plataforma (altitud 0)
var temporizadores := {}

# HUD
var lbl_nombre: Label
var lbl_maniobra: Label
var lbl_capa: Label
var lbl_altitud: Label
var lbl_temp: Label
var lbl_centro: Label
var lbl_aviso: Label
var corazones: Control
var altimetro: Control
var capa_hud: CanvasLayer

# Diálogo de Albertsahur
var retrato: TextureRect
var lbl_dialogo: Label
var tex_normal: Texture2D
var tex_hablando: Texture2D
var tex_parpadeo: Texture2D
var cola := []
var al_terminar := Callable()
var letras := 0.0
var espera := 0.0
var reloj_boca := 0.0
var boca_abierta := false
var parpadeo := 2.0


func _ready() -> void:
	pantalla = get_viewport_rect().size
	k = pantalla.y / 648.0
	fuente = load(RUTA_FUENTE) if ResourceLoader.exists(RUTA_FUENTE) else ThemeDB.fallback_font

	# --- Stats de la nave elegida ---
	id_nave = Mision.nave_elegida if Mision.NAVES.has(Mision.nave_elegida) else "apollo11"
	datos_nave = Mision.NAVES[id_nave]
	vida_max = Mision.vida_max(id_nave)
	vida = vida_max
	maniobra = Mision.maniobra(id_nave)
	escudo_proteccion = Mision.escudo_inicial(id_nave)
	aviso_rayo = Mision.aviso_rayo(id_nave)

	# --- Mundo y fondo ---
	mundo = Node2D.new()
	add_child(mundo)
	fondo = TextureRect.new()
	var tex_fondo: Texture2D = _cargar(FONDO)
	fondo.texture = tex_fondo
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alto_fondo = pantalla.x * tex_fondo.get_size().y / tex_fondo.get_size().x
	fondo.size = Vector2(pantalla.x, alto_fondo)
	mundo.add_child(fondo)

	for n in ["avion", "globos", "meteoro_grande", "meteoro_chico", "meteoro_chico2", "satelite", "escudo"]:
		texturas[n] = _cargar(RUTA_OBST + n + ".png")

	# --- Nave sobre la plataforma ---
	nave = Sprite2D.new()
	var tex_nave: Texture2D = _cargar(datos_nave.cohete_img)
	nave.texture = tex_nave
	var escala := ALTURA_NAVE * k / tex_nave.get_size().y
	nave.scale = Vector2(escala, escala)
	nave.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if escala < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	alto_nave = tex_nave.get_size().y * escala
	ancho_nave = tex_nave.get_size().x * escala
	var base_y := alto_fondo * (1.0 - PLATAFORMA.y)
	nave.position = Vector2(pantalla.x * PLATAFORMA.x, base_y - alto_nave * 0.5)
	mundo.add_child(nave)
	_crear_humo(tex_nave)
	_crear_burbuja()
	f_suelo = _fraccion_nave()

	# La cámara empieza abajo del todo y termina arriba del todo
	camara = alto_fondo - pantalla.y
	var distancia := nave.position.y - pantalla.y * POSICION_NAVE
	vel_crucero = distancia / Mision.duracion_ascenso(id_nave) * RITMO

	_crear_hud()
	_crear_dialogo()
	mundo.position = Vector2(0, -camara)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	decir(DIALOGOS.inicio, _cuenta_regresiva)


func _cargar(ruta: String) -> Texture2D:
	var t: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	if t == null:
		push_error("No encuentro la imagen: " + ruta + "  (revisa que esté en esa carpeta dentro de Godot)")
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	return t


func _process(delta: float) -> void:
	tiempo += delta
	_actualizar_dialogo(delta)

	if estado == "subiendo":
		_subir(delta)
	elif estado == "exito":
		nave.position.y -= velocidad * 1.5 * delta   # se va hacia el espacio

	_mover_obstaculos(delta)

	# Temblor de cámara
	var sacudida := Vector2.ZERO
	if temblor > 0.0:
		temblor -= delta
		sacudida = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * k * min(temblor * 2.0, 1.0)
	mundo.position = Vector2(0, -camara) + sacudida

	# Parpadeo después de un golpe
	if invulnerable > 0.0:
		invulnerable -= delta
		nave.visible = fmod(invulnerable, 0.16) < 0.1
	elif estado != "fallo":
		nave.visible = true

	_actualizar_hud()


# ================= Movimiento =================

func _cuenta_regresiva() -> void:
	for n in ["3", "2", "1"]:
		_texto_centro(n, Color.WHITE)
		await get_tree().create_timer(1.0).timeout
	_texto_centro("¡DESPEGUE!", Color("f5c542"))
	capa_actual = -1   # para que Albertsahur presente la troposfera al despegar
	estado = "subiendo"
	humo.emitting = true
	temblor = 1.2


func _subir(delta: float) -> void:
	# Acelera poco a poco hasta su velocidad normal
	velocidad = min(velocidad + vel_crucero * 0.45 * delta, vel_crucero)
	nave.position.y -= velocidad * delta
	# La cámara sigue a la nave cuando llega a su altura en pantalla
	camara = clamp(nave.position.y - pantalla.y * POSICION_NAVE, 0.0, alto_fondo - pantalla.y)

	var lado := Input.get_axis("ui_left", "ui_right")
	var margen := 45.0 * k
	nave.position.x = clamp(nave.position.x + lado * maniobra * k * delta, margen, pantalla.x - margen)
	nave.rotation = lerp(nave.rotation, lado * 0.12, 8.0 * delta)

	altitud_max = max(altitud_max, _altitud_km(_fraccion_nave()))
	_generar_obstaculos(delta)

	# Cuando la cámara ya llegó arriba, la nave sigue subiendo en pantalla
	# hasta que su punta toca el borde de arriba (la barra lateral llega al tope)
	if _fraccion_nave() >= 0.998:
		_exito()


## Qué tan arriba va la punta de la nave (0 = abajo de la imagen, 1 = arriba del todo)
func _fraccion_nave() -> float:
	var punta := nave.position.y - alto_nave * 0.5
	return clamp(1.0 - punta / alto_fondo, 0.0, 1.0)


func _indice_capa(f: float) -> int:
	for i in CAPAS.size():
		if f <= CAPAS[i].hasta:
			return i
	return CAPAS.size() - 1


func _interpolar(f: float, campo: String) -> float:
	var i := _indice_capa(f)
	var desde: float = f_suelo if i == 0 else CAPAS[i - 1].hasta
	var t: float = clamp(inverse_lerp(desde, CAPAS[i].hasta, f), 0.0, 1.0)
	return lerp(float(CAPAS[i][campo][0]), float(CAPAS[i][campo][1]), t)


func _altitud_km(f: float) -> float:
	return _interpolar(f, "km")


# ================= Obstáculos =================

func _generar_obstaculos(delta: float) -> void:
	var f := _fraccion_nave()
	# Los globos se quedan quietos en su capa, así que se generan según la capa
	# que está apareciendo arriba de la pantalla (no según dónde va la nave)
	var f_arriba := 1.0 - (camara - 150.0 * k) / alto_fondo
	for i in CAPAS.size():
		for o in CAPAS[i].obstaculos:
			var referencia := f_arriba if o[0] == "globos" else f
			if _indice_capa(referencia) != i or f < o[2]:
				continue
			var clave := str(i) + String(o[0])
			if not temporizadores.has(clave):
				temporizadores[clave] = randf_range(0.6, 1.5)
			temporizadores[clave] -= delta * DIFICULTAD
			if temporizadores[clave] <= 0.0:
				temporizadores[clave] = float(o[1]) * randf_range(0.7, 1.3)
				if (o[0] == "avion" or o[0] == "satelite") and Mision.avisos_laterales(id_nave):
					_avisar_y_crear(o[0])
				else:
					_crear_obstaculo(o[0])


func _sprite(nombre: String, tamano: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texturas[nombre]
	s.scale = Vector2.ONE * tamano * k
	mundo.add_child(s)
	return s


## COMUNICACIONES: muestra un aviso del lado por donde va a entrar el obstáculo
func _avisar_y_crear(tipo: String) -> void:
	var lado := 1 if randf() < 0.5 else 0          # 1 = entra por la izquierda
	var y_rel := randf_range(0.04, 0.3)
	var aviso := _etiqueta(26, Color("ff5a5a"))
	aviso.text = ("! " if lado == 1 else "") + ("AVIÓN" if tipo == "avion" else "SATÉLITE") + (" !" if lado == 0 else "")
	aviso.position = Vector2(12 * k if lado == 1 else pantalla.x - 330 * k, pantalla.y * y_rel)
	capa_hud.add_child(aviso)
	var t := aviso.create_tween().set_loops(4)
	t.tween_property(aviso, "modulate:a", 0.2, 0.15)
	t.tween_property(aviso, "modulate:a", 1.0, 0.15)
	await get_tree().create_timer(1.2).timeout
	aviso.queue_free()
	if estado == "subiendo":
		_crear_obstaculo(tipo, lado, y_rel)


func _crear_obstaculo(tipo: String, lado: int = -1, y_rel: float = -1.0) -> void:
	var ob := {"tipo": tipo, "nodo": null, "vel": Vector2.ZERO, "t": 0.0, "girar": 0.0, "circulos": [], "activo": true}
	var arriba := camara - 90.0 * k
	var n: Node2D
	match tipo:
		"avion":
			var s := _sprite("avion", 1.5)
			var desde_izq := (randf() < 0.5) if lado == -1 else lado == 1
			s.flip_h = desde_izq          # la imagen mira a la izquierda
			s.position = Vector2(-110.0 * k if desde_izq else pantalla.x + 110.0 * k,
				camara + pantalla.y * (y_rel if y_rel >= 0.0 else randf_range(0.02, 0.32)))
			ob.vel = Vector2((1.0 if desde_izq else -1.0) * randf_range(170.0, 240.0) * k, 0.0)
			var w := s.texture.get_size().x * s.scale.x
			var h := s.texture.get_size().y * s.scale.y
			ob.circulos = [[Vector2(-w * 0.3, 0), h * 0.4], [Vector2.ZERO, h * 0.45], [Vector2(w * 0.3, 0), h * 0.4]]
			n = s
		"rayo":
			n = _crear_rayo(ob)
			n.position = Vector2(randf_range(60.0 * k, pantalla.x - 260.0 * k), camara + pantalla.y * randf_range(0.0, 0.25))
			ob.activo = false
		"globos":
			# Solo aparecen si ese punto de la imagen es estratosfera
			var y_globo := arriba - 60.0 * k
			var f_globo := 1.0 - y_globo / alto_fondo
			if f_globo < CAPAS[0].hasta or f_globo > CAPAS[1].hasta:
				return
			var s := _sprite("globos", 0.55)
			s.position = Vector2(randf_range(80.0 * k, pantalla.x - 80.0 * k), y_globo)
			ob.vel = Vector2(randf_range(-8.0, 8.0), 0.0) * k   # flotan quietos, sin subir
			var w := s.texture.get_size().x * s.scale.x
			var h := s.texture.get_size().y * s.scale.y
			ob.circulos = [[Vector2(-w * 0.05, -h * 0.22), w * 0.3], [Vector2(w * 0.28, 0), w * 0.15],
				[Vector2(-w * 0.32, 0), w * 0.12], [Vector2(0, h * 0.3), w * 0.1]]
			n = s
		"meteoro":
			var grande := randf() < 0.3
			var nombre := "meteoro_grande" if grande else ("meteoro_chico" if randf() < 0.5 else "meteoro_chico2")
			var s := _sprite(nombre, 0.75 if grande else 1.4)
			s.position = Vector2(randf_range(0.15, 1.15) * pantalla.x, arriba)
			ob.vel = Vector2(-randf_range(80.0, 150.0), randf_range(140.0, 230.0)) * k
			var w := s.texture.get_size().x * s.scale.x
			# la cabeza del meteoro está abajo a la izquierda de la imagen
			ob.circulos = [[Vector2(-w * 0.18, w * 0.18), w * 0.24]]
			n = s
		"satelite":
			var s := _sprite("satelite", 0.75)
			var desde_izq := (randf() < 0.5) if lado == -1 else lado == 1
			s.position = Vector2(-80.0 * k if desde_izq else pantalla.x + 80.0 * k,
				camara + pantalla.y * (y_rel if y_rel >= 0.0 else randf_range(0.0, 0.3)))
			ob.vel = Vector2((1.0 if desde_izq else -1.0) * randf_range(60.0, 120.0) * k, 0.0)
			ob.girar = randf_range(-0.8, 0.8)
			var w := s.texture.get_size().x * s.scale.x
			ob.circulos = [[Vector2.ZERO, w * 0.18], [Vector2(-w * 0.25, -w * 0.25), w * 0.15], [Vector2(w * 0.25, w * 0.25), w * 0.15]]
			n = s
		"escudo":
			var s := _sprite("escudo", 0.55)
			s.position = Vector2(randf_range(80.0 * k, pantalla.x - 80.0 * k), arriba)
			ob.vel = Vector2(0, 25.0 * k)
			ob.circulos = [[Vector2.ZERO, s.texture.get_size().x * s.scale.x * 0.45]]
			n = s
	if n == null:
		return
	ob.nodo = n
	obstaculos.append(ob)


func _crear_rayo(ob: Dictionary) -> Node2D:
	var r := Node2D.new()
	var puntos := PackedVector2Array()
	var largo := randf_range(170.0, 250.0) * k
	var x := 0.0
	for i in 10:
		puntos.append(Vector2(x, largo * i / 9.0))
		x += randf_range(-24.0, 24.0) * k
	var brillo := Line2D.new()
	brillo.points = puntos
	brillo.width = 16.0 * k
	brillo.default_color = Color(1.0, 0.95, 0.55, 0.35)
	var nucleo := Line2D.new()
	nucleo.points = puntos
	nucleo.width = 4.0 * k
	nucleo.default_color = Color(1.0, 1.0, 0.88)
	r.add_child(brillo)
	r.add_child(nucleo)
	mundo.add_child(r)
	var circulos := []
	for p in puntos:
		circulos.append([p, 9.0 * k])
	ob.circulos = circulos
	return r


func _mover_obstaculos(delta: float) -> void:
	for ob in obstaculos.duplicate():
		var n: Node2D = ob.nodo
		ob.t += delta
		n.position += ob.vel * delta
		n.rotation += ob.girar * delta
		match ob.tipo:
			"globos":
				n.position.x += sin(ob.t * 1.5) * 12.0 * k * delta
			"escudo":
				n.scale = Vector2.ONE * 0.55 * k * (1.0 + sin(ob.t * 5.0) * 0.06)
			"rayo":
				# Primero parpadea como aviso (más tiempo con mejores comunicaciones),
				# luego golpea 0.4 s y desaparece.
				if ob.t < aviso_rayo:
					n.modulate = Color(1, 0.45, 0.35, 0.2 + 0.2 * sin(ob.t * 30.0))
				elif ob.t < aviso_rayo + 0.4:
					ob.activo = true
					n.modulate = Color(1, 1, 1, 1)
					n.position.x += randf_range(-1.5, 1.5) * k
				else:
					ob.activo = false
					n.modulate.a = max(0.0, 1.0 - (ob.t - aviso_rayo - 0.4) * 3.0)

		var fuera: bool = n.position.y > camara + pantalla.y + 300.0 * k \
			or n.position.x < -500.0 * k or n.position.x > pantalla.x + 500.0 * k \
			or (ob.tipo == "rayo" and ob.t > aviso_rayo + 0.8)
		if fuera:
			_quitar(ob)
			continue

		if estado != "subiendo" or not ob.activo:
			continue
		if ob.tipo == "escudo":
			if _choca(ob):
				_recoger_escudo(ob)
		elif invulnerable <= 0.0 and _choca(ob):
			_recibir_golpe()


func _quitar(ob: Dictionary) -> void:
	ob.nodo.queue_free()
	obstaculos.erase(ob)


func _choca(ob: Dictionary) -> bool:
	# La nave se toma como una "cápsula" vertical
	var radio_nave := ancho_nave * 0.3
	var a := nave.position + Vector2(0, -alto_nave * 0.38).rotated(nave.rotation)
	var b := nave.position + Vector2(0, alto_nave * 0.18).rotated(nave.rotation)
	var n: Node2D = ob.nodo
	for c in ob.circulos:
		var centro: Vector2 = n.position + (c[0] as Vector2).rotated(n.rotation)
		var p := Geometry2D.get_closest_point_to_segment(centro, a, b)
		if p.distance_to(centro) < float(c[1]) + radio_nave:
			return true
	return false


func _recibir_golpe() -> void:
	if escudo_proteccion > 0:
		escudo_proteccion -= 1
		invulnerable = 1.0
		temblor = 0.25
		_texto_flotante("ESCUDO", Color("8fd3e8"))
		burbuja.visible = escudo_proteccion > 0
		avisos_escudo += 1
		if avisos_escudo == 1:
			cola.push_front("¡El escudo de energía nos protegió! " + ("Todavía aguanta otro golpe." if escudo_proteccion > 0 else "Ya se agotó."))
		return
	vida -= 1
	golpes += 1
	invulnerable = 1.6
	temblor = 0.45
	_texto_flotante("-1", Color("ff5a5a"))
	if vida <= 0:
		_fallo()
	elif vida == 1:
		cola.push_front(DIALOGOS.ultima[0])


func _recoger_escudo(ob: Dictionary) -> void:
	_quitar(ob)
	escudos += 1
	if vida < vida_max:
		vida += 1
		_texto_flotante("+1", Color("5ee39a"))
	else:
		_texto_flotante("MAX", Color("8fd3e8"))
	if escudos == 1:
		cola.push_front(DIALOGOS.escudo[0])


func _exito() -> void:
	estado = "exito"
	_texto_centro("¡EXOSFERA ALCANZADA!", Color("f5c542"), 3.0)
	decir(DIALOGOS.exito)
	get_tree().create_timer(2.0).timeout.connect(_despues_del_exito)


func _despues_del_exito() -> void:
	Mision.resultado = _calcular_resultado(true)
	if ESCENA_SIGUIENTE != "" and ResourceLoader.exists(ESCENA_SIGUIENTE):
		# Guarda la imagen actual para que la órbita aparezca encima (sin pantalla negra)
		await RenderingServer.frame_post_draw
		Mision.captura = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		get_tree().change_scene_to_file(ESCENA_SIGUIENTE)
	else:
		_mostrar_resultado(true)


func _calcular_resultado(gano: bool) -> Dictionary:
	var bono_vida: int = max(vida, 0) * 400 if gano else 0
	var bono_dinero := int(Mision.presupuesto_restante / 50_000.0) if gano else 0
	return {
		"nave": datos_nave.nombre, "vida": max(vida, 0), "vida_max": vida_max,
		"golpes": golpes, "escudos": escudos, "altitud": _numero(altitud_max),
		"datos": datos, "bono_vida": bono_vida, "bono_dinero": bono_dinero,
		"puntaje": datos + bono_vida + bono_dinero,
	}


func _fallo() -> void:
	estado = "fallo"
	humo.emitting = false
	temblor = 0.8
	var t := create_tween().set_parallel(true)
	t.tween_property(nave, "scale", nave.scale * 1.6, 0.5)
	t.tween_property(nave, "modulate", Color(1, 0.3, 0.1, 0), 0.5)
	_texto_centro("MISIÓN FALLIDA", Color("ff5a5a"), 3.0)
	decir(DIALOGOS.fallo)
	get_tree().create_timer(2.5).timeout.connect(_mostrar_resultado.bind(false))


# ================= Escudo de energía =================

func _crear_burbuja() -> void:
	burbuja = Sprite2D.new()
	burbuja.texture = texturas["escudo"]
	var tam_mundo := alto_nave * 1.05
	burbuja.scale = Vector2.ONE * tam_mundo / burbuja.texture.get_size().x / nave.scale.x
	burbuja.modulate = Color(1, 1, 1, 0.45)
	burbuja.visible = escudo_proteccion > 0
	nave.add_child(burbuja)


# ================= Humo del motor =================

func _crear_humo(tex_nave: Texture2D) -> void:
	humo = CPUParticles2D.new()
	humo.amount = 70
	humo.lifetime = 0.9
	humo.local_coords = false
	humo.emitting = false
	humo.direction = Vector2(0, 1)
	humo.spread = 18.0
	humo.gravity = Vector2.ZERO
	humo.initial_velocity_min = 120.0 * k
	humo.initial_velocity_max = 200.0 * k
	humo.scale_amount_min = 3.0 * k
	humo.scale_amount_max = 7.0 * k
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 0.9, 0.5, 1), Color(1, 0.5, 0.2, 0.8), Color(0.55, 0.55, 0.6, 0)])
	humo.color_ramp = g
	humo.position = Vector2(0, tex_nave.get_size().y * 0.42)
	nave.add_child(humo)


# ================= HUD =================

func _etiqueta(tamano: float, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", int(tamano * k))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b0f24"))
	l.add_theme_constant_override("outline_size", int(6 * k))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_hud() -> void:
	capa_hud = CanvasLayer.new()
	add_child(capa_hud)

	lbl_nombre = _etiqueta(22, Color("f5c542"))
	lbl_nombre.text = datos_nave.nombre
	lbl_nombre.position = Vector2(18, 10) * k
	capa_hud.add_child(lbl_nombre)

	corazones = Control.new()
	corazones.position = Vector2(18, 44) * k
	corazones.size = Vector2(300, 24) * k
	corazones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corazones.draw.connect(_dibujar_corazones)
	capa_hud.add_child(corazones)

	lbl_maniobra = _etiqueta(13, Color("c9d3ff"))
	lbl_maniobra.position = Vector2(18, 70) * k
	capa_hud.add_child(lbl_maniobra)

	lbl_capa = _etiqueta(20, Color.WHITE)
	lbl_capa.position = Vector2(18, 98) * k
	capa_hud.add_child(lbl_capa)

	lbl_altitud = _etiqueta(15, Color("8fd3e8"))
	lbl_altitud.position = Vector2(18, 126) * k
	capa_hud.add_child(lbl_altitud)

	lbl_temp = _etiqueta(15, Color("ffb37a"))
	lbl_temp.position = Vector2(18, 148) * k
	capa_hud.add_child(lbl_temp)

	lbl_datos = _etiqueta(15, Color("8fd3e8"))
	lbl_datos.position = Vector2(18, 170) * k
	capa_hud.add_child(lbl_datos)

	lbl_centro = _etiqueta(64, Color.WHITE)
	lbl_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_centro.size = Vector2(pantalla.x, 90 * k)
	lbl_centro.position = Vector2(0, pantalla.y * 0.3)
	lbl_centro.pivot_offset = lbl_centro.size * 0.5
	lbl_centro.modulate.a = 0.0
	capa_hud.add_child(lbl_centro)

	lbl_aviso = _etiqueta(36, Color.WHITE)
	lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_aviso.size = Vector2(pantalla.x, 50 * k)
	lbl_aviso.position = Vector2(0, pantalla.y * 0.17)
	lbl_aviso.modulate.a = 0.0
	capa_hud.add_child(lbl_aviso)

	altimetro = Control.new()
	altimetro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	altimetro.position = Vector2(pantalla.x - 175 * k, 16 * k)
	altimetro.size = Vector2(160 * k, pantalla.y - 32 * k)
	altimetro.draw.connect(_dibujar_altimetro)
	capa_hud.add_child(altimetro)


func _actualizar_hud() -> void:
	var f := _fraccion_nave()
	var i := _indice_capa(f)
	lbl_altitud.text = "ALTITUD: %s km" % _numero(_altitud_km(f))
	lbl_temp.text = "TEMPERATURA: %d °C" % int(_interpolar(f, "temp"))
	lbl_datos.text = "DATOS CIENTÍFICOS: %d" % datos
	lbl_maniobra.text = "MANIOBRA %s  |  ESCUDO %d" % [Mision.maniobra_texto(id_nave), escudo_proteccion]
	if i != capa_actual and estado != "fallo":
		capa_actual = i
		lbl_capa.text = CAPAS[i].nombre
		lbl_capa.add_theme_color_override("font_color", CAPAS[i].color)
		if estado == "subiendo":
			datos += Mision.datos_por_capa(id_nave)
			_texto_flotante("+%d DATOS" % Mision.datos_por_capa(id_nave), Color("8fd3e8"))
			_mostrar_aviso(CAPAS[i].nombre, CAPAS[i].color)
			decir(DIALOGOS[CAPAS[i].nombre])
	corazones.queue_redraw()
	altimetro.queue_redraw()


func _numero(km: float) -> String:
	if km < 100.0:
		return "%.1f" % km
	var s := str(int(km))
	return s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3) if km >= 1000.0 else s


func _texto_centro(texto: String, color: Color, duracion: float = 0.8) -> void:
	lbl_centro.text = texto
	lbl_centro.add_theme_color_override("font_color", color)
	lbl_centro.modulate.a = 1.0
	lbl_centro.scale = Vector2.ONE * 1.4
	var t := create_tween()
	t.tween_property(lbl_centro, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(duracion)
	t.tween_property(lbl_centro, "modulate:a", 0.0, 0.4)


func _mostrar_aviso(texto: String, color: Color) -> void:
	lbl_aviso.text = texto
	lbl_aviso.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_property(lbl_aviso, "modulate:a", 1.0, 0.4)
	t.tween_interval(2.0)
	t.tween_property(lbl_aviso, "modulate:a", 0.0, 0.6)


func _texto_flotante(texto: String, color: Color) -> void:
	var l := _etiqueta(26, color)
	l.text = texto
	l.position = nave.position + Vector2(ancho_nave * 0.6, -alto_nave * 0.4)
	mundo.add_child(l)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 60 * k, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.9)
	t.chain().tween_callback(l.queue_free)


func _dibujar_corazones() -> void:
	var p := 3.0 * k
	for i in vida_max:
		var x0 := i * (CORAZON[0].length() + 2) * p
		var color := Color("ff4d5e") if i < vida else Color(0.2, 0.22, 0.32, 0.9)
		for fila in CORAZON.size():
			for col in CORAZON[fila].length():
				if CORAZON[fila][col] == "1":
					corazones.draw_rect(Rect2(x0 + col * p, fila * p, p, p), color)


func _dibujar_altimetro() -> void:
	var alto := altimetro.size.y
	var x_barra := altimetro.size.x - 20 * k
	var ancho := 12 * k
	var tam := int(12 * k)
	altimetro.draw_rect(Rect2(x_barra - 2 * k, -2 * k, ancho + 4 * k, alto + 4 * k), Color(0.04, 0.06, 0.14, 0.8))
	var desde := 0.0
	for c in CAPAS:
		var y_arriba: float = alto * (1.0 - c.hasta)
		var y_abajo: float = alto * (1.0 - desde)
		var col: Color = c.color
		col.a = 0.55
		altimetro.draw_rect(Rect2(x_barra, y_arriba, ancho, y_abajo - y_arriba), col)
		var y_texto: float = (y_arriba + y_abajo) * 0.5 + tam * 0.35
		var w_texto := fuente.get_string_size(c.nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var pos := Vector2(x_barra - 8 * k - w_texto, y_texto)
		altimetro.draw_string_outline(fuente, pos, c.nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, int(4 * k), Color("0b0f24"))
		altimetro.draw_string(fuente, pos, c.nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, c.color)
		desde = c.hasta
	var y_nave := alto * (1.0 - _fraccion_nave())
	var punta := Vector2(x_barra - 3 * k, y_nave)
	altimetro.draw_colored_polygon(PackedVector2Array([punta, punta + Vector2(-10, -6) * k, punta + Vector2(-10, 6) * k]), Color.WHITE)
	altimetro.draw_rect(Rect2(x_barra - 2 * k, y_nave - 1.5 * k, ancho + 4 * k, 3 * k), Color.WHITE)


# ================= Albertsahur =================

func _crear_dialogo() -> void:
	tex_normal = _cargar("res://assets/personajes/astronauta.png")
	tex_hablando = _cargar("res://assets/personajes/astronauta_hablando.png")
	tex_parpadeo = _cargar("res://assets/personajes/astronauta_parpadeo.png")

	var caja := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.06, 0.15, 0.88)
	estilo.border_color = Color("6a76a8")
	estilo.set_border_width_all(max(1, int(2 * k)))
	estilo.set_content_margin_all(int(6 * k))
	caja.add_theme_stylebox_override("panel", estilo)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.position = Vector2(14 * k, pantalla.y - 104 * k)
	caja.custom_minimum_size = Vector2(540 * k, 90 * k)
	capa_hud.add_child(caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(8 * k))
	caja.add_child(fila)

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(78 * k, 70 * k)
	hueco.clip_contents = true
	fila.add_child(hueco)
	retrato = TextureRect.new()
	retrato.texture = tex_normal
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hueco.add_child(retrato)
	retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(2 * k))
	fila.add_child(col)
	var nombre := _etiqueta(13, Color("f5c542"))
	nombre.text = "ALBERTSAHUR"
	col.add_child(nombre)
	lbl_dialogo = _etiqueta(15, Color("f4eefc"))
	lbl_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_dialogo.custom_minimum_size.x = 420 * k
	col.add_child(lbl_dialogo)


## Albertsahur dice estas líneas (reemplaza lo que estaba diciendo).
## Avanzan solas; "despues" se llama al terminar la última.
func decir(lineas: Array, despues: Callable = Callable()) -> void:
	cola = lineas.duplicate()
	al_terminar = despues
	_siguiente_linea()


func _siguiente_linea() -> void:
	if cola.is_empty():
		var f := al_terminar
		al_terminar = Callable()
		if f.is_valid():
			f.call()
		return
	lbl_dialogo.text = cola.pop_front()
	lbl_dialogo.visible_characters = 0
	letras = 0.0
	espera = 1.8 + lbl_dialogo.text.length() * 0.025   # tiempo para leer


func _actualizar_dialogo(delta: float) -> void:
	var total := lbl_dialogo.get_total_character_count()
	var hablando := lbl_dialogo.visible_characters < total
	if hablando:
		letras = min(letras + 45.0 * delta, total)
		lbl_dialogo.visible_characters = int(letras)
		reloj_boca += delta
		if reloj_boca >= 0.11:
			reloj_boca = 0.0
			boca_abierta = not boca_abierta
		retrato.texture = tex_hablando if boca_abierta else tex_normal
		var salto: float = round(abs(sin(tiempo * 14.0)) * 2.0 * k)
		retrato.offset_top = -salto
		retrato.offset_bottom = -salto
	else:
		retrato.offset_top = 0
		retrato.offset_bottom = 0
		parpadeo -= delta
		if parpadeo <= 0.0:
			retrato.texture = tex_parpadeo
			if parpadeo <= -0.12:
				parpadeo = randf_range(2.0, 4.5)
		else:
			retrato.texture = tex_normal
		if total > 0 and (not cola.is_empty() or al_terminar.is_valid()):
			espera -= delta
			if espera <= 0.0:
				_siguiente_linea()


# ================= Resultado =================

func _mostrar_resultado(gano: bool) -> void:
	var fondo_panel := ColorRect.new()
	fondo_panel.color = Color(0, 0, 0, 0.55)
	fondo_panel.size = pantalla
	capa_hud.add_child(fondo_panel)

	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("0b1026")
	estilo.border_color = Color("f5c542") if gano else Color("ff5a5a")
	estilo.set_border_width_all(max(1, int(3 * k)))
	estilo.set_content_margin_all(int(18 * k))
	panel.add_theme_stylebox_override("panel", estilo)
	capa_hud.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * k))
	panel.add_child(v)
	var titulo := _etiqueta(34, Color("f5c542") if gano else Color("ff5a5a"))
	titulo.text = "¡MISIÓN CUMPLIDA!" if gano else "MISIÓN FALLIDA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var info := _etiqueta(16, Color("f4eefc"))
	var r := _calcular_resultado(gano)
	var puntaje: int = r.puntaje
	info.text = "Nave: %s\nResistencia restante: %d / %d   (+%d)\nGolpes recibidos: %d  |  Escudos recogidos: %d\nAltitud máxima: %s km\nDatos científicos: %d\nPresupuesto sin usar: %s   (+%d)" % [
		r.nave, r.vida, r.vida_max, r.bono_vida, r.golpes, r.escudos, r.altitud,
		r.datos, Mision.dinero(Mision.presupuesto_restante), r.bono_dinero]
	v.add_child(info)
	var lbl_puntaje := _etiqueta(28, Color("f5c542"))
	lbl_puntaje.text = "PUNTAJE: %d" % puntaje
	lbl_puntaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_puntaje)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", int(10 * k))
	v.add_child(botones)
	if gano and ESCENA_SIGUIENTE != "" and ResourceLoader.exists(ESCENA_SIGUIENTE):
		botones.add_child(_boton("CONTINUAR", _ir_a.bind(ESCENA_SIGUIENTE)))
	botones.add_child(_boton("JUGAR OTRA VEZ" if gano else "REINTENTAR", _reintentar))
	botones.add_child(_boton("TALLER", _ir_a.bind(ESCENA_TALLER)))
	botones.add_child(_boton("CAMBIAR NAVE", _ir_a.bind(ESCENA_SELECCION)))
	botones.add_child(_boton("MENÚ", _ir_a.bind(ESCENA_MENU)))

	# Centrar el panel cuando ya sabe su tamaño
	await get_tree().process_frame
	panel.position = (pantalla - panel.size) * 0.5


func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_override("font", fuente)
	b.add_theme_font_size_override("font_size", int(15 * k))
	b.custom_minimum_size = Vector2(0, 36 * k)
	b.pressed.connect(accion)
	return b


func _reintentar() -> void:
	get_tree().reload_current_scene()


func _ir_a(ruta: String) -> void:
	if ResourceLoader.exists(ruta):
		get_tree().change_scene_to_file(ruta)
	else:
		push_warning("No existe " + ruta)
