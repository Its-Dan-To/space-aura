extends CanvasLayer
## =====================================================================
##  BITÁCORA ESPACIAL — Interfaz (botón HUD + ventana modal)
## ---------------------------------------------------------------------
##  Va en el nodo raíz (CanvasLayer) de bitacora_ui.tscn.
##  Requiere el autoload "Bitacora" (bitacora.gd).
##  Todos los nodos se buscan por "Nombre único" (%), así que puedes
##  reorganizar el árbol sin romper el script.
## =====================================================================

## Si es true, el juego se pausa (get_tree().paused) mientras el diario está abierto.
## Se emite al cerrar la ventana (el menú de pausa lo usa para volver a mostrarse).
signal cerrado

## Si es false, se oculta el botón "Diario" propio (cuando lo abre el menú de pausa).
@export var mostrar_boton_hud: bool = true
@export var pausar_juego: bool = true
## Acción opcional del InputMap para abrir/cerrar el diario con teclado (ej. tecla J).
## Si no existe en el InputMap, simplemente se ignora.
@export var accion_abrir: StringName = &"abrir_diario"
## Imagen que se muestra si la ruta_imagen de una entrada no existe (opcional).
@export var textura_respaldo: Texture2D
## Texto para entradas no descubiertas.
@export var texto_bloqueada: String = "???  (bloqueada)"

@onready var boton_diario: Button = %BotonDiario
@onready var ventana: Control = %Ventana
@onready var boton_cerrar: Button = %BotonCerrar
@onready var titulo_diario: Label = %TituloDiario
@onready var scroll_lista: ScrollContainer = %ScrollLista
@onready var lista_entradas: VBoxContainer = %ListaEntradas
@onready var imagen: TextureRect = %Imagen
@onready var titulo_entrada: Label = %TituloEntrada
@onready var subtitulo: RichTextLabel = %Subtitulo
@onready var texto: RichTextLabel = %Texto
@onready var boton_anterior: Button = %BotonAnterior
@onready var boton_siguiente: Button = %BotonSiguiente
@onready var contador: Label = %Contador

var _id_seleccionado: String = ""
var _botones: Dictionary = {}          # id -> Button de la lista
var _grupo_botones := ButtonGroup.new()
var _pausa_previa: bool = false        # Para no "despausar" un juego que ya estaba en pausa
var _texto_boton_hud: String = ""

# Animación por hoja de cuadros (para imágenes animadas como la de Solar Flares)
var _anim_atlas: AtlasTexture = null
var _anim_columnas: int = 1
var _anim_frames: int = 1
var _anim_fps: float = 12.0
var _anim_tamano := Vector2.ZERO
var _anim_frame: int = 0
var _anim_tiempo: float = 0.0


func _ready() -> void:
	# Este nodo (y sus hijos, que heredan) sigue funcionando con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ventana.hide()
	_texto_boton_hud = boton_diario.text
	boton_diario.visible = mostrar_boton_hud

	# Ajustes clave también por código, por si se olvidan en el Inspector.
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # No deforma las fotos
	texto.bbcode_enabled = true
	texto.scroll_active = true
	texto.fit_content = false
	# Estos textos ya vienen en el idioma correcto desde el JSON,
	# así que Godot no debe volver a traducirlos.
	texto.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	titulo_entrada.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	subtitulo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	subtitulo.bbcode_enabled = true
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	boton_diario.focus_mode = Control.FOCUS_NONE  # Evita que Espacio/Enter lo active al jugar

	boton_diario.pressed.connect(alternar)
	boton_cerrar.pressed.connect(cerrar)
	boton_anterior.pressed.connect(_navegar.bind(-1))
	boton_siguiente.pressed.connect(_navegar.bind(1))
	Bitacora.entrada_desbloqueada.connect(_on_entrada_desbloqueada)
	Bitacora.datos_cargados.connect(_refrescar)

	_construir_lista()


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(accion_abrir) and event.is_action_pressed(accion_abrir):
		alternar()
		get_viewport().set_input_as_handled()
	elif ventana.visible and event.is_action_pressed("ui_cancel"):  # Esc cierra el diario
		cerrar()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------
#  ABRIR / CERRAR
# ---------------------------------------------------------------------

func alternar() -> void:
	if ventana.visible:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	if ventana.visible:
		return
	if pausar_juego:
		_pausa_previa = get_tree().paused
		get_tree().paused = true
	_construir_lista()
	ventana.show()
	_marcar_novedad(false)

	# Selecciona la última entrada leída o, si no hay, la primera desbloqueada.
	var ids := Bitacora.obtener_ids_desbloqueados()
	if ids.is_empty():
		_mostrar_vacio()
	elif _id_seleccionado in ids:
		mostrar_entrada(_id_seleccionado)
	else:
		mostrar_entrada(ids[0])

	# Foco para poder navegar con teclado / mando.
	if _botones.has(_id_seleccionado):
		_botones[_id_seleccionado].grab_focus()
	else:
		boton_cerrar.grab_focus()


func esta_abierta() -> bool:
	return ventana.visible


func cerrar() -> void:
	if not ventana.visible:
		return
	ventana.hide()
	if pausar_juego:
		get_tree().paused = _pausa_previa
	cerrado.emit()


# ---------------------------------------------------------------------
#  LISTA DE ENTRADAS (columna izquierda)
# ---------------------------------------------------------------------

## Se llama al cargar los datos y al cambiar de idioma.
func _refrescar() -> void:
	_construir_lista()
	if ventana.visible and _id_seleccionado != "":
		mostrar_entrada(_id_seleccionado)


func _construir_lista() -> void:
	# Limpiamos los botones anteriores (remove_child para que desaparezcan ya).
	for hijo in lista_entradas.get_children():
		lista_entradas.remove_child(hijo)
		hijo.queue_free()
	_botones.clear()
	_grupo_botones = ButtonGroup.new()

	for entrada in Bitacora.obtener_entradas():
		var id: String = entrada["id"]
		var boton := Button.new()
		boton.toggle_mode = true
		boton.button_group = _grupo_botones
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.custom_minimum_size = Vector2(0, 42)

		if entrada["desbloqueada"]:
			boton.text = entrada["titulo"]
			boton.tooltip_text = entrada["subtitulo_o_fecha"]
			boton.pressed.connect(mostrar_entrada.bind(id))
		else:
			boton.text = TranslationServer.translate(texto_bloqueada)
			boton.disabled = true
			boton.focus_mode = Control.FOCUS_NONE

		lista_entradas.add_child(boton)
		_botones[id] = boton

	titulo_diario.text = TranslationServer.translate("Bitácora Espacial  —  %d / %d descubiertas") % [
		Bitacora.contar_desbloqueadas(), Bitacora.contar_total()]

	# Re-marca la entrada que estaba seleccionada (si sigue existiendo).
	if _botones.has(_id_seleccionado):
		_botones[_id_seleccionado].set_pressed_no_signal(true)


# ---------------------------------------------------------------------
#  VISTA DE LECTURA (columna derecha)
# ---------------------------------------------------------------------

func mostrar_entrada(id: String) -> void:
	var entrada := Bitacora.obtener_entrada(id)
	if entrada.is_empty() or not entrada["desbloqueada"]:
		return
	_id_seleccionado = id

	titulo_entrada.text = entrada["titulo"]
	subtitulo.text = TranslationServer.translate("[i]%s[/i]") % entrada["subtitulo_o_fecha"]
	texto.text = entrada["texto"]  # Con bbcode_enabled, el BBCode se interpreta
	texto.scroll_to_line(0)
	_poner_imagen(_cargar_textura(entrada["ruta_imagen"]), entrada.get("animacion", {}))

	if _botones.has(id):
		var boton: Button = _botones[id]
		boton.set_pressed_no_signal(true)
		scroll_lista.ensure_control_visible(boton)

	_actualizar_navegacion()


func _mostrar_vacio() -> void:
	_id_seleccionado = ""
	titulo_entrada.text = TranslationServer.translate("Sin entradas todavía")
	subtitulo.text = ""
	texto.text = TranslationServer.translate("[i]Completa misiones para descubrir nuevas entradas de la bitácora.[/i]")
	_poner_imagen(textura_respaldo, {})
	_actualizar_navegacion()


## Muestra una imagen fija o, si "animacion" trae datos, la anima recorriendo
## los cuadros de una hoja (spritesheet). Godot no reproduce GIF directamente.
func _poner_imagen(textura: Texture2D, animacion: Dictionary) -> void:
	_anim_atlas = null
	if textura == null or animacion.is_empty():
		imagen.texture = textura
		return
	_anim_columnas = maxi(1, int(animacion.get("columnas", 1)))
	var filas := maxi(1, int(animacion.get("filas", 1)))
	_anim_frames = clampi(int(animacion.get("frames", _anim_columnas * filas)), 1, _anim_columnas * filas)
	_anim_fps = maxf(1.0, float(animacion.get("fps", 12.0)))
	_anim_tamano = Vector2(textura.get_width() / float(_anim_columnas), textura.get_height() / float(filas))
	_anim_atlas = AtlasTexture.new()
	_anim_atlas.atlas = textura
	_anim_atlas.filter_clip = true  # evita que se "cuele" el borde del cuadro vecino
	_anim_frame = 0
	_anim_tiempo = 0.0
	_mostrar_cuadro()
	imagen.texture = _anim_atlas


func _process(delta: float) -> void:
	if _anim_atlas == null or not ventana.visible:
		return
	_anim_tiempo += delta
	var duracion := 1.0 / _anim_fps
	if _anim_tiempo >= duracion:
		var avance := floori(_anim_tiempo / duracion)
		_anim_tiempo -= avance * duracion
		_anim_frame = (_anim_frame + avance) % _anim_frames
		_mostrar_cuadro()


func _mostrar_cuadro() -> void:
	var columna := _anim_frame % _anim_columnas
	var fila := floori(float(_anim_frame) / _anim_columnas)
	_anim_atlas.region = Rect2(Vector2(columna, fila) * _anim_tamano, _anim_tamano)


func _cargar_textura(ruta: String) -> Texture2D:
	# ResourceLoader.exists funciona también en el juego exportado (texturas importadas).
	if ruta != "" and ResourceLoader.exists(ruta):
		var recurso = load(ruta)
		if recurso is Texture2D:
			return recurso
	if ruta != "":
		push_warning("Bitacora UI: no se encontró la imagen '%s'." % ruta)
	return textura_respaldo


# ---------------------------------------------------------------------
#  ANTERIOR / SIGUIENTE (solo recorre entradas desbloqueadas)
# ---------------------------------------------------------------------

func _navegar(direccion: int) -> void:
	var ids := Bitacora.obtener_ids_desbloqueados()
	var indice := ids.find(_id_seleccionado)
	if indice == -1:
		return
	var nuevo := clampi(indice + direccion, 0, ids.size() - 1)
	if nuevo != indice:
		mostrar_entrada(ids[nuevo])


func _actualizar_navegacion() -> void:
	var ids := Bitacora.obtener_ids_desbloqueados()
	var indice := ids.find(_id_seleccionado)
	boton_anterior.disabled = indice <= 0
	boton_siguiente.disabled = indice == -1 or indice >= ids.size() - 1
	contador.text = "" if indice == -1 else TranslationServer.translate("%d / %d") % [indice + 1, ids.size()]


# ---------------------------------------------------------------------
#  NOTIFICACIÓN DE NUEVAS ENTRADAS
# ---------------------------------------------------------------------

func _on_entrada_desbloqueada(id: String) -> void:
	_construir_lista()
	if ventana.visible:
		mostrar_entrada(id)
	else:
		_id_seleccionado = id   # Al abrir, se muestra directamente la nueva
		_marcar_novedad(true)


func _marcar_novedad(hay_novedad: bool) -> void:
	boton_diario.text = (_texto_boton_hud + " (!)") if hay_novedad else _texto_boton_hud
	boton_diario.modulate = Color(1.0, 0.85, 0.3) if hay_novedad else Color.WHITE
