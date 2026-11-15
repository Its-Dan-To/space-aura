extends Control
## Menú principal con fondo espacial animado (Cozy Space Backdrops).
## Todo se arma desde código, así que la escena solo necesita este script.

# ---------- Cosas que puedes cambiar fácilmente ----------
const TITULO := "EL VIAJE DE ALBERTSAHUR"
const ESCENA_JUEGO := "res://scenes/intro.tscn"
const RUTA := "res://assets/espacio/"
# Si pones una fuente pixel en esta ruta, el menú la usa sola:
const RUTA_FUENTE := "res://fuentes/pixel.ttf"
const TAMANO_TITULO := 32
const TAMANO_BOTONES := 32
# Ancho mínimo de los botones (todos quedan igual de anchos que el más ancho)
const ANCHO_BOTONES := 240
# Pon false para quitar los planetas de las esquinas
const MOSTRAR_PLANETAS := false

# Colores sacados de la nebulosa violeta
const COLOR_FONDO_BOTON := Color("1b1433dd")
const COLOR_BORDE := Color("8a6bbf")
const COLOR_HOVER := Color("3a2a66")
const COLOR_BORDE_HOVER := Color("f2c6e0")
const COLOR_TEXTO := Color("f4eefc")
# ---------------------------------------------------------

var capas := []        # cada una: {nodo, velocidad, tile, desplazamiento}
var asteroides := []   # cada uno: {nodo, velocidad}
var planetas := []     # Sprite2D con 24 cuadros de animación
var reloj_animacion := 0.0
var titulo: Label
var tiempo := 0.0


func _ready() -> void:
	# Pixeles nítidos para todo lo que esté dentro del menú
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crear_fondo()
	if MOSTRAR_PLANETAS:
		_crear_planetas()
	_crear_asteroides()
	_crear_menu()
	# Aparece suavemente
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	tiempo += delta
	var pantalla := get_viewport_rect().size

	# Fondo con parallax: cada capa se mueve a distinta velocidad
	for c in capas:
		c.desplazamiento += c.velocidad * delta
		c.nodo.position.x = -round(fposmod(c.desplazamiento, c.tile))

	# Planetas girando (10 cuadros por segundo)
	reloj_animacion += delta
	if reloj_animacion >= 0.1:
		reloj_animacion = 0.0
		for p in planetas:
			p.frame = (p.frame + 1) % p.hframes

	# Asteroides que cruzan la pantalla y vuelven a aparecer
	for a in asteroides:
		a.nodo.position.x -= a.velocidad * delta
		if a.nodo.position.x < -16:
			a.nodo.position.x = pantalla.x + 16
			a.nodo.position.y = randf_range(10, pantalla.y - 10)

	# El título flota un poquito
	if titulo:
		titulo.position.y = round(sin(tiempo * 2.0) * 2.0)


# ---------------- Fondo ----------------

func _crear_capa(archivo: String, velocidad: float, tile: int) -> void:
	var capa := TextureRect.new()
	capa.texture = load(RUTA + "fondos/" + archivo)
	capa.stretch_mode = TextureRect.STRETCH_TILE
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(capa)
	# Un poco más grande que la pantalla para poder moverla sin que se vea el borde
	capa.size = get_viewport_rect().size + Vector2(tile, tile)
	capas.append({"nodo": capa, "velocidad": velocidad, "tile": tile, "desplazamiento": 0.0})


func _crear_fondo() -> void:
	# Cambia "violet" por "teal" o "rose" para otro color de nebulosa
	_crear_capa("nebula-violet-tile.png", 2.0, 256)
	_crear_capa("stars-mid-tile.png", 6.0, 128)
	_crear_capa("stars-near-tile.png", 12.0, 128)


# ---------------- Planetas y asteroides ----------------

func _crear_planeta(archivo: String, posicion: Vector2, cuadros: int = 24) -> void:
	var p := Sprite2D.new()
	p.texture = load(RUTA + "planetas/" + archivo)
	p.hframes = cuadros
	p.position = posicion
	add_child(p)
	planetas.append(p)


func _crear_planetas() -> void:
	var pantalla := get_viewport_rect().size
	_crear_planeta("planet-gasblue-spin-24f.png", Vector2(pantalla.x - 52, pantalla.y - 44))
	_crear_planeta("planet-moon-spin-24f.png", Vector2(26, pantalla.y - 22))


func _crear_asteroides() -> void:
	var pantalla := get_viewport_rect().size
	for i in range(4):
		var a := Sprite2D.new()
		a.texture = load(RUTA + "asteroides/asteroid-%d.png" % randi_range(1, 8))
		a.position = Vector2(randf_range(0, pantalla.x), randf_range(10, pantalla.y - 10))
		add_child(a)
		asteroides.append({"nodo": a, "velocidad": randf_range(4.0, 10.0)})


# ---------------- Menú ----------------

func _caja_boton(fondo: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(1)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


func _crear_tema() -> Theme:
	var tema := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		tema.default_font = load(RUTA_FUENTE)
	tema.default_font_size = TAMANO_BOTONES
	tema.set_stylebox("normal", "Button", _caja_boton(COLOR_FONDO_BOTON, COLOR_BORDE))
	tema.set_stylebox("hover", "Button", _caja_boton(COLOR_HOVER, COLOR_BORDE_HOVER))
	tema.set_stylebox("focus", "Button", _caja_boton(COLOR_HOVER, COLOR_BORDE_HOVER))
	tema.set_stylebox("pressed", "Button", _caja_boton(COLOR_BORDE, COLOR_BORDE_HOVER))
	for estado in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		tema.set_color(estado, "Button", COLOR_TEXTO)
	return tema


func _crear_boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ANCHO_BOTONES, 0)
	b.pressed.connect(accion)
	# Con el mouse encima también se marca, igual que con el teclado
	b.mouse_entered.connect(b.grab_focus)
	return b


func _crear_menu() -> void:
	var caja := VBoxContainer.new()
	caja.theme = _crear_tema()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 5)
	add_child(caja)
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# El título va dentro de un contenedor para que pueda flotar sin mover los botones
	var espacio_titulo := Control.new()
	espacio_titulo.custom_minimum_size = Vector2(0, TAMANO_TITULO + 14)
	caja.add_child(espacio_titulo)

	titulo = Label.new()
	titulo.text = TITULO
	titulo.add_theme_font_size_override("font_size", TAMANO_TITULO)
	titulo.add_theme_color_override("font_color", COLOR_TEXTO)
	titulo.add_theme_color_override("font_outline_color", Color("2a1a4a"))
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	espacio_titulo.add_child(titulo)
	titulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	# Los botones van en su propia columna centrada: así todos miden lo mismo
	var botones := VBoxContainer.new()
	botones.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	botones.add_theme_constant_override("separation", 5)
	caja.add_child(botones)

	var jugar := _crear_boton("Jugar", _on_jugar)
	botones.add_child(jugar)
	botones.add_child(_crear_boton("Opciones", _on_opciones))
	botones.add_child(_crear_boton("Salir", _on_salir))

	# Así se puede usar el menú con teclado o control desde el inicio
	jugar.grab_focus()


func _on_jugar() -> void:
	if ResourceLoader.exists(ESCENA_JUEGO):
		get_tree().change_scene_to_file(ESCENA_JUEGO)
	else:
		push_warning("Todavía no existe " + ESCENA_JUEGO + ". Crea tu primer nivel ahí.")


func _on_opciones() -> void:
	print("Aquí irá el menú de opciones")


func _on_salir() -> void:
	get_tree().quit()
