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
#   - Ctrl           : agacharse (mantener pulsado).
#   - J              : wall jump (salto desde una pared).
#   - Joystick táctil: desplazarse en móvil.
#   - Botón SALTO    : saltar en móvil.
#   - Botón CORRER   : correr mientras se mantiene pulsado en móvil.
#   - Botón AGACHARSE: agacharse mientras se mantiene pulsado en móvil.
#   - Botón WALL JUMP: saltar desde una pared en móvil.
#
# El movimiento es horizontal, con aceleración y desaceleración, gravedad
# cuando el cuerpo está en el aire, deslizamiento por paredes, wall jump,
# coyote time (margen para saltar tras dejar el borde) y reaparición si el
# jugador cae del mapa.
#
# SISTEMA DE VIDA:
# El jugador tiene varios puntos de vida. Los enemigos le llaman a
# take_damage(); al recibir un golpe queda invulnerable unos instantes y
# retrocede. Si la vida llega a cero, reaparece en el punto inicial con la
# vida completa.
# =============================================================================

# Hereda de CharacterBody3D: un cuerpo cinemático que se mueve con
# move_and_slide() y que detecta suelo, paredes y techos.
extends CharacterBody3D

## Se emite cada vez que cambia la vida. La interfaz lo usa para actualizar
## el marcador. Los argumentos son (vida actual, vida máxima).
signal health_changed(current_health: int, max_health: int)


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

## Velocidad horizontal (m/s) por debajo de la cual se considera que el
## jugador está quieto y la animación de caminar se detiene.
@export var animation_speed_threshold: float = 0.2

## Multiplicador de velocidad mientras el jugador está agachado.
## 0.45 significa que se mueve al 45 % de su velocidad normal.
@export_range(0.1, 1.0, 0.05) var crouch_speed_multiplier: float = 0.45

## Altura total (m) de la cápsula de colisión cuando el jugador se agacha.
## Al agacharse también se comprime el modelo para que se note visualmente.
@export var crouch_height: float = 1.5

## Impulso vertical (m/s) que se aplica al hacer un wall jump.
@export var wall_jump_velocity: float = 6.0

## Empuje horizontal (m/s) del wall jump. Aleja al jugador de la pared.
@export var wall_jump_push: float = 6.5

## Velocidad máxima de caída (m/s) al deslizarse pegado a una pared.
## Un valor bajo hace que la caída sea lenta, como si el personaje se agarrara.
@export var wall_slide_speed: float = 2.2

## Tiempo (s) después de salir de una plataforma en el que todavía se puede
## saltar. Se conoce como "coyote time" y perdona pulsaciones tardías.
@export var coyote_time: float = 0.12

## Tiempo (s) que se recuerda una pulsación de salto antes de aterrizar.
## Se conoce como "jump buffer" y perdona pulsaciones anticipadas.
@export var jump_buffer_time: float = 0.12

## Puntos de vida máximos del jugador.
@export var max_health: int = 3

## Duración (s) de la invulnerabilidad después de recibir un golpe.
@export var invulnerability_time: float = 1.2

## Fuerza con la que el jugador sale despedido al recibir daño.
@export var damage_knockback: float = 6.0


# -----------------------------------------------------------------------------
# CONSTANTES
# -----------------------------------------------------------------------------

## Nombre exacto de la animación de caminar del modelo (incluye el espacio
## final que tiene en el AnimationPlayer).
const WALK_ANIMATION := "caminar "


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

## Indica si el botón táctil AGACHARSE está siendo pulsado.
var _touch_crouch: bool = false

## Petición de wall jump hecha con el botón táctil. Se consume en el
## siguiente paso de física, igual que _jump_requested.
var _wall_jump_requested: bool = false

## Estado actual de agachado.
var _is_crouching: bool = false

## Tiempo restante de "coyote time" y de "jump buffer".
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

## Vida actual y tiempo restante de invulnerabilidad.
var _health: int = 0
var _invulnerability_timer: float = 0.0

## Cápsula de colisión del jugador y nodo del modelo visual. Se guardan en
## _ready() para poder cambiar su altura al agacharse.
var _collision_shape: CollisionShape3D = null
var _capsule: CapsuleShape3D = null
var _model: Node3D = null

## Altura y posición originales de la cápsula, para restaurarlas al levantarse.
var _stand_height: float = 0.0
var _stand_shape_y: float = 0.0
var _crouch_shape_y: float = 0.0

## AnimationPlayer del modelo del personaje. Se busca en _ready() para no
## depender de la ruta exacta del nodo.
var _animation_player: AnimationPlayer = null


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

	# El AnimationPlayer vive dentro del modelo instanciado. find_child() lo
	# busca en todos los descendientes, así no importa cómo se llame el nodo
	# que contiene el modelo.
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

	# La animación de caminar debe repetirse mientras el jugador se mueve.
	# Se activa el bucle en tiempo de ejecución para no depender de que el
	# recurso ya venga configurado así.
	if _animation_player and _animation_player.has_animation(WALK_ANIMATION):
		var walk := _animation_player.get_animation(WALK_ANIMATION)
		if walk:
			walk.loop_mode = Animation.LOOP_LINEAR

	# Se localizan la cápsula de colisión y el modelo visual para poder
	# agacharse sin depender de rutas profundas del árbol.
	_collision_shape = get_node_or_null("Colision") as CollisionShape3D
	if _collision_shape:
		_capsule = _collision_shape.shape as CapsuleShape3D
		if _capsule:
			_stand_height = _capsule.height
			_stand_shape_y = _collision_shape.position.y
			# El centro de la cápsula debe quedar a media altura para que
			# sus pies sigan apoyados en el origen del jugador.
			crouch_height = clampf(
				crouch_height, _capsule.radius * 2.0 + 0.01, _stand_height)
			_crouch_shape_y = crouch_height * 0.5

	_model = get_node_or_null("Personaje") as Node3D

	# La vida empieza al máximo. La interfaz se sincroniza después.
	_health = max_health
	health_changed.emit(_health, max_health)


## Devuelve la vida actual. La usa la interfaz de escenario.gd.
func get_health() -> int:
	return _health


## Devuelve la vida máxima. La usa la interfaz de escenario.gd.
func get_max_health() -> int:
	return max_health


## Aplica daño al jugador. La llaman los enemigos al tocarlo.
## "from_position" es el punto del enemigo y sirve para calcular el empuje.
func take_damage(amount: int, from_position: Vector3 = Vector3.ZERO) -> void:
	# Durante la invulnerabilidad o con la vida ya a cero se ignora el golpe.
	if amount <= 0 or _invulnerability_timer > 0.0 or _health <= 0:
		return

	_health = maxi(_health - amount, 0)
	health_changed.emit(_health, max_health)

	if _health <= 0:
		_respawn()
		return

	_invulnerability_timer = invulnerability_time
	_apply_damage_knockback(from_position)


## Cura al jugador sin superar la vida máxima.
func heal(amount: int) -> void:
	if amount <= 0:
		return
	_health = mini(_health + amount, max_health)
	health_changed.emit(_health, max_health)


## Empuja al jugador en dirección contraria al enemigo y lo lanza un poco
## hacia arriba para que el golpe se sienta y pueda escapar.
func _apply_damage_knockback(from_position: Vector3) -> void:
	var push_direction := global_position - from_position
	push_direction.y = 0.0

	if push_direction.length_squared() < 0.001:
		push_direction = -global_transform.basis.z
	push_direction = push_direction.normalized()

	velocity.x = push_direction.x * damage_knockback
	velocity.z = push_direction.z * damage_knockback
	velocity.y = maxf(velocity.y, 3.0)


## Reaparece en el punto inicial con la vida completa y un breve margen de
## invulnerabilidad para no morir encadenado si hay enemigos cerca.
func _respawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_health = max_health
	_invulnerability_timer = maxf(invulnerability_time, 1.0)
	health_changed.emit(_health, max_health)


## Solicita un salto desde los controles táctiles. La llama mobile_controls.gd
## mediante call_group("player", "request_jump") al pulsar el botón SALTO.
func request_jump() -> void:
	_jump_requested = true


## Activa o desactiva la carrera desde el botón táctil. La llama
## mobile_controls.gd al pulsar y soltar el botón CORRER.
func set_touch_sprint(pressed: bool) -> void:
	_touch_sprint = pressed


## Solicita un wall jump desde los controles táctiles. La petición solo se
## aplica si en ese momento el jugador está pegado a una pared en el aire.
func request_wall_jump() -> void:
	_wall_jump_requested = true


## Activa o desactiva el agachado desde el botón táctil. Se mantiene agachado
## mientras el botón esté pulsado, igual que mantener Ctrl en teclado.
func set_touch_crouch(pressed: bool) -> void:
	_touch_crouch = pressed


## _physics_process() es un método virtual que el motor llama en cada paso de
## física (60 veces por segundo por defecto). Es el lugar correcto para mover
## cuerpos físicos, porque el movimiento queda sincronizado con las colisiones.
## "delta" son los segundos transcurridos desde el paso anterior; multiplicar
## por delta hace que el movimiento no dependa de los FPS.
func _physics_process(delta: float) -> void:
	# La invulnerabilidad se agota con el tiempo.
	_invulnerability_timer = maxf(_invulnerability_timer - delta, 0.0)

	# =========================================================================
	# 1) AGACHARSE
	# =========================================================================
	# Se combinan el teclado (Ctrl) y el botón táctil. Mientras se mantiene
	# pulsado, el jugador se agacha; al soltarlo, se levanta si hay espacio.
	var wants_crouch := Input.is_action_pressed("crouch") or _touch_crouch
	if wants_crouch and not _is_crouching:
		_set_crouching(true)
	elif not wants_crouch and _is_crouching and _can_stand():
		_set_crouching(false)

	# =========================================================================
	# 2) GRAVEDAD, SALTO Y WALL JUMP
	# =========================================================================
	# is_on_floor() devuelve true si el cuerpo está apoyado sobre el suelo.
	# Se combinan el teclado y el botón táctil: basta con que cualquiera de los
	# dos pida el salto. Las peticiones táctiles se borran enseguida para que
	# no se repitan en los siguientes pasos de física.
	var wants_jump := Input.is_action_just_pressed("jump") or _jump_requested
	var wants_wall_jump := (
		Input.is_action_just_pressed("wall_jump") or _wall_jump_requested)
	_jump_requested = false
	_wall_jump_requested = false

	# "Coyote time": al estar en el suelo se recarga el margen para saltar;
	# en el aire se va agotando. Permite saltar poco después de dejar el borde.
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# "Jump buffer": recuerda durante un instante que se pulsó salto, de modo
	# que si el jugador aterriza justo después, el salto no se pierde.
	if wants_jump:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# ¿Está en el aire y tocando una pared? is_on_wall() se actualiza en
	# move_and_slide(), así que aquí se usa el estado del paso anterior.
	var on_wall := not is_on_floor() and is_on_wall()

	if on_wall and (wants_wall_jump or _jump_buffer_timer > 0.0):
		# Wall jump: impulso vertical y empuje horizontal alejándose de la pared.
		_perform_wall_jump()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	elif is_on_floor():
		# Salto normal desde el suelo si hay una pulsación pendiente.
		if _jump_buffer_timer > 0.0:
			velocity.y = jump_velocity
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
	elif _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		# Salto dentro del margen de coyote time: el jugador acaba de dejar
		# el borde de una plataforma y todavía puede saltar.
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	else:
		# Gravedad normal en el aire.
		velocity.y -= _gravity * delta

		# Deslizamiento por pared: si cae pegado a una pared, se limita la
		# velocidad de caída para dar tiempo a preparar el wall jump.
		if on_wall and velocity.y < 0.0:
			velocity.y = maxf(velocity.y, -wall_slide_speed)

	# =========================================================================
	# 3) DIRECCIÓN DEL MOVIMIENTO
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
	# 4) VELOCIDAD HORIZONTAL
	# =========================================================================
	# Velocidad objetivo base: la velocidad de caminar.
	var current_speed := speed

	# Agachado se reduce la velocidad y no se puede correr. Si no está
	# agachado, Shift o el botón CORRER multiplican la velocidad.
	if _is_crouching:
		current_speed *= crouch_speed_multiplier
	elif Input.is_action_pressed("sprint") or _touch_sprint:
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
	# 5) REAPARICIÓN SI SE CAE DEL MAPA
	# =========================================================================
	# Si la coordenada Y del jugador está por debajo del límite, reaparece en
	# el punto inicial y recupera la vida.
	if global_position.y < respawn_height:
		_respawn()

	# =========================================================================
	# 6) ANIMACIÓN DEL MODELO
	# =========================================================================
	_update_animation()


## Cambia entre agachado y de pie. Ajusta la altura de la cápsula de colisión
## y comprime verticalmente el modelo para que el cambio se note, ya que
## todavía no existe una animación específica de agacharse.
func _set_crouching(crouching: bool) -> void:
	_is_crouching = crouching

	if _capsule and _collision_shape:
		_capsule.height = crouch_height if crouching else _stand_height
		_collision_shape.position.y = _crouch_shape_y if crouching else _stand_shape_y

	if _model and _stand_height > 0.0:
		# Se usa la proporción entre la altura agachada y la altura de pie.
		# Así el modelo queda aplastado de forma coherente con la cápsula.
		_model.scale.y = crouch_height / _stand_height if crouching else 1.0


## Comprueba si hay sitio para levantarse. Lanza una forma con la cápsula de
## pie desde la posición actual; si no golpea nada, se puede dejar de agachar.
func _can_stand() -> bool:
	if _capsule == null:
		return true

	# Se deja un pequeño margen para no chocar con el propio suelo.
	var margin := 0.05
	var standing_capsule := CapsuleShape3D.new()
	standing_capsule.radius = _capsule.radius
	standing_capsule.height = maxf(_stand_height - margin, standing_capsule.radius * 2.0)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_capsule
	query.collision_mask = collision_mask
	var exclude: Array[RID] = [get_rid()]
	query.exclude = exclude
	query.transform = Transform3D(
		global_transform.basis,
		global_position + Vector3.UP * (_stand_shape_y + margin * 0.5))

	var hits := get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits.is_empty()


## Aplica el impulso del wall jump usando la normal de la pared tocada.
## get_wall_normal() apunta desde la pared hacia el jugador.
func _perform_wall_jump() -> void:
	var wall_normal := get_wall_normal()
	wall_normal.y = 0.0

	# Respaldo por si la normal no es horizontal (esquinas o rampas).
	if wall_normal.length_squared() < 0.001:
		wall_normal = -global_transform.basis.z
	wall_normal = wall_normal.normalized()

	# Empuje horizontal hacia fuera de la pared + impulso vertical.
	velocity.x = wall_normal.x * wall_jump_push
	velocity.z = wall_normal.z * wall_jump_push
	velocity.y = wall_jump_velocity

	# El personaje mira en la dirección en la que sale despedido.
	rotation.y = atan2(-wall_normal.x, -wall_normal.z)


## Reproduce la animación de caminar mientras el jugador se desplaza por el
## suelo, la pausa al quedarse quieto y ajusta su velocidad a la del jugador.
func _update_animation() -> void:
	if _animation_player == null:
		return

	# Velocidad horizontal real (sin contar la caída/salto).
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_walking := is_on_floor() and horizontal_speed > animation_speed_threshold

	if is_walking:
		# Si aún no es la animación actual, se inicia. Si estaba pausada,
		# play() sin argumentos la reanuda desde el fotograma donde quedó.
		if _animation_player.current_animation != WALK_ANIMATION:
			_animation_player.play(WALK_ANIMATION)
		elif not _animation_player.is_playing():
			_animation_player.play()

		# La animación se acelera con la velocidad: al correr (Shift o botón
		# CORRER) se ve más rápida que al caminar.
		_animation_player.speed_scale = clampf(
			horizontal_speed / speed, 0.5, sprint_multiplier + 0.2)
	elif _animation_player.is_playing():
		# Quieto o en el aire: se detiene la animación de caminar.
		_animation_player.pause()
