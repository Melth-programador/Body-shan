# =============================================================================
# personaje.gd - Controlador del jugador (cápsula) para body-shan
# =============================================================================
# Este script se adjunta al nodo CharacterBody3D de "mapa.tscn".
#
# SOBRE LOS "IMPORTS":
# GDScript no usa importaciones. Las clases que aparecen en este archivo
# (CharacterBody3D, Input, Vector3, ProjectSettings, etc.) son clases
# integradas del motor y están disponibles globalmente. La única dependencia
# es "extends", que indica de qué clase del motor hereda este script.
#
# CONTROLES:
#   - WASD o flechas : desplazarse en relación a la cámara.
#   - Shift          : correr (multiplica la velocidad).
#   - Espacio        : saltar (solo desde el suelo).
#   - Joystick táctil: desplazarse en móvil.
#   - Botón SALTO    : saltar en móvil.
#   - Botón CORRER   : correr mientras se mantiene pulsado en móvil.
#
# El movimiento es horizontal, con aceleración y desaceleración, gravedad
# cuando el cuerpo está en el aire y reaparición si el jugador cae del mapa.
# =============================================================================

# Hereda de CharacterBody3D: un cuerpo cinemático que se mueve con
# move_and_slide() y que detecta suelo, paredes y techos.
extends CharacterBody3D


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------
# "@export" hace que la variable aparezca en el Inspector de Godot, de modo
# que se puede modificar sin tocar el código. El tipo (: float) y el valor
# inicial (5.0) se usan como valor por defecto.

## Velocidad base al caminar, en metros por segundo (m/s).
@export var speed: float = 5.0

## Multiplicador de velocidad mientras se mantiene pulsado Shift.
## 1.6 significa que al correr se alcanza el 160 % de la velocidad base.
@export var sprint_multiplier: float = 1.6

## Impulso vertical (m/s) que se aplica al empezar un salto.
@export var jump_velocity: float = 5.5

## Aceleración en el suelo, en metros por segundo al cuadrado (m/s²).
## Cuanto mayor sea, antes se alcanza la velocidad objetivo.
@export var acceleration: float = 25.0

## Aceleración en el aire (m/s²). Es menor para que el control aéreo
## no sea tan brusco como el del suelo.
@export var air_acceleration: float = 8.0

## Rapidez con la que el cuerpo gira hacia la dirección en la que camina.
## Un valor alto hace que gire casi de inmediato.
@export var turn_speed: float = 12.0

## Altura (coordenada Y) por debajo de la cual se considera que el jugador
## se cayó del mapa y debe reaparecer en su punto inicial.
@export var respawn_height: float = -12.0


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS (no visibles en el Inspector)
# -----------------------------------------------------------------------------
# El prefijo "_" es una convención de GDScript para indicar que la variable
# es de uso interno del script.

## Gravedad que se leerá de los ajustes del proyecto en _ready().
var _gravity: float = 9.8

## Posición del mundo a la que el jugador vuelve si se cae del mapa.
var _spawn_position: Vector3 = Vector3.ZERO

## Salto solicitado por el botón táctil. El botón puede pulsarse en cualquier
## momento, así que la petición se guarda aquí y se consume en el siguiente
## paso de física, igual que "Input.is_action_just_pressed".
var _jump_requested: bool = false

## Indica si el botón táctil de correr está siendo pulsado. Equivale a
## mantener Shift en teclado.
var _touch_sprint: bool = false


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

## _ready() es un método virtual del motor: se ejecuta una sola vez, cuando
## el nodo y todos sus hijos ya han entrado en el árbol de escena y antes del
## primer fotograma. Se usa para inicializar valores que dependen del entorno.
func _ready() -> void:
	# ProjectSettings.get_setting() lee un ajuste del proyecto.
	# "physics/3d/default_gravity" es la gravedad global configurada en
	# Proyecto > Ajustes del proyecto > Física > 3D.
	# El segundo argumento (9.8) es el valor de reserva si el ajuste no existe.
	# float() convierte el valor devuelto (un Variant) a número decimal.
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

	# global_position es la posición del nodo en coordenadas del mundo.
	# Se guarda para poder volver aquí si el jugador se cae.
	_spawn_position = global_position


## Solicita un salto desde los controles táctiles. La llama mobile_controls.gd
## mediante call_group("player", "request_jump") al pulsar el botón SALTO.
func request_jump() -> void:
	_jump_requested = true


## Activa o desactiva la carrera desde el botón táctil. La llama
## mobile_controls.gd al pulsar y soltar el botón CORRER.
func set_touch_sprint(pressed: bool) -> void:
	_touch_sprint = pressed


## _physics_process() es un método virtual que el motor llama en cada paso de
## física (60 veces por segundo por defecto). Es el lugar correcto para mover
## cuerpos físicos, porque el movimiento queda sincronizado con las colisiones.
## "delta" son los segundos transcurridos desde el paso anterior; multiplicar
## por delta hace que el movimiento no dependa de los FPS.
func _physics_process(delta: float) -> void:
	# =========================================================================
	# 1) GRAVEDAD Y SALTO
	# =========================================================================
	# is_on_floor() devuelve true si el cuerpo está apoyado sobre el suelo.
	# Si no lo está, se aplica gravedad: se resta a la velocidad vertical
	# (velocity.y) la gravedad multiplicada por el tiempo transcurrido.
	# "velocity" es una propiedad integrada de CharacterBody3D.
	# Se combinan el teclado y el botón táctil: basta con que cualquiera de los
	# dos pida el salto. La petición táctil se borra enseguida para que no se
	# repita en los siguientes pasos de física.
	var wants_jump := Input.is_action_just_pressed("jump") or _jump_requested
	_jump_requested = false

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Si está en el suelo y el jugador acaba de pulsar "jump", se asigna de
	# golpe una velocidad vertical positiva. "just_pressed" evita que mantener
	# la tecla pulsada produzca saltos repetidos.
	elif wants_jump:
		velocity.y = jump_velocity

	# =========================================================================
	# 2) DIRECCIÓN DEL MOVIMIENTO
	# =========================================================================
	# Input.get_vector() combina cuatro acciones en un Vector2:
	#   x = move_right - move_left  (positivo a la derecha)
	#   y = move_back  - move_forward (positivo hacia atrás; adelante es -1)
	# El resultado ya viene normalizado (longitud máxima 1), así que las
	# diagonales no son más rápidas que las direcciones rectas.
	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back")

	# get_viewport().get_camera_3d() devuelve la Camera3D activa en el viewport,
	# es decir, la cámara desde la que el jugador está viendo la escena.
	var camera := get_viewport().get_camera_3d()

	# Vector de dirección en el mundo; empieza en cero.
	var direction := Vector3.ZERO

	if camera:
		# camera.global_transform.basis es la orientación de la cámara en el
		# mundo. Al multiplicarla por el Vector2 convertido a Vector3 se obtiene
		# una dirección relativa a lo que ve el jugador: W siempre va hacia
		# delante en la pantalla, aunque la cámara esté girada.
		direction = camera.global_transform.basis * Vector3(
			input_direction.x, 0.0, input_direction.y)
	else:
		# Respaldo por si todavía no hay ninguna cámara activa: se usa la
		# orientación del propio cuerpo.
		direction = global_transform.basis * Vector3(
			input_direction.x, 0.0, input_direction.y)

	# Se descarta la componente vertical para que mirar arriba o abajo con la
	# cámara no haga que el personaje se mueva hacia el cielo o el suelo.
	direction.y = 0.0

	# Si hay dirección de entrada (longitud mayor que 0) se normaliza para
	# obtener un vector de longitud exactamente 1.
	if direction.length_squared() > 0.0:
		direction = direction.normalized()

		# Giro del cuerpo hacia la dirección de avance.
		# En Godot el "frente" de un Node3D es el eje -Z. Por eso se usa
		# atan2(-x, -z): convierte el vector de dirección en un ángulo Y.
		var target_yaw := atan2(-direction.x, -direction.z)

		# lerp_angle() interpola entre el ángulo actual y el objetivo.
		# El peso (1 - exp(-turn_speed * delta)) produce un giro suave que no
		# depende de los FPS: con valores altos de turn_speed gira más rápido.
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	# =========================================================================
	# 3) VELOCIDAD HORIZONTAL
	# =========================================================================
	# Velocidad objetivo base: la velocidad de caminar.
	var current_speed := speed

	# Si se mantiene pulsado "sprint" (Shift), se multiplica la velocidad.
	# is_action_pressed() es true mientras la acción siga pulsada.
	# Se corre si se mantiene Shift (teclado) o el botón CORRER (táctil).
	if Input.is_action_pressed("sprint") or _touch_sprint:
		current_speed *= sprint_multiplier

	# Vector de velocidad al que se quiere llegar: dirección * velocidad.
	var target_velocity := direction * current_speed

	# En el suelo se usa la aceleración normal; en el aire, la reducida.
	# El operador ternario "a if condición else b" elige entre los dos valores.
	var current_acceleration := acceleration if is_on_floor() else air_acceleration

	# move_toward() acerca un valor a otro sin pasarse, como máximo la cantidad
	# indicada. Así la velocidad cambia de forma progresiva (aceleración) y
	# también se detiene suavemente al soltar las teclas (desaceleración).
	# Solo se modifican X y Z: la componente Y la controla la gravedad/salto.
	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)

	# move_and_slide() aplica "velocity" al cuerpo teniendo en cuenta las
	# colisiones del escenario y deslizando por las superficies. Además
	# actualiza internamente el estado de suelo (is_on_floor()).
	move_and_slide()

	# =========================================================================
	# 4) REAPARICIÓN SI SE CAE DEL MAPA
	# =========================================================================
	# Si la coordenada Y del jugador está por debajo del límite, se teletransporta
	# al punto de aparición y se detiene por completo.
	if global_position.y < respawn_height:
		global_position = _spawn_position
		velocity = Vector3.ZERO
