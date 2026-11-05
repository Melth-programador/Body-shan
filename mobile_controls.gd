# =============================================================================
# mobile_controls.gd - Botones táctiles de salto y carrera para body-shan
# =============================================================================
# Este script se adjunta al nodo Control "MobileControls" de "mapa.tscn".
#
# QUÉ HACE:
# - Detecta si el juego se está ejecutando en un dispositivo táctil (móvil).
# - Muestra u oculta los controles táctiles según esa detección.
# - Conecta los botones "SALTO" y "CORRER" con el jugador.
#
# CÓMO SE COMUNICA CON EL JUGADOR:
# El jugador (CharacterBody3D) pertenece al grupo "player". En lugar de
# acceder directamente a su script, se usa call_group(), que llama a un método
# por nombre en todos los nodos del grupo. Así los controles no necesitan
# conocer la ruta exacta del jugador.
#
# CONTROLES:
#   - Botón SALTO  : pide un salto por cada pulsación (request_jump()).
#   - Botón CORRER : mantiene la carrera mientras se mantiene pulsado
#                    (set_touch_sprint(true/false)).
# =============================================================================

# Hereda de Control: nodo de interfaz que puede contener botones y recibir
# eventos de entrada. Con "visible = false" desaparece junto con sus hijos.
extends Control


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS (no visibles en el Inspector)
# -----------------------------------------------------------------------------

## True si la sesión actual usa pantalla táctil. En escritorio vale false y
## los controles permanecen ocultos.
var _is_touch_device: bool = false


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

## _ready() se ejecuta una sola vez, cuando el nodo ya está en el árbol de
## escena. Aquí se detecta la plataforma, se ajusta la visibilidad y se
## conectan los botones con sus funciones.
func _ready() -> void:
	# OS.has_feature("mobile") es true en Android e iOS.
	# DisplayServer.is_touchscreen_available() cubre también equipos de
	# escritorio con pantalla táctil y las pruebas en el editor.
	_is_touch_device = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

	# El nodo completo (y sus botones) solo se muestra en dispositivos
	# táctiles. Al ocultar el Control también se ocultan sus hijos.
	visible = _is_touch_device

	# El joystick es un nodo hermano: se oculta en escritorio para no estorbar
	# con el ratón y se deja visible en móvil.
	var joystick := get_parent().get_node_or_null("VirtualJoystick")
	if joystick is CanvasItem:
		joystick.visible = _is_touch_device

	# "button_down" se emite al apoyar el dedo (o pulsar el botón) y
	# "button_up" al levantarlo. El salto se pide al bajar para que responda
	# de inmediato; la carrera se activa al bajar y se desactiva al subir.
	$JumpButton.button_down.connect(_on_jump_button_down)
	$SprintButton.button_down.connect(_on_sprint_button_down)
	$SprintButton.button_up.connect(_on_sprint_button_up)


## _exit_tree() se ejecuta al salir de la escena. Si el botón de correr seguía
## pulsado (por ejemplo, al cambiar de escena), se avisa al jugador para que
## no se quede corriendo indefinidamente.
func _exit_tree() -> void:
	if _is_touch_device:
		get_tree().call_group("player", "set_touch_sprint", false)


# -----------------------------------------------------------------------------
# CALLBACKS DE LOS BOTONES
# -----------------------------------------------------------------------------

## Pide un salto al jugador. request_jump() solo marca la petición; el salto
## real se aplica en el siguiente paso de física de personaje.gd.
func _on_jump_button_down() -> void:
	get_tree().call_group("player", "request_jump")


## Activa la carrera mientras el botón permanezca pulsado.
func _on_sprint_button_down() -> void:
	get_tree().call_group("player", "set_touch_sprint", true)


## Desactiva la carrera al soltar el botón.
func _on_sprint_button_up() -> void:
	get_tree().call_group("player", "set_touch_sprint", false)
