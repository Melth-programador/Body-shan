# =============================================================================
# mobile_controls.gd - Botones táctiles de salto, carrera, agacharse y wall jump
# =============================================================================
# Este script se adjunta al nodo Control "MobileControls" de "escenario.tscn".
#
# QUÉ HACE:
# - Detecta si el juego se está ejecutando en un dispositivo táctil (móvil).
# - Muestra u oculta los controles táctiles según esa detección, pudiendo
#   forzarlos visibles en escritorio con "force_show_on_desktop".
# - Conecta los botones "SALTO", "CORRER", "AGACHARSE" y "WALL JUMP".
#
# CÓMO SE COMUNICA CON EL JUGADOR:
# El jugador (CharacterBody3D) pertenece al grupo "player". En lugar de
# acceder directamente a su script, se usa call_group(), que llama a un método
# por nombre en todos los nodos del grupo. Así los controles no necesitan
# conocer la ruta exacta del jugador.
#
# CONTROLES:
#   - Botón SALTO     : pide un salto por cada pulsación (request_jump()).
#   - Botón CORRER    : mantiene la carrera mientras se mantiene pulsado
#                       (set_touch_sprint(true/false)).
#   - Botón AGACHARSE : mantiene el agachado mientras se mantiene pulsado
#                       (set_touch_crouch(true/false)).
#   - Botón WALL JUMP : pide un salto de pared por cada pulsación
#                       (request_wall_jump()).
# =============================================================================

# Hereda de Control: nodo de interfaz que puede contener botones y recibir
# eventos de entrada. Con "visible = false" desaparece junto con sus hijos.
extends Control


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------

## Si es true, los controles táctiles (y el joystick) se muestran también en
## escritorio. Sirve para probar la interfaz móvil desde la vista de PC.
@export var force_show_on_desktop: bool = true


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS (no visibles en el Inspector)
# -----------------------------------------------------------------------------

## True si la sesión actual usa pantalla táctil. En escritorio vale false y
## los controles permanecen ocultos, salvo que force_show_on_desktop sea true.
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

	# Los controles se muestran en dispositivos táctiles o si se fuerza desde
	# el Inspector para probarlos en la vista de PC.
	var controls_visible := _is_touch_device or force_show_on_desktop

	# El nodo completo (y sus botones) se muestra u oculta según lo anterior.
	# Al ocultar el Control también se ocultan sus hijos.
	visible = controls_visible

	# El joystick es un nodo hermano: se oculta en escritorio para no estorbar
	# con el ratón y se deja visible en móvil (o si se fuerza en PC).
	var joystick := get_parent().get_node_or_null("VirtualJoystick")
	if joystick is CanvasItem:
		joystick.visible = controls_visible

	# "button_down" se emite al apoyar el dedo (o pulsar el botón) y
	# "button_up" al levantarlo. El salto se pide al bajar para que responda
	# de inmediato; la carrera se activa al bajar y se desactiva al subir.
	$JumpButton.button_down.connect(_on_jump_button_down)
	$SprintButton.button_down.connect(_on_sprint_button_down)
	$SprintButton.button_up.connect(_on_sprint_button_up)

	# Los botones nuevos se conectan solo si existen en la escena. Así este
	# script sigue funcionando en escenas antiguas que no los tengan.
	var crouch_button := get_node_or_null("CrouchButton") as Button
	if crouch_button:
		crouch_button.button_down.connect(_on_crouch_button_down)
		crouch_button.button_up.connect(_on_crouch_button_up)

	var wall_jump_button := get_node_or_null("WallJumpButton") as Button
	if wall_jump_button:
		wall_jump_button.button_down.connect(_on_wall_jump_button_down)


## _exit_tree() se ejecuta al salir de la escena. Si el botón de correr seguía
## pulsado (por ejemplo, al cambiar de escena), se avisa al jugador para que
## no se quede corriendo indefinidamente.
func _exit_tree() -> void:
	if _is_touch_device or force_show_on_desktop:
		get_tree().call_group("player", "set_touch_sprint", false)
		get_tree().call_group("player", "set_touch_crouch", false)


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


## Mantiene el agachado mientras el botón esté pulsado.
func _on_crouch_button_down() -> void:
	get_tree().call_group("player", "set_touch_crouch", true)


## Deja de agacharse al soltar el botón. Si no hay espacio para levantarse,
## el jugador seguirá agachado hasta que pueda.
func _on_crouch_button_up() -> void:
	get_tree().call_group("player", "set_touch_crouch", false)


## Pide un wall jump. Solo se aplica si el jugador está en el aire tocando
## una pared; en caso contrario, la petición se descarta.
func _on_wall_jump_button_down() -> void:
	get_tree().call_group("player", "request_wall_jump")
