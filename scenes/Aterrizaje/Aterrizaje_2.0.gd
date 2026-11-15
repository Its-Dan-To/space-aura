extends Node2D
## Aterrizaje_2.0.gd — Minijuego de alunizaje 2D estilo Lunar Lander (escena Aterrizaje_2.0.tscn).
## Física en UNIDADES REALES (metros, segundos, kilogramos) basada en la fase de
## "descenso terminal" del Módulo Lunar Apolo: empieza a 150 m de altura y termina en el toque.
## Combustible e integridad son LOCALES. La nave usa la gráfica del Módulo Lunar (no necesita Autoloads).

signal mision_completada  # Útil para avanzar a la siguiente escena del juego.

# ---------------- FÍSICA REAL (valores aproximados del Módulo Lunar Apolo) ----------------
const GRAVEDAD_LUNAR := 1.62        # m/s² (≈ 1/6 de la gravedad terrestre)
const G0 := 9.81                    # m/s², gravedad estándar (para el cálculo con Isp)
# El motor de descenso daba ~45 kN máx. y era regulable; cerca del suelo se usaba aprox. la mitad.
const EMPUJE_MOTOR := 25000.0       # N
const ISP_MOTOR := 311.0            # s, impulso específico del motor de descenso (aprox.)
const MASA_SECA := 6800.0           # kg, módulo sin el combustible restante (aprox.)
const ACEL_LATERAL := 2.0           # m/s², propulsores de control (RCS) para desplazarse
const VEL_HORIZONTAL_TOPE := 8.0    # m/s, tope de velocidad lateral
const CONSUMO_LATERAL := 0.8        # kg/s mientras se usan los RCS

# ---------------- ESCENARIO ----------------
const ALTURA_INICIAL := 150.0       # m: inicio del descenso terminal
const VEL_VERTICAL_INICIAL := 4.0   # m/s hacia abajo al empezar
const DERIVA_INICIAL_MAX := 2.0     # m/s de deriva horizontal aleatoria al empezar
const PIXELES_POR_METRO := 3.3      # escala: 150 m ≈ 495 px de pantalla

# ---------------- CRITERIOS DE ALUNIZAJE ----------------
const VEL_TOQUE_IDEAL := 1.0        # m/s (~3.6 km/h): toque perfecto, como en Apolo
const VEL_TOQUE_MAX := 3.0          # m/s (~10 ft/s): límite del tren de aterrizaje
const VEL_HORIZONTAL_MAX := 1.2     # m/s: con más deriva lateral la nave puede volcarse
const ALTURA_SONDAS := 1.7          # m: sondas bajo las patas -> se enciende "CONTACT LIGHT"
const DANO_IMPACTO := 25.0          # se resta a la integridad en cada choque
const VEL_MAX_BARRA := 10.0         # m/s, tope visual de la barra de velocidad

const COLOR_OK := Color(0.4, 1.0, 0.4)
const COLOR_ALERTA := Color(1.0, 0.85, 0.3)
const COLOR_PELIGRO := Color(1.0, 0.35, 0.3)

# ---------------- REFERENCIAS A NODOS ----------------
@onready var nave: CharacterBody2D = $Nave
@onready var cuerpo_nave: ColorRect = $Nave/Cuerpo
@onready var ventana_nave: ColorRect = $Nave/Ventana
@onready var sprite_nave: Sprite2D = $Nave/SpriteNave
@onready var llama: ColorRect = $Nave/Llama   # placeholder viejo (se oculta; ahora hay partículas)
@onready var zona_segura: Area2D = $Suelo/ZonaSegura
@onready var fondo_imagen: TextureRect = $FondoImagen

@onready var label_altitud: Label = get_node_or_null("UI/Panel/VBox/LabelAltitud")  # se crea si falta
@onready var barra_combustible: ProgressBar = $UI/Panel/VBox/BarraCombustible
@onready var label_combustible: Label = $UI/Panel/VBox/LabelCombustible
@onready var barra_velocidad: ProgressBar = $UI/Panel/VBox/BarraVelocidad
@onready var label_velocidad: Label = $UI/Panel/VBox/LabelVelocidad
@onready var label_horizontal: Label = get_node_or_null("UI/Panel/VBox/LabelHorizontal")  # se crea si falta
@onready var label_integridad: Label = $UI/Panel/VBox/LabelIntegridad
@onready var aviso: Label = get_node_or_null("UI/Aviso")  # se crea si falta
@onready var mensaje: Label = $UI/Mensaje

# ---------------- VARIABLES LOCALES ----------------
## Combustible de descenso restante al empezar, en kg.
@export var combustible_maximo: float = 250.0
## Integridad con la que empieza la misión.
@export var integridad_maxima: float = 100.0
## Acelera el tiempo de la simulación (1.0 = tiempo real, ~1 min de descenso; 3.0 = ~20 s).
@export var escala_tiempo: float = 3.0
## Si es true, el motor se apaga solo al encenderse "CONTACT LIGHT" (como en Apolo).
@export var apagado_automatico_en_contacto: bool = false
## Ruta de la imagen de fondo. Cámbiala si guardas la imagen en otra carpeta.
@export_file("*.jpg", "*.png") var ruta_fondo: String = "res://scenes/Aterrizaje/fondo_luna2.jpg"
## Imagen del Módulo Lunar que usa el jugador.
@export_file("*.png") var ruta_modulo_lunar: String = "res://assets/naves/modulo_lunar.png"
## Altura en píxeles a la que se escala el sprite de la nave.
@export var alto_sprite_nave: float = 40.0  # igual al alto de la colisión (30x40)

var combustible: float = 0.0          # kg restantes en este intento
var integridad: float = 0.0           # se conserva entre intentos
var vel: Vector2 = Vector2.ZERO       # velocidad REAL en m/s (y positivo = hacia abajo)
var altitud: float = 0.0              # m sobre la plataforma
var contacto := false                 # ya se encendió CONTACT LIGHT
var aviso_60 := false
var aviso_30 := false
var aviso_restante: float = 0.0       # segundos que queda visible el aviso

var terminado := false
var posicion_inicial := Vector2.ZERO
var tope_plataforma: float = 0.0      # y (px) de la superficie de la plataforma
var mitad_alto_nave: float = 0.0      # px

# Efectos de los propulsores (se crean por código)
var fuego: CPUParticles2D             # motor principal, abajo
var rcs_izq: CPUParticles2D           # chorro lateral izquierdo (empuja a la derecha)
var rcs_der: CPUParticles2D           # chorro lateral derecho (empuja a la izquierda)


func _ready() -> void:
	_crear_nodos_faltantes()
	posicion_inicial = nave.position
	integridad = integridad_maxima

	var forma_zona: RectangleShape2D = $Suelo/ZonaSegura/CollisionShape2D.shape
	var forma_nave: RectangleShape2D = $Nave/CollisionShape2D.shape
	tope_plataforma = zona_segura.global_position.y - forma_zona.size.y / 2.0
	mitad_alto_nave = forma_nave.size.y / 2.0
	_crear_efectos_propulsores()

	barra_combustible.max_value = max(combustible_maximo, 1.0)
	barra_velocidad.max_value = VEL_MAX_BARRA
	_cargar_fondo()
	_cargar_modelo_nave()
	_reiniciar_intento()


## Si la escena es una versión anterior y le faltan las etiquetas nuevas, las crea por código.
func _crear_nodos_faltantes() -> void:
	var vbox: VBoxContainer = $UI/Panel/VBox
	if label_altitud == null:
		label_altitud = Label.new()
		label_altitud.name = "LabelAltitud"
		vbox.add_child(label_altitud)
		vbox.move_child(label_altitud, 0)  # primera del panel
	if label_horizontal == null:
		label_horizontal = Label.new()
		label_horizontal.name = "LabelHorizontal"
		vbox.add_child(label_horizontal)
		vbox.move_child(label_horizontal, label_integridad.get_index())  # antes de la integridad
	if aviso == null:
		aviso = Label.new()
		aviso.name = "Aviso"
		aviso.visible = false
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso.add_theme_font_size_override("font_size", 28)
		$UI.add_child(aviso)
		aviso.set_anchors_preset(Control.PRESET_TOP_WIDE)
		aviso.offset_top = 24.0
		aviso.offset_bottom = 64.0


## Pone la nave a 150 m con el tanque lleno, sin tocar la integridad.
func _reiniciar_intento() -> void:
	combustible = combustible_maximo
	nave.position.x = posicion_inicial.x
	nave.global_position.y = tope_plataforma - mitad_alto_nave - ALTURA_INICIAL * PIXELES_POR_METRO
	vel = Vector2(randf_range(-DERIVA_INICIAL_MAX, DERIVA_INICIAL_MAX), VEL_VERTICAL_INICIAL)
	nave.velocity = Vector2.ZERO
	nave.modulate = Color.WHITE
	_apagar_propulsores()
	mensaje.visible = false
	contacto = false
	aviso_60 = false
	aviso_30 = false
	terminado = false
	_mostrar_aviso(TranslationServer.translate("DESCENSO TERMINAL — %d m") % int(ALTURA_INICIAL), Color.WHITE, 3.0)
	_actualizar_ui()


# ---------------- APARIENCIA ----------------

func _cargar_fondo() -> void:
	if ruta_fondo != "" and ResourceLoader.exists(ruta_fondo):
		fondo_imagen.texture = load(ruta_fondo)
	else:
		push_warning("No se encontró la imagen de fondo: %s (se usa el color liso)" % ruta_fondo)


func _cargar_modelo_nave() -> void:
	# Gráfica del Módulo Lunar (en vez de la cápsula de la nave elegida)
	if ruta_modulo_lunar == "" or not ResourceLoader.exists(ruta_modulo_lunar):
		push_warning("No se encontró la imagen del módulo lunar: %s (se usa el placeholder)" % ruta_modulo_lunar)
		return

	var textura: Texture2D = load(ruta_modulo_lunar)
	sprite_nave.texture = textura
	sprite_nave.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art nítido
	sprite_nave.visible = true
	# Escalar para que mida 'alto_sprite_nave' px de alto, sin deformarlo
	var alto_textura: float = float(textura.get_height())
	if alto_textura > 0.0:
		var escala: float = alto_sprite_nave / alto_textura
		sprite_nave.scale = Vector2(escala, escala)
	# Oculta los cuadros de color placeholder
	cuerpo_nave.visible = false
	ventana_nave.visible = false


# ---------------- EFECTOS DE PROPULSORES ----------------

func _crear_efectos_propulsores() -> void:
	llama.visible = false

	# Motor principal: llamarada amarilla -> naranja -> roja que se desvanece
	var rampa_fuego := Gradient.new()
	rampa_fuego.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	rampa_fuego.colors = PackedColorArray([Color(1, 1, 0.8, 1), Color(1, 0.6, 0.15, 0.9), Color(0.8, 0.2, 0.1, 0)])
	fuego = _crear_particulas(Vector2(0, mitad_alto_nave), Vector2(0, 1), rampa_fuego, 60, 0.35, 70.0, 120.0, 12.0, 2.0, 4.5)

	# Propulsores laterales (RCS): soplidos cortos de gas blanco
	var rampa_gas := Gradient.new()
	rampa_gas.offsets = PackedFloat32Array([0.0, 1.0])
	rampa_gas.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(0.8, 0.85, 1, 0)])
	rcs_izq = _crear_particulas(Vector2(-15, -4), Vector2(-1, 0), rampa_gas, 16, 0.25, 40.0, 70.0, 20.0, 1.5, 3.0)
	rcs_der = _crear_particulas(Vector2(15, -4), Vector2(1, 0), rampa_gas, 16, 0.25, 40.0, 70.0, 20.0, 1.5, 3.0)


func _crear_particulas(pos: Vector2, direccion: Vector2, rampa: Gradient, cantidad: int, vida: float, vel_min: float, vel_max: float, apertura: float, escala_min: float, escala_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.amount = cantidad
	p.lifetime = vida
	p.local_coords = false          # el rastro se queda atrás cuando la nave se mueve
	p.direction = direccion
	p.spread = apertura
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min = escala_min
	p.scale_amount_max = escala_max
	p.color_ramp = rampa
	nave.add_child(p)
	return p


func _apagar_propulsores() -> void:
	llama.visible = false
	if fuego != null:
		fuego.emitting = false
		rcs_izq.emitting = false
		rcs_der.emitting = false


# ---------------- FÍSICA ----------------

## Masa total actual: al quemar combustible la nave se aligera y el motor la empuja más.
func _masa_total() -> float:
	return MASA_SECA + combustible


## Segundos de combustible si se mantuviera la nave flotando (como los avisos de Apolo 11).
func _segundos_de_vuelo() -> float:
	var flujo_flotando: float = (_masa_total() * GRAVEDAD_LUNAR) / (ISP_MOTOR * G0)  # kg/s
	return combustible / flujo_flotando


func _physics_process(delta_real: float) -> void:
	_actualizar_aviso(delta_real)
	if terminado:
		return
	var delta: float = delta_real * escala_tiempo

	# --- Gravedad lunar ---
	var acel := Vector2(0.0, GRAVEDAD_LUNAR)

	# --- Propulsores laterales (RCS): hay inercia, para frenar hay que empujar al lado contrario ---
	var dir_x := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		dir_x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		dir_x += 1.0
	var usando_rcs: bool = dir_x != 0.0 and combustible > 0.0
	if usando_rcs:
		acel.x += dir_x * ACEL_LATERAL
		combustible = max(combustible - CONSUMO_LATERAL * delta, 0.0)

	# --- Motor de descenso: F = m·a  ->  a = F / m ---
	var quiere_propulsar: bool = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	var motor_permitido: bool = not (apagado_automatico_en_contacto and contacto)
	var propulsando: bool = quiere_propulsar and combustible > 0.0 and motor_permitido

	if propulsando:
		acel.y -= EMPUJE_MOTOR / _masa_total()
		# Consumo real del motor: flujo de masa = F / (Isp · g0)
		var flujo: float = EMPUJE_MOTOR / (ISP_MOTOR * G0)
		combustible = max(combustible - flujo * delta, 0.0)

	# Efectos visuales de los propulsores
	fuego.emitting = propulsando
	rcs_izq.emitting = usando_rcs and dir_x > 0.0
	rcs_der.emitting = usando_rcs and dir_x < 0.0

	# --- Integrar velocidad (m/s) y convertir a píxeles para mover la nave ---
	vel += acel * delta
	vel.x = clamp(vel.x, -VEL_HORIZONTAL_TOPE, VEL_HORIZONTAL_TOPE)
	nave.velocity = vel * PIXELES_POR_METRO * escala_tiempo
	nave.move_and_slide()
	_limitar_a_pantalla()

	# --- Altitud sobre la plataforma ---
	var fondo_nave: float = nave.global_position.y + mitad_alto_nave
	altitud = max((tope_plataforma - fondo_nave) / PIXELES_POR_METRO, 0.0)

	_revisar_avisos()
	_actualizar_ui()


func _limitar_a_pantalla() -> void:
	var ancho: float = get_viewport_rect().size.x
	if nave.position.x < 15.0 or nave.position.x > ancho - 15.0:
		nave.position.x = clamp(nave.position.x, 15.0, ancho - 15.0)
		vel.x = 0.0
	if nave.position.y < 20.0:
		nave.position.y = 20.0
		vel.y = max(vel.y, 0.0)


# ---------------- AVISOS DE MISIÓN ----------------

func _revisar_avisos() -> void:
	if not contacto and altitud <= ALTURA_SONDAS:
		contacto = true
		var texto := "CONTACT LIGHT"
		if apagado_automatico_en_contacto:
			texto += TranslationServer.translate(" — motor apagado")
		_mostrar_aviso(texto, Color(0.5, 0.8, 1.0), 2.0)
		return

	var segundos: float = _segundos_de_vuelo()
	if combustible <= 0.0:
		_mostrar_aviso("SIN COMBUSTIBLE", COLOR_PELIGRO, 0.5)
	elif segundos <= 30.0 and not aviso_30:
		aviso_30 = true
		_mostrar_aviso("¡30 SEGUNDOS!", COLOR_PELIGRO, 2.5)
	elif segundos <= 60.0 and not aviso_60:
		aviso_60 = true
		_mostrar_aviso("60 SEGUNDOS", COLOR_ALERTA, 2.5)


func _mostrar_aviso(texto: String, color: Color, duracion: float) -> void:
	aviso.text = texto
	aviso.modulate = color
	aviso.visible = true
	aviso_restante = duracion


func _actualizar_aviso(delta: float) -> void:
	if aviso_restante > 0.0:
		aviso_restante -= delta
		if aviso_restante <= 0.0:
			aviso.visible = false


# ---------------- INTERFAZ ----------------

func _color_por_velocidad(v: float, ideal: float, maximo: float) -> Color:
	if v <= ideal:
		return COLOR_OK
	if v <= maximo:
		return COLOR_ALERTA
	return COLOR_PELIGRO


func _actualizar_ui() -> void:
	label_altitud.text = TranslationServer.translate("Altitud: %.1f m") % altitud

	# Combustible en kg y en segundos de vuelo estacionario
	barra_combustible.value = combustible
	label_combustible.text = TranslationServer.translate("Combustible: %d kg  (~%d s)") % [ceili(combustible), int(_segundos_de_vuelo())]
	label_combustible.modulate = COLOR_PELIGRO if _segundos_de_vuelo() <= 30.0 else Color.WHITE

	# Velocidad vertical (solo cuenta si baja), en m/s y km/h
	var v_baja: float = max(vel.y, 0.0)
	barra_velocidad.value = min(v_baja, VEL_MAX_BARRA)
	label_velocidad.text = TranslationServer.translate("Vel. vertical: %.1f m/s  (%.1f km/h)") % [vel.y, vel.y * 3.6]
	var color_v: Color = _color_por_velocidad(v_baja, VEL_TOQUE_IDEAL, VEL_TOQUE_MAX)
	label_velocidad.modulate = color_v
	barra_velocidad.modulate = color_v

	# Velocidad horizontal
	label_horizontal.text = TranslationServer.translate("Vel. horizontal: %.1f m/s") % vel.x
	label_horizontal.modulate = COLOR_OK if absf(vel.x) <= VEL_HORIZONTAL_MAX else COLOR_PELIGRO

	label_integridad.text = TranslationServer.translate("Integridad de la nave: %d%%") % roundi(integridad)


# ---------------- SEÑALES (body_entered) ----------------

## Conectada desde Suelo/ZonaSegura -> body_entered
func _on_zona_segura_body_entered(body: Node2D) -> void:
	if body != nave or terminado:
		return
	var v_toque: float = vel.y
	var deriva: float = absf(vel.x)

	if v_toque > VEL_TOQUE_MAX:
		_fallo(TranslationServer.translate("¡Impacto brusco!\nToque a %.1f m/s (máx. %.1f m/s)") % [v_toque, VEL_TOQUE_MAX])
	elif deriva > VEL_HORIZONTAL_MAX:
		_fallo(TranslationServer.translate("¡Volcadura!\nDeriva lateral de %.1f m/s (máx. %.1f m/s)") % [deriva, VEL_HORIZONTAL_MAX])
	elif v_toque <= VEL_TOQUE_IDEAL:
		_victoria(TranslationServer.translate("¡Alunizaje perfecto!\nToque a %.1f m/s (%.1f km/h)") % [v_toque, v_toque * 3.6])
	else:
		_victoria(TranslationServer.translate("Alunizaje exitoso (toque firme)\nToque a %.1f m/s (%.1f km/h)") % [v_toque, v_toque * 3.6])


## Conectada desde ZonaPeligrosaIzq y ZonaPeligrosaDer -> body_entered
func _on_zona_peligrosa_body_entered(body: Node2D) -> void:
	if body != nave or terminado:
		return
	_fallo("¡Caíste en un cráter!\nAlunizaje fuera de la plataforma")


# ---------------- RESULTADOS ----------------

func _detener_nave() -> void:
	terminado = true
	vel = Vector2.ZERO
	nave.velocity = Vector2.ZERO
	_apagar_propulsores()


func _victoria(texto: String) -> void:
	_detener_nave()
	nave.global_position.y = tope_plataforma - mitad_alto_nave  # asentar sobre la plataforma
	altitud = 0.0
	_mostrar_mensaje(TranslationServer.translate("%s\nCombustible restante: %d kg") % [texto, ceili(combustible)], COLOR_OK)
	_actualizar_ui()
	# Bitácora: alunizaje exitoso
	var bitacora = get_node_or_null("/root/Bitacora")
	if bitacora:
		bitacora.desbloquear_entrada("lunar_craters")
	mision_completada.emit()


func _fallo(texto: String) -> void:
	_detener_nave()
	nave.modulate = COLOR_PELIGRO
	integridad = max(integridad - DANO_IMPACTO, 0.0)

	if integridad <= 0.0:
		texto += TranslationServer.translate("\n\nNAVE DESTRUIDA - Misión fallida\n\nPresiona R para reiniciar la misión")
	else:
		texto += TranslationServer.translate("\n-%d de integridad\n\nPresiona R para reintentar") % int(DANO_IMPACTO)
	_mostrar_mensaje(texto, COLOR_PELIGRO)
	_actualizar_ui()


func _mostrar_mensaje(texto: String, color: Color) -> void:
	mensaje.text = texto
	mensaje.modulate = color
	mensaje.visible = true


# ---------------- REINICIO ----------------

func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_R:
		if integridad <= 0.0:
			get_tree().reload_current_scene()
		else:
			_reiniciar_intento()
