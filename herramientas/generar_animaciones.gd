# =============================================================================
# generar_animaciones.gd - Genera las animaciones del personaje como .tres
# =============================================================================
# Uso (desde la carpeta del proyecto):
#   godot --headless --path . --script res://herramientas/generar_animaciones.gd
#
# Crea res://animaciones/*.tres y la librería
# res://animaciones/personaje_library.tres.
# Es idempotente: se puede volver a ejecutar tras cambiar el modelo.
# =============================================================================

extends SceneTree

const MODEL_SCENE := "res://personaje (v.0,15).tscn"
const OUT_DIR := "res://animaciones"

const LEG_L := "pierna izquierda"
const LEG_R := "piernas derecha"
const HEAD := "cara"
const ARM_L := "cara/pecho/brazo izquierdo1_2"
const ARM_R := "cara/pecho/brazo derecho1_2"

const WALK_LENGTH := 0.76666665

var _base_pos: Dictionary = {}
var _base_rot: Dictionary = {}


func _init() -> void:
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)

	var model: Node = load(MODEL_SCENE).instantiate()
	_capture(model, LEG_L)
	_capture(model, LEG_R)
	_capture(model, HEAD)
	_capture(model, ARM_L)
	_capture(model, ARM_R)

	var library := AnimationLibrary.new()

	library.add_animation("RESET", _save(_build("RESET", 0.001, false, {}), "reset"))
	library.add_animation("reposo", _save(_build("reposo", 2.4, true, _idle_overrides()), "reposo"))
	library.add_animation("caminar", _save(_build("caminar", WALK_LENGTH, true, _walk_overrides()), "caminar"))
	library.add_animation("correr", _save(_build("correr", 0.5, true, _run_overrides()), "correr"))
	library.add_animation("saltar", _save(_build("saltar", 0.3, false, _jump_overrides()), "saltar"))
	library.add_animation("caer", _save(_build("caer", 0.6, true, _fall_overrides()), "caer"))
	library.add_animation("aterrizar", _save(_build("aterrizar", 0.2, false, _land_overrides()), "aterrizar"))

	var lib_path := OUT_DIR + "/personaje_library.tres"
	var err := ResourceSaver.save(library, lib_path)
	print("Librería guardada: ", lib_path, " (error=", err, ")")
	print("Animaciones: ", library.get_animation_list())

	model.free()
	quit()


# -----------------------------------------------------------------------------
# CAPTURA DE POSES BASE
# -----------------------------------------------------------------------------

func _capture(root: Node, path: String) -> void:
	var node := root.get_node_or_null(path)
	if node is Node3D:
		_base_pos[path] = (node as Node3D).position
		_base_rot[path] = (node as Node3D).rotation
	else:
		push_error("No se encontró el nodo: " + path)


func _pos(path: String, offset: Vector3) -> Vector3:
	return _base_pos[path] + offset


func _rot(path: String, offset: Vector3) -> Vector3:
	return _base_rot[path] + offset


func _base_value(path: String, prop: String) -> Variant:
	return _base_pos[path] if prop == "position" else _base_rot[path]


# -----------------------------------------------------------------------------
# CONSTRUCCIÓN DE ANIMACIONES
# -----------------------------------------------------------------------------

func _props() -> Array:
	return [
		[LEG_L, "position"], [LEG_L, "rotation"],
		[LEG_R, "position"], [LEG_R, "rotation"],
		[HEAD, "position"], [HEAD, "rotation"],
		[ARM_L, "position"], [ARM_L, "rotation"],
		[ARM_R, "position"], [ARM_R, "rotation"],
	]


func _build(name: String, length: float, loop: bool, overrides: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.resource_name = name
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for pair in _props():
		var node_path: String = pair[0]
		var prop: String = pair[1]
		var key := node_path + ":" + prop
		if overrides.has(key):
			var data: Array = overrides[key]
			_add_track(anim, node_path, prop, data[0], data[1])
		else:
			_add_hold(anim, node_path, prop, length)
	return anim


func _add_track(anim: Animation, node_path: String, prop: String, times: PackedFloat32Array, values: Array) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(node_path + ":" + prop))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for i in times.size():
		anim.track_insert_key(track, times[i], values[i])


func _add_hold(anim: Animation, node_path: String, prop: String, length: float) -> void:
	var value: Variant = _base_value(node_path, prop)
	_add_track(anim, node_path, prop, PackedFloat32Array([0.0, length]), [value, value])


func _save(anim: Animation, file_name: String) -> Animation:
	var path := OUT_DIR + "/" + file_name + ".tres"
	var err := ResourceSaver.save(anim, path)
	if err != OK:
		push_error("No se pudo guardar " + path + " (error=" + str(err) + ")")
	return load(path)


func _scale_times(times: PackedFloat32Array, scale: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t in times:
		out.append(t * scale)
	return out


func _scale_rot_x(values: Array, scale: float) -> Array:
	var out: Array = []
	for v in values:
		out.append(Vector3(v.x * scale, v.y, v.z))
	return out


# -----------------------------------------------------------------------------
# DATOS DE CADA ANIMACIÓN
# -----------------------------------------------------------------------------

func _idle_overrides() -> Dictionary:
	var t := PackedFloat32Array([0.0, 1.2, 2.4])
	return {
		HEAD + ":position": [t, [
			_pos(HEAD, Vector3.ZERO),
			_pos(HEAD, Vector3(0, 0.02, 0)),
			_pos(HEAD, Vector3.ZERO)]],
		ARM_R + ":rotation": [t, [
			_rot(ARM_R, Vector3(0.03, 0, 0)),
			_rot(ARM_R, Vector3(-0.03, 0, 0)),
			_rot(ARM_R, Vector3(0.03, 0, 0))]],
		ARM_L + ":rotation": [t, [
			_rot(ARM_L, Vector3(-0.03, 0, 0)),
			_rot(ARM_L, Vector3(0.03, 0, 0)),
			_rot(ARM_L, Vector3(-0.03, 0, 0))]],
	}


func _walk_overrides() -> Dictionary:
	var d := _leg_overrides(1.0, 1.0)
	d.merge(_arm_overrides(WALK_LENGTH, 0.35))
	return d


func _run_overrides() -> Dictionary:
	var d := _leg_overrides(0.5 / WALK_LENGTH, 1.25)
	d.merge(_arm_overrides(0.5, 0.6))
	var t := PackedFloat32Array([0.0, 0.25, 0.5])
	d[HEAD + ":rotation"] = [t, [
		_rot(HEAD, Vector3(0.12, 0, 0)),
		_rot(HEAD, Vector3(0.14, 0, 0)),
		_rot(HEAD, Vector3(0.12, 0, 0))]]
	d[HEAD + ":position"] = [t, [
		_pos(HEAD, Vector3.ZERO),
		_pos(HEAD, Vector3(0, 0.03, 0)),
		_pos(HEAD, Vector3.ZERO)]]
	return d


func _leg_overrides(time_scale: float, rot_scale: float) -> Dictionary:
	var l_pos_t := PackedFloat32Array([0.0, 0.08, 0.2, 0.31, 0.45, 0.47, 0.56])
	var l_pos_v := [
		Vector3(0.11, 0.325, 0.147), Vector3(0.075, 0.57, -0.135),
		Vector3(0.07, 0.57, -0.305), Vector3(0.045, 0.295, -0.11),
		Vector3(0.075, 0.295, 0.21), Vector3(0.11, 0.295, 0.269),
		Vector3(0.08, 0.295, 0.535)]
	var l_rot_t := PackedFloat32Array([0.0, 0.08, 0.2, 0.31, 0.45, 0.56])
	var l_rot_v := [
		Vector3(0, 0, 0), Vector3(0.3577925, 0, 0), Vector3(0.51487213, 0, 0),
		Vector3(0, 0, 0), Vector3(-0.18325958, 0, 0), Vector3(-0.53232545, 0, 0)]
	var r_pos_t := PackedFloat32Array([0.0, 0.1, 0.21, 0.33333334, 0.43333334, 0.6, 0.7])
	var r_pos_v := [
		Vector3(-0.281, 0.299, 0.166), Vector3(-0.281, 0.326, 0.13),
		Vector3(-0.281, 0.3557, 0.0904), Vector3(-0.281, 0.389, 0.046),
		Vector3(-0.281, 0.486, -0.314), Vector3(-0.281, 0.441, -0.389),
		Vector3(-0.281, 0.291, -0.214)]
	var r_rot_t := PackedFloat32Array([0.0, 0.1, 0.21, 0.33333334, 0.43333334, 0.6, 0.6666667])
	var r_rot_v := [
		Vector3(0, 0, 0), Vector3(0.07435103, 0, 0), Vector3(0.15613714, 0, 0),
		Vector3(0.24783675, 0, 0), Vector3(0.4660029, 0, 0), Vector3(0.34906584, 0, 0),
		Vector3(0, 0, 0)]
	return {
		LEG_L + ":position": [_scale_times(l_pos_t, time_scale), l_pos_v],
		LEG_L + ":rotation": [_scale_times(l_rot_t, time_scale), _scale_rot_x(l_rot_v, rot_scale)],
		LEG_R + ":position": [_scale_times(r_pos_t, time_scale), r_pos_v],
		LEG_R + ":rotation": [_scale_times(r_rot_t, time_scale), _scale_rot_x(r_rot_v, rot_scale)],
	}


func _arm_overrides(length: float, amplitude: float) -> Dictionary:
	var t := PackedFloat32Array([0.0, length * 0.25, length * 0.5, length * 0.75, length])
	return {
		ARM_R + ":rotation": [t, [
			_rot(ARM_R, Vector3(amplitude, 0, 0)),
			_rot(ARM_R, Vector3(-amplitude, 0, 0)),
			_rot(ARM_R, Vector3(amplitude, 0, 0)),
			_rot(ARM_R, Vector3(-amplitude, 0, 0)),
			_rot(ARM_R, Vector3(amplitude, 0, 0))]],
		ARM_L + ":rotation": [t, [
			_rot(ARM_L, Vector3(-amplitude, 0, 0)),
			_rot(ARM_L, Vector3(amplitude, 0, 0)),
			_rot(ARM_L, Vector3(-amplitude, 0, 0)),
			_rot(ARM_L, Vector3(amplitude, 0, 0)),
			_rot(ARM_L, Vector3(-amplitude, 0, 0))]],
	}


func _jump_overrides() -> Dictionary:
	var t := PackedFloat32Array([0.0, 0.3])
	return {
		LEG_L + ":position": [t, [_pos(LEG_L, Vector3(0, 0.1, 0)), _pos(LEG_L, Vector3(0, 0.1, 0))]],
		LEG_R + ":position": [t, [_pos(LEG_R, Vector3(0, 0.1, 0)), _pos(LEG_R, Vector3(0, 0.1, 0))]],
		LEG_L + ":rotation": [t, [_rot(LEG_L, Vector3(0.6, 0, 0)), _rot(LEG_L, Vector3(0.6, 0, 0))]],
		LEG_R + ":rotation": [t, [_rot(LEG_R, Vector3(0.6, 0, 0)), _rot(LEG_R, Vector3(0.6, 0, 0))]],
		ARM_L + ":position": [t, [_pos(ARM_L, Vector3(0, 0.15, 0)), _pos(ARM_L, Vector3(0, 0.15, 0))]],
		ARM_R + ":position": [t, [_pos(ARM_R, Vector3(0, 0.15, 0)), _pos(ARM_R, Vector3(0, 0.15, 0))]],
		ARM_L + ":rotation": [t, [_rot(ARM_L, Vector3(-1.4, 0, 0)), _rot(ARM_L, Vector3(-1.4, 0, 0))]],
		ARM_R + ":rotation": [t, [_rot(ARM_R, Vector3(-1.4, 0, 0)), _rot(ARM_R, Vector3(-1.4, 0, 0))]],
		HEAD + ":rotation": [t, [_rot(HEAD, Vector3(-0.15, 0, 0)), _rot(HEAD, Vector3(-0.15, 0, 0))]],
	}


func _fall_overrides() -> Dictionary:
	var t := PackedFloat32Array([0.0, 0.3, 0.6])
	return {
		LEG_L + ":rotation": [t, [
			_rot(LEG_L, Vector3(-0.15, 0, 0.12)),
			_rot(LEG_L, Vector3(-0.1, 0, 0.14)),
			_rot(LEG_L, Vector3(-0.15, 0, 0.12))]],
		LEG_R + ":rotation": [t, [
			_rot(LEG_R, Vector3(-0.15, 0, -0.12)),
			_rot(LEG_R, Vector3(-0.1, 0, -0.14)),
			_rot(LEG_R, Vector3(-0.15, 0, -0.12))]],
		ARM_L + ":rotation": [t, [
			_rot(ARM_L, Vector3(0.2, 0, 0.6)),
			_rot(ARM_L, Vector3(0.2, 0, 0.7)),
			_rot(ARM_L, Vector3(0.2, 0, 0.6))]],
		ARM_R + ":rotation": [t, [
			_rot(ARM_R, Vector3(0.2, 0, -0.6)),
			_rot(ARM_R, Vector3(0.2, 0, -0.7)),
			_rot(ARM_R, Vector3(0.2, 0, -0.6))]],
		HEAD + ":rotation": [t, [
			_rot(HEAD, Vector3(0.15, 0, 0)),
			_rot(HEAD, Vector3(0.18, 0, 0)),
			_rot(HEAD, Vector3(0.15, 0, 0))]],
	}


func _land_overrides() -> Dictionary:
	var t := PackedFloat32Array([0.0, 0.1, 0.2])
	return {
		HEAD + ":position": [t, [
			_pos(HEAD, Vector3(0, -0.12, 0)),
			_pos(HEAD, Vector3(0, -0.05, 0)),
			_pos(HEAD, Vector3.ZERO)]],
		LEG_L + ":rotation": [t, [
			_rot(LEG_L, Vector3(0.5, 0, 0)),
			_rot(LEG_L, Vector3(0.2, 0, 0)),
			_rot(LEG_L, Vector3.ZERO)]],
		LEG_R + ":rotation": [t, [
			_rot(LEG_R, Vector3(0.5, 0, 0)),
			_rot(LEG_R, Vector3(0.2, 0, 0)),
			_rot(LEG_R, Vector3.ZERO)]],
		ARM_L + ":rotation": [t, [
			_rot(ARM_L, Vector3(0.3, 0, 0)),
			_rot(ARM_L, Vector3(0.1, 0, 0)),
			_rot(ARM_L, Vector3.ZERO)]],
		ARM_R + ":rotation": [t, [
			_rot(ARM_R, Vector3(0.3, 0, 0)),
			_rot(ARM_R, Vector3(0.1, 0, 0)),
			_rot(ARM_R, Vector3.ZERO)]],
	}
