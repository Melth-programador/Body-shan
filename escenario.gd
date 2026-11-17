# =============================================================================
# escenario.gd - Escenario principal de body-shan
# =============================================================================
# Este script se adjunta al nodo raíz de "escenario.tscn".
#
# QUÉ HACE:
# - Controla la meta del nivel: cuando el jugador llega a la torre del norte,
#   muestra el mensaje "¡META ALCANZADA!" con un fundido.
# - Muestra un objetivo breve al empezar y un aviso al encontrar el secreto
#   del laberinto.
# - Permite volver al menú de inicio con el botón MENÚ (o Escape).
#
# El resto del comportamiento (movimiento, cámara, salto, carrera y
# reaparición si se cae) lo aportan personaje.gd, camara.gd y
# mobile_controls.gd, igual que en el mapa original.
# =============================================================================

extends Node3D


# -----------------------------------------------------------------------------
# PARÁMETROS AJUSTABLES DESDE EL INSPECTOR
# -----------------------------------------------------------------------------

## Escena del menú de inicio a la que se vuelve con el botón MENÚ.
@export_file("*.tscn") var escena_menu: String = "res://menu_inicio.tscn"


# -----------------------------------------------------------------------------
# NODOS DE LA ESCENA
# -----------------------------------------------------------------------------

@onready var _mensaje: Control = $Interfaz/Mensaje
@onready var _meta: Area3D = $Meta
@onready var _boton_menu: Button = $Interfaz/BotonMenu
@onready var _objetivo: Label = $Interfaz/Objetivo
@onready var _aviso_secreto: Label = $Interfaz/AvisoSecreto
@onready var _secreto: Area3D = $Secreto


# -----------------------------------------------------------------------------
# VARIABLES INTERNAS
# -----------------------------------------------------------------------------

## Evita mostrar el mensaje más de una vez.
var _meta_alcanzada: bool = false

## Evita mostrar el aviso del secreto más de una vez.
var _secreto_encontrado: bool = false

## Evita pedir el cambio de escena más de una vez.
var _saliendo: bool = false


# -----------------------------------------------------------------------------
# MÉTODOS DEL CICLO DE VIDA
# -----------------------------------------------------------------------------

func _ready() -> void:
	# El mensaje empieza oculto y transparente.
	_mensaje.visible = false
	_mensaje.modulate.a = 0.0

	# Area3D emite body_entered cuando un cuerpo físico entra en su volumen.
	_meta.body_entered.connect(_on_meta_body_entered)
	_secreto.body_entered.connect(_on_secreto_body_entered)

	# Botón para volver al menú de inicio.
	_boton_menu.pressed.connect(_volver_al_menu)

	# El objetivo se muestra unos segundos y luego se desvanece solo.
	_objetivo.modulate.a = 1.0
	var tween_objetivo := create_tween()
	tween_objetivo.tween_interval(5.0)
	tween_objetivo.tween_property(_objetivo, "modulate:a", 0.0, 1.0)


# -----------------------------------------------------------------------------
# OBJETIVO Y SECRETO
# -----------------------------------------------------------------------------

## Muestra un aviso breve al entrar en el nicho secreto del laberinto.
func _on_secreto_body_entered(cuerpo: Node3D) -> void:
	if _secreto_encontrado or not cuerpo.is_in_group("player"):
		return

	_secreto_encontrado = true
	_aviso_secreto.visible = true
	_aviso_secreto.modulate.a = 0.0

	# Fundido de entrada, pausa y fundido de salida del aviso.
	var tween := create_tween()
	tween.tween_property(_aviso_secreto, "modulate:a", 1.0, 0.35)
	tween.tween_interval(2.5)
	tween.tween_property(_aviso_secreto, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_ocultar_aviso_secreto)


## Oculta el aviso cuando termina su fundido de salida.
func _ocultar_aviso_secreto() -> void:
	_aviso_secreto.visible = false


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


## Escape permite volver al menú durante la partida.
func _unhandled_input(evento: InputEvent) -> void:
	if _saliendo:
		return

	if evento.is_action_pressed("ui_cancel"):
		_volver_al_menu()
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------------
# SALIDA AL MENÚ
# -----------------------------------------------------------------------------

## Vuelve al menú de inicio.
func _volver_al_menu() -> void:
	if _saliendo:
		return

	_saliendo = true
	var error := get_tree().change_scene_to_file(escena_menu)
	if error != OK:
		push_error("No se pudo volver al menú: %s" % escena_menu)
		_saliendo = false
