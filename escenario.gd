# =============================================================================
# escenario.gd - Escenario principal de body-shan
# =============================================================================
# Este script se adjunta al nodo raíz de "escenario.tscn".
#
# QUÉ HACE:
# - Controla la meta del nivel: cuando el jugador llega a la torre del norte,
#   muestra el mensaje "¡META ALCANZADA!" con un fundido.
#
# El resto del comportamiento (movimiento, cámara, salto, carrera y
# reaparición si se cae) lo aportan personaje.gd, camara.gd y
# mobile_controls.gd, igual que en el mapa original.
# =============================================================================

extends Node3D


# -----------------------------------------------------------------------------
# NODOS DE LA ESCENA
# -----------------------------------------------------------------------------

@onready var _mensaje: Control = $Interfaz/Mensaje
@onready var _meta: Area3D = $Meta


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS
# -----------------------------------------------------------------------------

## Evita mostrar el mensaje más de una vez.
var _meta_alcanzada: bool = false


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

func _ready() -> void:
	# El mensaje empieza oculto y transparente.
	_mensaje.visible = false
	_mensaje.modulate.a = 0.0

	# Area3D emite body_entered cuando un cuerpo físico entra en su volumen.
	_meta.body_entered.connect(_on_meta_body_entered)


# -----------------------------------------------------------------------------
# META
# -----------------------------------------------------------------------------

## Se ejecuta al entrar un cuerpo en el área de la torre. Solo reacciona al
## jugador (grupo "player") y solo la primera vez.
func _on_meta_body_entered(cuerpo: Node3D) -> void:
	if _meta_alcanzada or not cuerpo.is_in_group("player"):
		return

	_meta_alcanzada = true
	_mensaje.visible = true
	_mensaje.modulate.a = 0.0

	# Fundido de entrada del mensaje.
	var tween := create_tween()
	tween.tween_property(_mensaje, "modulate:a", 1.0, 0.5)
