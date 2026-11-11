# =============================================================================
# menu_inicio.gd - Menú de inicio (pantalla de título) para body-shan
# =============================================================================
# Este script se adjunta al nodo raíz Control de "menu_inicio.tscn".
#
# QUÉ HACE:
# - Muestra el título del juego y tres botones:
#     INICIAR JUEGO -> carga la escena del mapa ("mapa.tscn").
#     CINEMÁTICA    -> reproduce el video de introducción.
#     CÓMIC         -> abre el cómic del juego.
# - Todos los cambios de escena usan un fundido a negro.
#
# El fundido se dibuja con el ColorRect "Fade", que cubre toda la pantalla.
# Al empezar la escena está negro y se aclara; al pulsar un botón se oscurece.
# =============================================================================

# Hereda de Control: nodo de interfaz que ocupa toda la pantalla.
extends Control


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------

## Escena que se carga al pulsar INICIAR JUEGO.
@export_file("*.tscn") var escena_juego: String = "res://mapa.tscn"

## Escena que se carga al pulsar CINEMÁTICA.
@export_file("*.tscn") var escena_cinematica: String = "res://cinematica.tscn"

## Escena que se carga al pulsar CÓMIC.
@export_file("*.tscn") var escena_comic: String = "res://comic.tscn"

## Duración en segundos de los fundidos de entrada y de salida.
@export var duracion_fundido: float = 0.4


# -----------------------------------------------------------------------------
# NODOS DE LA ESCENA
# -----------------------------------------------------------------------------

@onready var _fade: ColorRect = $Fade
@onready var _boton_jugar: Button = $Centro/Contenido/BotonJugar
@onready var _boton_cinematica: Button = $Centro/Contenido/BotonCinematica
@onready var _boton_comic: Button = $Centro/Contenido/BotonComic


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS
# -----------------------------------------------------------------------------

## Evita que se pida cambiar de escena dos veces si se pulsa dos botones.
var _cambiando: bool = false


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

## _ready() se ejecuta una sola vez, cuando la escena ya está en el árbol.
func _ready() -> void:
	# Cada botón llama a _ir_a() con la escena que debe abrir. "bind" añade
	# ese argumento a la función que se ejecuta al pulsar el botón.
	_boton_jugar.pressed.connect(_ir_a.bind(escena_juego))
	_boton_cinematica.pressed.connect(_ir_a.bind(escena_cinematica))
	_boton_comic.pressed.connect(_ir_a.bind(escena_comic))

	# En escritorio se selecciona INICIAR JUEGO para poder empezar con Enter
	# o Espacio. En pantallas táctiles no se pide foco para no dibujar el
	# recuadro de selección.
	if not DisplayServer.is_touchscreen_available():
		_boton_jugar.grab_focus()

	# Fundido de entrada: la pantalla empieza negra y se aclara.
	_fade.color = Color(0, 0, 0, 1)
	_fundir_fade(0.0)


# -----------------------------------------------------------------------------
# CAMBIO DE ESCENA
# -----------------------------------------------------------------------------

## Abre la escena indicada con un fundido a negro. Se conecta a los botones.
func _ir_a(escena: String) -> void:
	if _cambiando:
		return

	_cambiando = true
	_bloquear_botones(true)
	_fundir_fade(1.0, _cambiar_escena.bind(escena))


## Carga la escena una vez terminado el fundido a negro.
func _cambiar_escena(escena: String) -> void:
	var error := get_tree().change_scene_to_file(escena)

	# Si la escena no existe o está dañada, se informa y se vuelve a mostrar
	# el menú en lugar de dejar la pantalla en negro.
	if error != OK:
		push_error("No se pudo cargar la escena: %s" % escena)
		_cambiando = false
		_bloquear_botones(false)
		_fundir_fade(0.0)


# -----------------------------------------------------------------------------
# FUNCIONES AUXILIARES
# -----------------------------------------------------------------------------

## Anima la transparencia del ColorRect "Fade" hasta el valor indicado.
## "al_terminar" es una función opcional que se llama al acabar el fundido.
func _fundir_fade(alpha_final: float, al_terminar: Callable = Callable()) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade, "color:a", alpha_final, duracion_fundido)

	if al_terminar.is_valid():
		tween.finished.connect(al_terminar)


## Activa o desactiva los botones mientras se está cambiando de escena.
func _bloquear_botones(bloqueados: bool = true) -> void:
	for boton in [_boton_jugar, _boton_cinematica, _boton_comic]:
		boton.disabled = bloqueados
