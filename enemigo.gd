# =============================================================================
# enemigo.gd - Bola roja enemiga para body-shan
# =============================================================================
# Este script se adjunta al nodo raíz de "enemigo.tscn", un CharacterBody3D
# con forma de esfera roja.
#
# QUÉ HACE:
# - Permanece quieta hasta que el jugador entra en su radio de detección.
# - Cuando lo detecta, se desplaza por el suelo hacia él.
# - Si choca contra el jugador, le hace daño.
# - La gravedad la mantiene apoyada sobre el escenario.
#
# El jugador controla su propia vida en personaje.gd. Este enemigo solo llama
# a su método take_damage(); el jugador decide si el golpe cuenta o si está
# en un periodo de invulnerabilidad.
# =============================================================================

extends CharacterBody3D


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------

## Velocidad a la que persigue al jugador, en metros por segundo.
@export var speed: float = 2.4

## Distancia (m) a la que empieza a perseguir al jugador.
@export var detection_radius: float = 14.0

## Puntos de vida que quita al tocar al jugador.
@export var damage: int = 1

## Aceleración (m/s²) con la que cambia de velocidad. Evita arranques y
## frenadas instantáneas.
@export var acceleration: float = 18.0


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS
# -----------------------------------------------------------------------------

## Gravedad leída de los ajustes del proyecto.
var _gravity: float = 9.8

## Referencia al jugador, buscada por el grupo "player".
var _player: Node3D = null

## Radio de la esfera, usado para hacer girar la malla al rodar.
var _radius: float = 0.55

## Malla de la bola, para darle un giro visual mientras se mueve.
var _mesh: MeshInstance3D = null


# -----------------------------------------------------------------------------
# CICLO DE VIDA
# -----------------------------------------------------------------------------

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_mesh = get_node_or_null("Malla") as MeshInstance3D

	var collision := get_node_or_null("Colision") as CollisionShape3D
	if collision and collision.shape is SphereShape3D:
		_radius = (collision.shape as SphereShape3D).radius


func _physics_process(delta: float) -> void:
	# Gravedad cuando está en el aire.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Persecución horizontal. La componente Y se ignora para que la bola no
	# intente "volar" hacia la altura de la cabeza del jugador.
	var target_velocity := Vector3.ZERO
	if _player:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() <= detection_radius and to_player.length_squared() > 0.01:
			target_velocity = to_player.normalized() * speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()

	_rotate_mesh(delta)
	_damage_player_on_contact()


# -----------------------------------------------------------------------------
# DAÑO AL JUGADOR
# -----------------------------------------------------------------------------

## Recorre las colisiones del último move_and_slide() y, si alguna es el
## jugador, le pide que reciba daño. El jugador ignora el golpe si está en
## periodo de invulnerabilidad o si ya no le queda vida.
func _damage_player_on_contact() -> void:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node3D and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.call("take_damage", damage, global_position)
			return


# -----------------------------------------------------------------------------
# EFECTO VISUAL
# -----------------------------------------------------------------------------

## Gira la esfera en la dirección en la que rueda. El eje de giro es
## perpendicular al movimiento y la cantidad girada depende de la distancia
## recorrida y del radio.
func _rotate_mesh(delta: float) -> void:
	if _mesh == null:
		return

	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := flat_velocity.length()
	if horizontal_speed < 0.05:
		return

	var axis := Vector3(flat_velocity.z, 0.0, -flat_velocity.x).normalized()
	_mesh.rotate(axis, horizontal_speed * delta / _radius)
