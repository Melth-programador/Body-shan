# =============================================================================
# cinematica.gd - Cinemática de introducción para body-shan
# =============================================================================
# Este script se adjunta al nodo raíz Control de "cinematica.tscn".
#
# QUÉ HACE:
# - Reproduce el video "cinematica.ogv" a pantalla completa, respetando su
#   proporción 16:9 (el AspectRatioContainer deja barras negras si hace falta).
# - Al terminar el video vuelve automáticamente al menú de inicio.
# - El botón SALTAR (o Escape / Enter / Espacio) corta el video y vuelve.
#
# NOTA SOBRE EL FORMATO:
# Godot solo reproduce video Ogg Theora (.ogv) de forma nativa. Por eso el
# WebM original del repositorio se convirtió a "cinematica.ogv" conservando
# la imagen y el audio.
# =============================================================================

extends Control


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------

## Escena a la que se vuelve al terminar o saltar la cinemática.
@export_file("*.tscn") var escena_menu: String = "res://menu_inicio.tscn"

## Duración en segundos de los fundidos de entrada y de salida.
@export var duracion_fundido: float = 0.3


# -----------------------------------------------------------------------------
# NODOS DE LA ESCENA
# -----------------------------------------------------------------------------

@onready var _video: VideoStreamPlayer = $Aspecto/Video
@onready var _boton_saltar: Button = $BotonSaltar
@onready var _fade: ColorRect = $Fade


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS
# -----------------------------------------------------------------------------

## Evita que se pida volver al menú más de una vez (por ejemplo, si el video
## termina justo cuando el jugador pulsa SALTAR).
var _saliendo: bool = false


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

## _ready() arranca el video y prepara los botones y el fundido de entrada.
func _ready() -> void:
	_boton_saltar.pressed.connect(_volver_al_menu)
	_video.finished.connect(_volver_al_menu)

	# En escritorio se enfoca SALTAR para poder saltar con Enter/Espacio.
	if not DisplayServer.is_touchscreen_available():
		_boton_saltar.grab_focus()

	# Fundido de entrada: de negro a transparente.
	_fade.color = Color(0, 0, 0, 1)
	_fundir_fade(0.0)

	# Reproducción del video. Si el recurso no se pudo cargar se avisa por
	# consola y se deja la pantalla negra hasta que el jugador pulse SALTAR.
	if _video.stream == null:
		push_warning("No se pudo cargar el video de la cinemática.")
	else:
		_video.play()


## Un toque o clic en cualquier parte de la pantalla también salta el video.
func _gui_input(evento: InputEvent) -> void:
	if _saliendo:
		return

	if evento is InputEventMouseButton and evento.pressed:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			_volver_al_menu()
	elif evento is InputEventScreenTouch and evento.pressed:
		_volver_al_menu()


## Permite salir de la cinemática con Escape, Enter o Espacio.
func _unhandled_input(evento: InputEvent) -> void:
	if _saliendo:
		return

	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("ui_accept"):
		_volver_al_menu()
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------------
# SALIDA
# -----------------------------------------------------------------------------

## Para el video y vuelve al menú con un fundido a negro.
func _volver_al_menu() -> void:
	if _saliendo:
		return

	_saliendo = true
	_video.stop()
	_fundir_fade(1.0, _cargar_menu)


## Carga el menú de inicio una vez terminado el fundido.
func _cargar_menu() -> void:
	var error := get_tree().change_scene_to_file(escena_menu)

	if error != OK:
		push_error("No se pudo volver al menú: %s" % escena_menu)
		# Si falla, se muestra otra vez la cinemática para no dejar la
		# pantalla en negro.
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
