# =============================================================================
# comic.gd - Lector del cómic de body-shan
# =============================================================================
# Este script se adjunta al nodo raíz Control de "comic.tscn".
#
# QUÉ HACE:
# - Muestra el cómic del repositorio ("Screenshot_20261109-214510.jpg") a
#   pantalla completa, respetando su proporción.
# - Permite hacer zoom con la rueda del ratón, con los botones − / + o con
#   un pellizco de dos dedos en pantalla táctil.
# - Permite arrastrar la imagen cuando está ampliada para ver cualquier zona.
# - El botón VOLVER (o Escape) regresa al menú de inicio.
# =============================================================================

extends Control


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------

## Escena a la que se vuelve al cerrar el cómic.
@export_file("*.tscn") var escena_menu: String = "res://menu_inicio.tscn"

## Duración en segundos de los fundidos de entrada y de salida.
@export var duracion_fundido: float = 0.3

## Ampliación máxima permitida.
@export var zoom_maximo: float = 6.0

## Cuánto aumenta o disminuye el zoom en cada paso.
@export var paso_zoom: float = 1.25


# -----------------------------------------------------------------------------
# NODOS DE LA ESCENA
# -----------------------------------------------------------------------------

@onready var _pagina: TextureRect = $Pagina
@onready var _boton_volver: Button = $BotonVolver
@onready var _boton_menos: Button = $Zoom/Controles/BotonMenos
@onready var _boton_mas: Button = $Zoom/Controles/BotonMas
@onready var _boton_ajustar: Button = $Zoom/Controles/BotonAjustar
@onready var _fade: ColorRect = $Fade


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS
# -----------------------------------------------------------------------------

## Ampliación actual de la página (1.0 = tamaño ajustado a la pantalla).
var _zoom: float = 1.0

## True mientras se arrastra la página con el ratón.
var _arrastrando: bool = false

## Posiciones de los dedos que están tocando la pantalla, por índice de dedo.
## Se usa para detectar el pellizco de dos dedos.
var _dedos: Dictionary = {}

## Distancia y zoom al empezar un pellizco, para calcular el aumento relativo.
var _distancia_inicial: float = 0.0
var _zoom_inicial: float = 1.0

## Evita que se pida volver al menú más de una vez.
var _saliendo: bool = false


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

## _ready() conecta los botones y lanza el fundido de entrada.
func _ready() -> void:
	_boton_volver.pressed.connect(_volver_al_menu)
	_boton_menos.pressed.connect(_alejar)
	_boton_mas.pressed.connect(_acercar)
	_boton_ajustar.pressed.connect(_ajustar)

	# Si cambia el tamaño de la ventana (o gira el móvil), se recoloca el
	# punto de escala y se vuelve a limitar el desplazamiento.
	get_viewport().size_changed.connect(_al_cambiar_tamano)

	if not DisplayServer.is_touchscreen_available():
		_boton_volver.grab_focus()

	# Fundido de entrada: de negro a transparente.
	_fade.color = Color(0, 0, 0, 1)
	_fundir_fade(0.0)
	_actualizar_pivote()


## Escape cierra el cómic y vuelve al menú.
func _unhandled_input(evento: InputEvent) -> void:
	if _saliendo:
		return

	if evento.is_action_pressed("ui_cancel"):
		_volver_al_menu()
		get_viewport().set_input_as_handled()


## _gui_input() recibe ratón y toques sobre la página. Los botones tienen su
## propio manejo y no llegan hasta aquí.
func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		if evento.pressed:
			if evento.button_index == MOUSE_BUTTON_WHEEL_UP:
				_acercar()
			elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_alejar()
			elif evento.button_index == MOUSE_BUTTON_LEFT:
				_arrastrando = true
		elif evento.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = false

	elif evento is InputEventMouseMotion and _arrastrando:
		_mover(evento.relative)

	elif evento is InputEventScreenTouch:
		if evento.pressed:
			_dedos[evento.index] = evento.position
			# Al apoyar el segundo dedo empieza un pellizco.
			if _dedos.size() == 2:
				_distancia_inicial = _distancia_entre_dedos()
				_zoom_inicial = _zoom
		else:
			_dedos.erase(evento.index)
			if _dedos.size() < 2:
				_distancia_inicial = 0.0

	elif evento is InputEventScreenDrag:
		_dedos[evento.index] = evento.position
		if _dedos.size() >= 2 and _distancia_inicial > 0.0:
			var distancia := _distancia_entre_dedos()
			if distancia > 0.0:
				_aplicar_zoom(_zoom_inicial * distancia / _distancia_inicial)
		elif _dedos.size() == 1:
			_mover(evento.relative)


# -----------------------------------------------------------------------------
# ZOOM Y DESPLAZAMIENTO
# -----------------------------------------------------------------------------

## Aumenta un paso el zoom.
func _acercar() -> void:
	_aplicar_zoom(_zoom * paso_zoom)


## Disminuye un paso el zoom.
func _alejar() -> void:
	_aplicar_zoom(_zoom / paso_zoom)


## Vuelve al tamaño ajustado a la pantalla y centra la página.
func _ajustar() -> void:
	_zoom = 1.0
	_pagina.scale = Vector2.ONE
	_pagina.position = Vector2.ZERO
	_actualizar_pivote()


## Aplica una ampliación concreta, limitada entre 1.0 y zoom_maximo.
func _aplicar_zoom(nuevo_zoom: float) -> void:
	_zoom = clampf(nuevo_zoom, 1.0, zoom_maximo)
	_actualizar_pivote()
	_pagina.scale = Vector2(_zoom, _zoom)

	# Al volver al tamaño normal se centra de nuevo; si sigue ampliada, se
	# limita la posición para no perder la página fuera de la pantalla.
	if is_equal_approx(_zoom, 1.0):
		_pagina.position = Vector2.ZERO
	else:
		_limitar_pan()


## Desplaza la página con el movimiento del ratón o del dedo.
func _mover(desplazamiento: Vector2) -> void:
	_pagina.position += desplazamiento
	_limitar_pan()


## Impide que el centro de la página salga de la pantalla.
func _limitar_pan() -> void:
	var centro := _pagina.position + _pagina.size * 0.5
	centro.x = clampf(centro.x, 0.0, size.x)
	centro.y = clampf(centro.y, 0.0, size.y)
	_pagina.position = centro - _pagina.size * 0.5


## El punto de escala debe ser el centro de la página para que el zoom
## crezca desde el centro y no desde la esquina superior izquierda.
func _actualizar_pivote() -> void:
	_pagina.pivot_offset = _pagina.size * 0.5


## Devuelve la distancia entre los dos primeros dedos apoyados.
func _distancia_entre_dedos() -> float:
	var puntos: Array = _dedos.values()
	if puntos.size() < 2:
		return 0.0
	var primero: Vector2 = puntos[0]
	var segundo: Vector2 = puntos[1]
	return primero.distance_to(segundo)


## Al cambiar el tamaño de la ventana se recalcula el pivote y se recoloca.
func _al_cambiar_tamano() -> void:
	_actualizar_pivote()
	_limitar_pan()


# -----------------------------------------------------------------------------
# SALIDA
# -----------------------------------------------------------------------------

## Vuelve al menú de inicio con un fundido a negro.
func _volver_al_menu() -> void:
	if _saliendo:
		return

	_saliendo = true
	_fundir_fade(1.0, _cargar_menu)


## Carga el menú una vez terminado el fundido.
func _cargar_menu() -> void:
	var error := get_tree().change_scene_to_file(escena_menu)

	if error != OK:
		push_error("No se pudo volver al menú: %s" % escena_menu)
		_saliendo = false
		_fundir_fade(0.0)


# -----------------------------------------------------------------------------
# FUNCIONES AUXILIARES
# -----------------------------------------------------------------------------

## Anima la transparencia del ColorRect "Fade" hasta el valor indicado.
func _fundir_fade(alpha_final: float, al_terminar: Callable = Callable()) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade, "color:a", alpha_final, duracion_fundido)

	if al_terminar.is_valid():
		tween.finished.connect(al_terminar)
