extends Node2D
## AterrizajeTierra.gd — Reentrada atmosférica y amerizaje (minijuego 2D, resolución 640x360).
##   Fase 1 (REENTRADA): el escudo térmico se calienta si la cápsula sale del corredor seguro.
##   Fase 2 (PARACAÍDAS): desplegar el paracaídas a tiempo y contrarrestar el viento
##                        para caer en la zona de rescate.
## Usa los Autoloads "Global" (integridad_nave) y "Mision" (nave_elegida) si existen.
## Si se prueba aislado con F6 y no están, funciona con valores de respaldo locales.
## La escena está dibujada a 640x360 y se ESCALA SOLA a cualquier tamaño de ventana
## (cámara + UI), sin cambiar la configuración del proyecto.

signal mision_completada

enum Fase { REENTRADA, PARACAIDAS, TERMINADO }

const RESOLUCION_BASE := Vector2(640.0, 360.0)  # tamaño en el que está dibujada la escena

# ---------------- ALTURAS CLAVE (px, pantalla de 640x360) ----------------
const Y_INICIO := 24.0               # donde aparece la cápsula
const Y_FASE_2 := 170.0              # fin del calor de reentrada -> alerta de paracaídas
const Y_LIMITE_PARACAIDAS := 260.0   # más abajo ya es demasiado tarde para abrirlo
const Y_OCEANO := 322.0              # superficie del agua

# ---------------- FASE 1: REENTRADA ----------------
const VEL_CAIDA_REENTRADA := 16.0    # px/s de descenso constante
const TURBULENCIA_MAX := 70.0        # px/s² de empuje lateral aleatorio
const CALOR_FUERA := 45.0            # % por segundo fuera del corredor
const ENFRIAMIENTO_DENTRO := 12.0    # % por segundo dentro del corredor

# ---------------- FASE 2: PARACAÍDAS Y VIENTO ----------------
const GRAVEDAD_SIN_PARACAIDAS := 25.0   # px/s²: sin paracaídas la cápsula acelera
const VEL_MAX_SIN_PARACAIDAS := 95.0    # px/s
const VEL_CON_PARACAIDAS := 14.0        # px/s: descenso suave con paracaídas
const FRENADO_PARACAIDAS := 120.0       # px/s²: qué tan rápido frena al abrirse
const VIENTO_MIN := 70.0                # px/s² de empuje del viento (fuerte)
const VIENTO_MAX := 120.0
const VEL_AMERIZAJE_SEGURA := 25.0      # px/s máximos para tocar el agua sin daño

# ---------------- CONTROL LATERAL ----------------
const ACEL_LATERAL := 240.0          # px/s² con A/D o flechas (más que el viento máximo)
const ARRASTRE_LATERAL := 1.5        # resistencia del aire: frena el movimiento lateral
const VEL_LATERAL_MAX := 140.0       # px/s: suficiente para cruzar hasta el barco
const DANO_FALLO := 25.0

# ---------------- DATOS REALES PARA LA UI (valores aproximados de Apolo) ----------------
const KM_INICIO := 120.0             # interfaz de reentrada (~120 km de altura)
const KM_FASE_2 := 7.0               # paracaídas de frenado (~7 km de altura)
const VIENTO_A_KMH := 0.8            # conversión solo para mostrar el viento en km/h

const COLOR_OK := Color(0.4, 1.0, 0.4)
const COLOR_ALERTA := Color(1.0, 0.85, 0.3)
const COLOR_PELIGRO := Color(1.0, 0.35, 0.3)
const COLOR_CALOR := Color(1.0, 0.4, 0.1)

# ---------------- REFERENCIAS A NODOS ----------------
@onready var capsula: CharacterBody2D = $Capsula
@onready var visual_capsula: Node2D = $Capsula/Visual
@onready var sprite_capsula: Sprite2D = $Capsula/Visual/Sprite
@onready var placeholder_capsula: ColorRect = $Capsula/Visual/Placeholder
@onready var paracaidas: ColorRect = $Capsula/Paracaidas
@onready var forma_capsula: CollisionShape2D = $Capsula/CollisionShape2D
@onready var corredor: ColorRect = $Corredor
@onready var camara: Camera2D = $Camara
@onready var ui: CanvasLayer = $UI

@onready var label_altitud: Label = $UI/Panel/VBox/LabelAltitud
@onready var barra_altitud: ProgressBar = $UI/Panel/VBox/BarraAltitud
@onready var label_temperatura: Label = $UI/Panel/VBox/LabelTemperatura
@onready var barra_temperatura: ProgressBar = $UI/Panel/VBox/BarraTemperatura
@onready var label_paracaidas: Label = $UI/Panel/VBox/LabelParacaidas
@onready var label_viento: Label = $UI/Panel/VBox/LabelViento
@onready var label_integridad: Label = $UI/Panel/VBox/LabelIntegridad
@onready var alerta: Label = $UI/Alerta
@onready var mensaje: Label = $UI/Mensaje

# ---------------- OPCIONES EN EL INSPECTOR ----------------
## Nave que se usa si no existe Mision.nave_elegida (prueba aislada con F6).
@export var nave_por_defecto: String = "apollo11"
## Opcional: ruta exacta a un sprite. Si está vacía, se busca "<nave>_capsula.png" en el proyecto.
@export_file("*.png") var ruta_sprite_manual: String = ""
## Altura en píxeles a la que se escala el sprite de la cápsula.
@export var alto_sprite: float = 22.0

# ---------------- ESTADO ----------------
var fase: Fase = Fase.REENTRADA
var vel := Vector2.ZERO
var temperatura: float = 0.0
var paracaidas_abierto := false
var demasiado_tarde := false
var viento: float = 0.0
var turbulencia: float = 0.0
var tiempo_turbulencia: float = 0.0
var integridad_local: float = 100.0   # respaldo si no existe Global
var corredor_min: float = 0.0
var corredor_max: float = 0.0
var mitad_alto_capsula: float = 9.0
var tiempo: float = 0.0
var alerta_temporal_texto: String = ""
var alerta_temporal_color := Color.WHITE
var alerta_temporal_restante: float = 0.0


func _ready() -> void:
	_ajustar_escala()
	get_viewport().size_changed.connect(_ajustar_escala)  # si cambian el tamaño de la ventana
	corredor_min = corredor.position.x
	corredor_max = corredor.position.x + corredor.size.x
	var forma: RectangleShape2D = forma_capsula.shape
	mitad_alto_capsula = forma.size.y / 2.0
	barra_altitud.max_value = 100.0
	barra_temperatura.max_value = 100.0
	_cargar_sprite_capsula()
	_reiniciar_intento()


func _reiniciar_intento() -> void:
	fase = Fase.REENTRADA
	# Empieza en el centro del corredor (lado izquierdo)
	capsula.position = Vector2((corredor_min + corredor_max) / 2.0, Y_INICIO)
	vel = Vector2(randf_range(-20.0, 20.0), VEL_CAIDA_REENTRADA)
	capsula.velocity = Vector2.ZERO
	temperatura = 0.0
	paracaidas_abierto = false
	demasiado_tarde = false
	paracaidas.visible = false
	viento = 0.0
	turbulencia = 0.0
	tiempo_turbulencia = 0.0
	visual_capsula.modulate = Color.WHITE
	mensaje.visible = false
	alerta_temporal_restante = 0.0
	_mostrar_alerta_temporal("REENTRADA ATMOSFÉRICA", Color.WHITE, 2.0)
	_actualizar_ui()


# ---------------- ESCALA A PANTALLA COMPLETA ----------------

## Agranda la escena (640x360) para llenar la ventana sin deformarla.
## Si la ventana tiene otra proporción, quedan franjas negras a los lados o arriba/abajo.
func _ajustar_escala() -> void:
	var tam: Vector2 = get_viewport_rect().size
	var factor: float = min(tam.x / RESOLUCION_BASE.x, tam.y / RESOLUCION_BASE.y)

	# Mundo del juego: la cámara mira al centro de la escena y hace zoom
	camara.position = RESOLUCION_BASE / 2.0
	camara.zoom = Vector2(factor, factor)
	camara.make_current()

	# Interfaz: se escala igual y se centra
	ui.scale = Vector2(factor, factor)
	ui.offset = (tam - RESOLUCION_BASE * factor) / 2.0


# ---------------- AUTOLOADS (con respaldo para F6) ----------------

func _obtener_integridad() -> float:
	var g := get_node_or_null("/root/Global")
	if g != null and g.get("integridad_nave") != null:
		return float(g.get("integridad_nave"))
	return integridad_local


func _guardar_integridad(valor: float) -> void:
	var g := get_node_or_null("/root/Global")
	if g != null and g.get("integridad_nave") != null:
		g.set("integridad_nave", valor)
	else:
		integridad_local = valor


func _nave_elegida() -> String:
	var m := get_node_or_null("/root/Mision")
	if m != null:
		var elegida = m.get("nave_elegida")
		if elegida != null and str(elegida) != "":
			return str(elegida)
	return nave_por_defecto


# ---------------- SPRITE DE LA CÁPSULA ----------------

func _cargar_sprite_capsula() -> void:
	var ruta: String = ruta_sprite_manual
	if ruta == "" or not ResourceLoader.exists(ruta):
		ruta = _buscar_archivo("res://", _nave_elegida() + "_capsula.png")
	if ruta == "":
		push_warning("No se encontró el sprite de la cápsula para '%s'; se usa el placeholder." % _nave_elegida())
		return

	var textura: Texture2D = load(ruta)
	sprite_capsula.texture = textura
	sprite_capsula.visible = true
	placeholder_capsula.visible = false
	var alto: float = float(textura.get_height())
	if alto > 0.0:
		var escala: float = alto_sprite / alto
		sprite_capsula.scale = Vector2(escala, escala)


## Busca un archivo por nombre en todas las carpetas del proyecto.
## (En un juego exportado los .png aparecen como ".png.import", por eso se revisan ambos.)
func _buscar_archivo(carpeta: String, nombre: String) -> String:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if dir.current_is_dir():
			if not archivo.begins_with("."):
				var encontrado := _buscar_archivo(carpeta.path_join(archivo), nombre)
				if encontrado != "":
					dir.list_dir_end()
					return encontrado
		elif archivo == nombre or archivo == nombre + ".import":
			dir.list_dir_end()
			return carpeta.path_join(nombre)
		archivo = dir.get_next()
	dir.list_dir_end()
	return ""


# ---------------- BUCLE PRINCIPAL ----------------

func _physics_process(delta: float) -> void:
	tiempo += delta
	_actualizar_alerta(delta)
	if fase == Fase.TERMINADO:
		return

	# Control del jugador + resistencia del aire en X
	var acel_x: float = _direccion_jugador() * ACEL_LATERAL - vel.x * ARRASTRE_LATERAL

	if fase == Fase.REENTRADA:
		_actualizar_turbulencia(delta)
		acel_x += turbulencia
		vel.y = VEL_CAIDA_REENTRADA
		_actualizar_calor(delta)
		if fase == Fase.TERMINADO:
			return  # el escudo se sobrecalentó
		if capsula.position.y >= Y_FASE_2:
			_entrar_fase_paracaidas()
	else:
		if paracaidas_abierto:
			acel_x += viento
			vel.y = move_toward(vel.y, VEL_CON_PARACAIDAS, FRENADO_PARACAIDAS * delta)
		else:
			vel.y = min(vel.y + GRAVEDAD_SIN_PARACAIDAS * delta, VEL_MAX_SIN_PARACAIDAS)
			if _quiere_paracaidas():
				_intentar_paracaidas()

	vel.x = clamp(vel.x + acel_x * delta, -VEL_LATERAL_MAX, VEL_LATERAL_MAX)
	capsula.velocity = vel
	capsula.move_and_slide()
	_limitar_a_pantalla()
	_actualizar_ui()


func _direccion_jugador() -> float:
	var dir_x := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		dir_x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		dir_x += 1.0
	return dir_x


func _quiere_paracaidas() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)


func _limitar_a_pantalla() -> void:
	if capsula.position.x < 8.0 or capsula.position.x > 632.0:
		capsula.position.x = clamp(capsula.position.x, 8.0, 632.0)
		vel.x = 0.0


# ---------------- FASE 1: TURBULENCIA Y CALOR ----------------

func _actualizar_turbulencia(delta: float) -> void:
	tiempo_turbulencia -= delta
	if tiempo_turbulencia <= 0.0:
		turbulencia = randf_range(-TURBULENCIA_MAX, TURBULENCIA_MAX)
		tiempo_turbulencia = randf_range(0.6, 1.2)


func _dentro_del_corredor() -> bool:
	return capsula.position.x >= corredor_min and capsula.position.x <= corredor_max


func _actualizar_calor(delta: float) -> void:
	if _dentro_del_corredor():
		temperatura = max(temperatura - ENFRIAMIENTO_DENTRO * delta, 0.0)
	else:
		temperatura = min(temperatura + CALOR_FUERA * delta, 100.0)

	# Tinte rojo/naranja según el calor (solo la cápsula, no el paracaídas)
	visual_capsula.modulate = Color.WHITE.lerp(COLOR_CALOR, temperatura / 100.0)

	if temperatura >= 100.0:
		_fallo("¡Escudo térmico sobrecalentado!\nTe saliste del corredor de reentrada")


# ---------------- FASE 2: PARACAÍDAS Y VIENTO ----------------

func _entrar_fase_paracaidas() -> void:
	fase = Fase.PARACAIDAS
	temperatura = 0.0
	visual_capsula.modulate = Color.WHITE
	turbulencia = 0.0


func _intentar_paracaidas() -> void:
	if capsula.position.y > Y_LIMITE_PARACAIDAS:
		demasiado_tarde = true  # ya no se puede abrir: impacto inminente
		return
	paracaidas_abierto = true
	paracaidas.visible = true
	# Aparece un viento lateral constante con dirección y fuerza aleatorias
	var signo: float = 1.0 if randf() < 0.5 else -1.0
	viento = signo * randf_range(VIENTO_MIN, VIENTO_MAX)
	_mostrar_alerta_temporal("PARACAÍDAS DESPLEGADO\n¡Contrarresta el viento!", COLOR_OK, 2.0)


# ---------------- ALERTAS CENTRALES ----------------

func _mostrar_alerta_temporal(texto: String, color: Color, duracion: float) -> void:
	alerta_temporal_texto = texto
	alerta_temporal_color = color
	alerta_temporal_restante = duracion


func _poner_alerta(texto: String, color: Color, parpadea: bool) -> void:
	alerta.text = texto
	alerta.modulate = color
	alerta.visible = (not parpadea) or (sin(tiempo * 10.0) > -0.3)


func _actualizar_alerta(delta: float) -> void:
	if alerta_temporal_restante > 0.0 and fase != Fase.TERMINADO:
		alerta_temporal_restante -= delta
		_poner_alerta(alerta_temporal_texto, alerta_temporal_color, false)
		return

	match fase:
		Fase.REENTRADA:
			if not _dentro_del_corredor():
				_poner_alerta("¡MANTÉN EL CORREDOR!", COLOR_PELIGRO, true)
			else:
				alerta.visible = false
		Fase.PARACAIDAS:
			if paracaidas_abierto:
				alerta.visible = false
			elif demasiado_tarde or capsula.position.y > Y_LIMITE_PARACAIDAS:
				_poner_alerta("¡DEMASIADO TARDE! Impacto inminente", COLOR_PELIGRO, true)
			else:
				_poner_alerta("¡PRESIONA ESPACIO PARA DESPLEGAR PARACAÍDAS!", COLOR_ALERTA, true)
		_:
			alerta.visible = false


# ---------------- INTERFAZ ----------------

func _altitud_km() -> float:
	var y_fondo: float = capsula.position.y + mitad_alto_capsula
	if y_fondo <= Y_FASE_2:
		var t1: float = clamp((y_fondo - Y_INICIO) / (Y_FASE_2 - Y_INICIO), 0.0, 1.0)
		return lerp(KM_INICIO, KM_FASE_2, t1)
	var t2: float = clamp((y_fondo - Y_FASE_2) / (Y_OCEANO - Y_FASE_2), 0.0, 1.0)
	return lerp(KM_FASE_2, 0.0, t2)


func _actualizar_ui() -> void:
	# Altitud y progreso del descenso
	var km: float = _altitud_km()
	label_altitud.text = TranslationServer.translate("Altitud: %.1f km") % km
	var progreso: float = (capsula.position.y - Y_INICIO) / (Y_OCEANO - Y_INICIO) * 100.0
	barra_altitud.value = clamp(progreso, 0.0, 100.0)

	# Fase 1: temperatura del escudo
	var en_reentrada: bool = fase == Fase.REENTRADA
	label_temperatura.visible = en_reentrada
	barra_temperatura.visible = en_reentrada
	label_temperatura.text = TranslationServer.translate("Escudo térmico: %d%%") % roundi(temperatura)
	barra_temperatura.value = temperatura
	var color_temp: Color = COLOR_OK
	if temperatura >= 70.0:
		color_temp = COLOR_PELIGRO
	elif temperatura >= 35.0:
		color_temp = COLOR_ALERTA
	label_temperatura.modulate = color_temp
	barra_temperatura.modulate = color_temp

	# Fase 2: paracaídas y viento
	label_paracaidas.visible = not en_reentrada
	label_viento.visible = not en_reentrada
	if paracaidas_abierto:
		label_paracaidas.text = "Paracaídas: DESPLEGADO"
		label_paracaidas.modulate = COLOR_OK
		var flecha: String = "<<<" if viento < 0.0 else ">>>"
		label_viento.text = TranslationServer.translate("Viento: %s %d km/h") % [flecha, roundi(absf(viento) * VIENTO_A_KMH)]
		label_viento.modulate = COLOR_ALERTA
	else:
		label_paracaidas.text = "Paracaídas: SIN DESPLEGAR"
		label_paracaidas.modulate = COLOR_PELIGRO
		label_viento.text = "Viento: --"
		label_viento.modulate = Color.WHITE

	label_integridad.text = TranslationServer.translate("Integridad: %d%%") % roundi(_obtener_integridad())


# ---------------- SEÑALES (body_entered) ----------------

## Conectada desde Oceano/ZonaSegura -> body_entered
func _on_zona_segura_body_entered(body: Node2D) -> void:
	if body != capsula or fase == Fase.TERMINADO:
		return
	if not paracaidas_abierto or vel.y > VEL_AMERIZAJE_SEGURA:
		_fallo("¡Impacto contra el agua a alta velocidad!\nEl paracaídas no se desplegó a tiempo")
	else:
		_victoria()


## Conectada desde Oceano/ZonaPeligrosa -> body_entered
func _on_zona_peligrosa_body_entered(body: Node2D) -> void:
	if body != capsula or fase == Fase.TERMINADO:
		return
	if not paracaidas_abierto:
		_fallo("¡Impacto contra el agua a alta velocidad!\nEl paracaídas no se desplegó a tiempo")
	else:
		_fallo("Amerizaje fuera de la zona de rescate\n¡Oleaje peligroso y rocas!")


# ---------------- RESULTADOS ----------------

func _detener_capsula() -> void:
	fase = Fase.TERMINADO
	vel = Vector2.ZERO
	capsula.velocity = Vector2.ZERO
	alerta.visible = false


func _victoria() -> void:
	_detener_capsula()
	_mostrar_mensaje("¡Amerizaje exitoso!\nMisión completada", COLOR_OK)
	_actualizar_ui()
	mision_completada.emit()


func _fallo(texto: String) -> void:
	_detener_capsula()
	visual_capsula.modulate = COLOR_PELIGRO
	var nueva_integridad: float = max(_obtener_integridad() - DANO_FALLO, 0.0)
	_guardar_integridad(nueva_integridad)

	if nueva_integridad <= 0.0:
		texto += TranslationServer.translate("\n\nNAVE DESTRUIDA\nPresiona R para reiniciar")
	else:
		texto += TranslationServer.translate("\n-%d de integridad\nPresiona R para reintentar") % int(DANO_FALLO)
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
		if _obtener_integridad() <= 0.0:
			# Nave destruida: para poder seguir probando se restaura la integridad.
			# En el juego completo podrías mandar a una pantalla de "Game Over" aquí.
			_guardar_integridad(100.0)
		_reiniciar_intento()
