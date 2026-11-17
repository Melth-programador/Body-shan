# =============================================================================
# camara.gd - Controlador de cámara en tercera persona para body-shan
# =============================================================================
# Este script se adjunta al nodo Camera3D de "mapa.tscn".
#
# SOBRE LOS "IMPORTS":
# GDScript no usa importaciones. Las clases que aparecen aquí (Camera3D,
# InputEvent, InputEventMouseMotion, InputEventMouseButton, Input, Vector3,
# PhysicsRayQueryParameters3D, RID, etc.) son clases integradas del motor y
# están disponibles globalmente. La única dependencia es "extends", que indica
# de qué clase del motor hereda este script.
#
# QUÉ HACE:
# Mantiene la cámara orbitando alrededor del jugador a una distancia dada.
# El ratón controla el giro horizontal (yaw) y la inclinación vertical (pitch).
# Un rayo de física evita que la cámara atraviese el suelo o las paredes.
#
# CONTROLES:
#   - Ratón              : girar la cámara alrededor del jugador.
#   - Arrastrar un dedo  : girar la cámara en pantallas táctiles.
#   - Rueda del ratón    : acercar / alejar.
#   - Esc                : liberar el cursor.
#   - Clic               : volver a capturar el cursor.
#
# NOTA: si el proyecto tiene activado "Emulate Touch From Mouse" (Ajustes del
# proyecto > Dispositivos de entrada > Puntero), la cámara funciona como en
# móvil: el cursor queda visible y se gira arrastrando con el ratón. Así se
# pueden usar los controles táctiles (joystick y botones) desde el PC.
# =============================================================================

# Hereda de Camera3D: nodo que representa la cámara con la que se renderiza
# la escena 3D. Este script controla su posición y orientación cada fotograma.
extends Camera3D


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------
# "@export" expone la variable en el Inspector de Godot para poder ajustarla
# sin editar el código. Los tipos (: float, : Node3D...) documentan y validan
# el valor, y lo que aparece tras "=" es el valor por defecto.

## Nodo que la cámara debe seguir. Normalmente será el CharacterBody3D del
## jugador. Si se deja vacío, el script busca el primer nodo del grupo "player".
@export var target: Node3D

## Altura, sobre el origen del jugador, del punto al que mira la cámara.
## Sirve para que la cámara apunte a la cabeza y no a los pies.
@export var height_offset: float = 1.4

## Distancia actual entre la cámara y el jugador, en metros.
@export var distance: float = 3.0

## Distancia mínima permitida al hacer zoom con la rueda (no acercarse más).
@export var min_distance: float = 1.2

## Distancia máxima permitida al hacer zoom con la rueda (no alejarse más).
@export var max_distance: float = 6.0

## Cuánto cambia la distancia con cada muesca de la rueda del ratón.
@export var zoom_step: float = 0.4

## Sensibilidad del ratón: radianes de giro por cada píxel que se mueve.
## @export_range limita los valores que se pueden introducir en el Inspector
## (mínimo, máximo e incremento de la barra deslizante).
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025

## Sensibilidad táctil: radianes de giro por cada píxel que se arrastra el dedo.
@export_range(0.0001, 0.02, 0.0001) var touch_sensitivity: float = 0.004

## Límite inferior de la inclinación vertical, en grados.
## Los valores negativos colocan la cámara por debajo del jugador.
@export var min_pitch_degrees: float = -60.0

## Límite superior de la inclinación vertical, en grados.
## Los valores positivos colocan la cámara por encima del jugador.
@export var max_pitch_degrees: float = 25.0

## Velocidad con la que la cámara se acerca a su posición ideal. Cuanto mayor
## sea, menos retardo tendrá el seguimiento.
@export var follow_speed: float = 14.0

## Separación mínima que se deja entre la cámara y una pared cuando el rayo
## de colisión detecta un obstáculo.
@export var collision_margin: float = 0.2

## Capas de física con las que puede chocar la cámara.
## @export_flags_3d_physics genera en el Inspector una lista de casillas
## (una por capa de colisión) y guarda la selección como máscara de bits.
@export_flags_3d_physics var collision_mask: int = 1


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS (no visibles en el Inspector)
# -----------------------------------------------------------------------------
# El prefijo "_" indica, por convención, que son de uso interno del script.

## Ángulo horizontal actual de la órbita (yaw), en radianes.
var _yaw: float = 0.0

## Ángulo vertical actual de la órbita (pitch), en radianes.
## Empieza en 10 grados para que la cámara mire ligeramente hacia abajo.
var _pitch: float = deg_to_rad(10.0)

## RID ("Resource ID") del cuerpo físico del jugador. Se usa para excluirlo del
## rayo de colisión de la cámara y que esta no choque con el propio personaje.
var _target_rid: RID = RID()

## Indica si la sesión actual se controla con pantalla táctil. Se calcula en
## _ready() y sirve para elegir entre la entrada de ratón y la entrada táctil.
var _is_touch_device: bool = false

## Índice del dedo que está girando la cámara; -1 si ninguno. Guardar el índice
## permite ignorar los dedos que están usando el joystick o los botones y
## admite varios toques a la vez sin mezclar sus movimientos.
var _look_touch_index: int = -1


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

## _ready() es un método virtual del motor: se ejecuta una sola vez, cuando el
## nodo ya está en el árbol de escena y antes del primer fotograma.
## Aquí se resuelve el objetivo, se guarda su RID y se configura el ratón.
func _ready() -> void:
	# OS.has_feature("mobile") es true en Android e iOS, mientras que
	# DisplayServer.is_touchscreen_available() también detecta pantallas
	# táctiles conectadas a un ordenador.
	# "emulate_touch_from_mouse" hace que el ratón genere eventos táctiles,
	# de modo que en PC se pueden usar el joystick y los botones con el ratón.
	# En ese caso la cámara también se comporta como en móvil (sin capturar el
	# cursor y girando con el arrastre).
	_is_touch_device = (
		OS.has_feature("mobile")
		or DisplayServer.is_touchscreen_available()
		or bool(ProjectSettings.get_setting(
			"input_devices/pointing/emulate_touch_from_mouse", false))
	)

	# Si el objetivo no se asignó en el Inspector, se busca en el árbol de
	# escena el primer nodo que pertenezca al grupo "player".
	# "as Node3D" convierte el resultado al tipo esperado (o null si no lo es).
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D

	# "is" comprueba el tipo en tiempo de ejecución. Solo los cuerpos físicos
	# (CollisionObject3D) tienen un RID de física que podamos excluir del rayo.
	if target is CollisionObject3D:
		_target_rid = (target as CollisionObject3D).get_rid()

	# MOUSE_MODE_CAPTURED oculta el cursor y lo mantiene dentro de la ventana.
	# Así el ratón sirve para girar la cámara y no para mover un puntero.
	# En táctil no se captura: no hay cursor que ocultar y la captura puede
	# interferir con los eventos de toque.
	if _is_touch_device:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## _unhandled_input() recibe los eventos de entrada que no ha consumido antes
## ningún Control de la interfaz (por ejemplo, un botón). Es el lugar adecuado
## para la entrada de la cámara.
func _unhandled_input(event: InputEvent) -> void:
	# En un dispositivo táctil se ignora por completo la entrada de ratón
	# (incluida la que el sistema emula a partir de los toques) y se usa
	# exclusivamente el manejo de dedos de _handle_touch_look().
	if _is_touch_device:
		_handle_touch_look(event)
		return

	# --- Movimiento del ratón ---------------------------------------------
	# "is" comprueba que el evento sea realmente un movimiento de ratón.
	# Solo se gira la cámara si el ratón está capturado.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# "event.relative" es el desplazamiento del ratón en píxeles desde el
		# evento anterior. Se multiplica por la sensibilidad para convertirlo
		# en radianes.
		# wrapf() mantiene el yaw dentro de [-PI, PI] para evitar que crezca
		# indefinidamente. Se resta X para que mover el ratón a la derecha
		# gire la vista hacia la derecha.
		_yaw = wrapf(_yaw - event.relative.x * mouse_sensitivity, -PI, PI)

		# El movimiento vertical del ratón modifica el pitch. Se suma Y y se
		# limita entre los ángulos mínimo y máximo (convertidos a radianes con
		# deg_to_rad) para que la cámara no gire por completo.
		_pitch = clampf(
			_pitch + event.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees))

		# El evento ya está atendido; se sale para no procesarlo otra vez.
		return

	# --- Liberar el cursor -------------------------------------------------
	# "ui_cancel" es una acción integrada de Godot asociada a Esc.
	# Al pulsarla se muestra el cursor para poder interactuar con el sistema.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# --- Botones del ratón -------------------------------------------------
	# Solo interesan las pulsaciones (event.pressed), no las sueltas.
	if event is InputEventMouseButton and event.pressed:
		# match compara event.button_index con varios casos posibles.
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				# Acercar: se reduce la distancia, sin bajar del mínimo.
				distance = clampf(distance - zoom_step, min_distance, max_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				# Alejar: se aumenta la distancia, sin pasar del máximo.
				distance = clampf(distance + zoom_step, min_distance, max_distance)
			_:
				# El guion bajo "_" es el caso por defecto: cualquier otro
				# clic (izquierdo, derecho, etc.) vuelve a capturar el ratón.
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Gira la cámara con un dedo. Los toques que caen sobre controles de la
## interfaz (joystick o botones) los consume la GUI y no llegan hasta aquí,
## así que arrastrar fuera de esos controles es lo que mueve la vista.
func _handle_touch_look(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# Al apoyar el primer dedo se recuerda su índice. Si ya había un dedo
		# girando la cámara, el nuevo se ignora para no mezclar movimientos.
		if event.pressed:
			if _look_touch_index == -1:
				_look_touch_index = event.index
		# Al levantar ese mismo dedo se libera la cámara para el siguiente.
		elif event.index == _look_touch_index:
			_look_touch_index = -1
	# Solo los arrastres del dedo que empezó el giro mueven la cámara.
	elif event is InputEventScreenDrag and event.index == _look_touch_index:
		add_look(event.relative)
		# Se marca el evento como atendido para que ningún otro nodo lo repita.
		get_viewport().set_input_as_handled()


## Aplica un desplazamiento relativo (en píxeles) a los ángulos de la órbita.
## Usa touch_sensitivity en lugar de mouse_sensitivity y comparte la misma
## lógica de límites que el ratón: yaw se envuelve y pitch se limita.
func add_look(relative: Vector2) -> void:
	_yaw = wrapf(_yaw - relative.x * touch_sensitivity, -PI, PI)
	_pitch = clampf(
		_pitch + relative.y * touch_sensitivity,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees))


## _process() es un método virtual que el motor llama en cada fotograma
## (no en cada paso de física). La cámara se actualiza aquí para que el
## seguimiento se vea suave aunque la tasa de física sea distinta de los FPS.
## "delta" son los segundos transcurridos desde el fotograma anterior.
func _process(delta: float) -> void:
	# Si no hay objetivo, no hay nada que seguir.
	if target == null:
		return

	# Punto del mundo alrededor del cual orbita la cámara: la posición del
	# jugador elevada "height_offset" metros en vertical.
	# Vector3.UP es el vector (0, 1, 0).
	var pivot := target.global_position + Vector3.UP * height_offset

	# Posición ideal de la cámara: punto de órbita más el desplazamiento
	# calculado por _orbit_offset() multiplicado por la distancia actual.
	var desired_position := pivot + _orbit_offset() * distance

	# ---------------------------------------------------------------------
	# COLISIÓN CON EL ESCENARIO
	# ---------------------------------------------------------------------
	# direct_space_state es el estado del espacio físico 3D del mundo; permite
	# lanzar consultas (rayos, formas) contra los cuerpos de colisión.
	var space := get_world_3d().direct_space_state

	# PhysicsRayQueryParameters3D.create() construye la consulta de un rayo:
	#   1. pivot: desde dónde sale el rayo.
	#   2. desired_position: hasta dónde llega.
	#   3. collision_mask: capas de física que puede golpear.
	#   4. [_target_rid]: lista de RID que se ignoran (el propio jugador).
	var query := PhysicsRayQueryParameters3D.create(
		pivot, desired_position, collision_mask, [_target_rid])

	# intersect_ray() devuelve un diccionario vacío si no hay impacto, o datos
	# del impacto (posición, normal, cuerpo golpeado...) si lo hay.
	var hit := space.intersect_ray(query)

	# Si el rayo golpeó algo, se coloca la cámara justo antes del obstáculo,
	# dejando el margen de seguridad para que no se vea a través de la pared.
	if not hit.is_empty():
		# Dirección desde la posición deseada hacia el jugador (normalizada).
		var safe_direction := (pivot - desired_position).normalized()
		# hit.position es el punto de impacto del rayo.
		desired_position = hit.position + safe_direction * collision_margin

	# ---------------------------------------------------------------------
	# SEGUIMIENTO SUAVE
	# ---------------------------------------------------------------------
	# Se interpola la posición actual hacia la deseada con un peso que depende
	# de delta y de follow_speed. La exponencial hace que el resultado sea
	# independiente de los FPS: a más delta, mayor peso y más rápido se acerca.
	var weight := 1.0 - exp(-follow_speed * delta)

	# lerp() interpola entre dos vectores: actual + (destino - actual) * peso.
	global_position = global_position.lerp(desired_position, weight)

	# look_at() orienta el nodo para que su eje -Z apunte al punto indicado.
	# El segundo argumento (Vector3.UP) indica qué dirección se considera
	# "arriba" para calcular la inclinación de la cámara.
	look_at(pivot, Vector3.UP)


## _orbit_offset() devuelve el vector unitario que va del punto de órbita a la
## cámara, calculado a partir de los ángulos _yaw (horizontal) y _pitch
## (vertical). Es una conversión de coordenadas esféricas a cartesianas.
func _orbit_offset() -> Vector3:
	# cos(_pitch) es el radio horizontal: cuanto más se inclina la cámara
	# (pitch), menor es su componente horizontal.
	var horizontal := cos(_pitch)

	# Componentes del vector:
	#   X = sin(yaw) * cos(pitch)
	#   Y = sin(pitch)
	#   Z = cos(yaw) * cos(pitch)
	# Con yaw = 0 la cámara queda detrás del jugador (Z positivo).
	return Vector3(
		sin(_yaw) * horizontal,
		sin(_pitch),
		cos(_yaw) * horizontal)
