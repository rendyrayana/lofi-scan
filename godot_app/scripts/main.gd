extends Node3D

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var viewport3d:   SubViewport   = $SubViewport
@onready var crt_rect:     ColorRect     = $CanvasLayer/CRT
@onready var side_panel:   Panel         = $CanvasLayer/SidePanel
@onready var upload_btn:   Button        = $CanvasLayer/SidePanel/VBox/UploadBtn
@onready var process_btn:  Button        = $CanvasLayer/SidePanel/VBox/ProcessBtn
@onready var input_label:  Label         = $CanvasLayer/SidePanel/VBox/InputLabel
@onready var status_label: RichTextLabel = $CanvasLayer/SidePanel/VBox/StatusLabel
@onready var snap_btn:     CheckButton   = $CanvasLayer/SidePanel/VBox/SnapBtn
@onready var affine_btn:   CheckButton   = $CanvasLayer/SidePanel/VBox/AffineBtn
@onready var dither_btn:   CheckButton   = $CanvasLayer/SidePanel/VBox/DitherBtn
@onready var file_dialog:  FileDialog    = $CanvasLayer/FileDialog

# ─── 3D scene nodes (built in _ready) ────────────────────────────────────────
var cam:        Camera3D
var model_root: Node3D
var psx_shader: Shader
var crt_shader: Shader

# ─── App state ───────────────────────────────────────────────────────────────
var selected_path: String = ""
var repo_root:     String = ""
var pipeline_thread: Thread

const PYTHON_BIN  := "/usr/bin/python3"
const BLENDER_BIN := "/Applications/Blender.app/Contents/MacOS/blender"
const TIER        := 2

# ─── Orbit camera ────────────────────────────────────────────────────────────
var orbit_yaw:    float   = 30.0
var orbit_pitch:  float   = 20.0
var orbit_dist:   float   = 3.0
var orbit_center: Vector3 = Vector3.ZERO
var is_dragging:  bool    = false

var _aabb_acc:   AABB = AABB()
var _aabb_empty: bool = true


# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	repo_root = ProjectSettings.globalize_path("res://").rstrip("/\\").get_base_dir()

	_build_3d_scene()
	_load_shaders()
	_setup_crt()

	upload_btn.pressed.connect(_on_upload_pressed)
	process_btn.pressed.connect(_on_process_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	snap_btn.toggled.connect(func(v): _set_all_shader_param("snap_vertices", v))
	affine_btn.toggled.connect(func(v): _set_all_shader_param("use_affine_uv", v))
	dither_btn.toggled.connect(func(v): _set_all_shader_param("use_dither", v))

	_try_autoload_latest_glb()


func _build_3d_scene() -> void:
	# Camera — must be first so it becomes current in the SubViewport
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 45.0
	cam.near = 0.05
	viewport3d.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	sun.light_energy = 2.0
	sun.light_color = Color(0.81, 0.81, 0.81)
	viewport3d.add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.118, 0.118, 0.118)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	viewport3d.add_child(we)

	model_root = Node3D.new()
	viewport3d.add_child(model_root)

	_update_camera()


func _load_shaders() -> void:
	var p := "res://shaders/psx_shader.gdshader"
	if ResourceLoader.exists(p):
		psx_shader = load(p)
	else:
		push_warning("[lofi-scan] PSX shader not found at %s" % p)

	var c := "res://shaders/magnification.gdshader"
	if ResourceLoader.exists(c):
		crt_shader = load(c)


func _setup_crt() -> void:
	if crt_shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = crt_shader
	# match working project defaults
	mat.set_shader_parameter("grain_intensity",       0.0)
	mat.set_shader_parameter("chromatic_aberration",  0.001)
	mat.set_shader_parameter("warble_amount",         0.001)
	mat.set_shader_parameter("warble_speed",          1.0)
	mat.set_shader_parameter("scanline_intensity",    0.0)
	mat.set_shader_parameter("vignette_darkness",     0.0)
	mat.set_shader_parameter("crt_vignette_power",    0.0)
	crt_rect.material = mat


# ─── Auto-load ───────────────────────────────────────────────────────────────

func _try_autoload_latest_glb() -> void:
	var cache := repo_root.path_join("cache")
	var dir := DirAccess.open(cache)
	if dir == null:
		return

	var newest_glb := ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("_"):
			var sub_path := cache.path_join(entry)
			var sub_dir := DirAccess.open(sub_path)
			if sub_dir:
				sub_dir.list_dir_begin()
				var sub := sub_dir.get_next()
				while sub != "":
					if sub_dir.current_is_dir() and sub.begins_with("final_"):
						var glb := sub_path.path_join(sub).path_join("mesh_lo.glb")
						if FileAccess.file_exists(glb):
							newest_glb = glb
					sub = sub_dir.get_next()
				sub_dir.list_dir_end()
			var direct := sub_path.path_join("mesh_lo.glb")
			if FileAccess.file_exists(direct):
				newest_glb = direct
		entry = dir.get_next()
	dir.list_dir_end()

	if newest_glb != "":
		_load_glb(newest_glb)
		_set_status("[color=gray]Auto-loaded: %s[/color]" % newest_glb.get_file())


# ─── File selection ──────────────────────────────────────────────────────────

func _on_upload_pressed() -> void:
	file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	selected_path = path
	input_label.text = path.get_file()
	process_btn.disabled = false
	_set_status("[color=yellow]Mesh selected — press Process to run pipeline.[/color]")
	if path.get_extension().to_lower() in ["glb", "gltf"]:
		_load_glb(path)


# ─── Pipeline ────────────────────────────────────────────────────────────────

func _on_process_pressed() -> void:
	if selected_path.is_empty():
		return
	upload_btn.disabled = true
	process_btn.disabled = true
	_set_status("[color=cyan]Starting pipeline…[/color]")
	pipeline_thread = Thread.new()
	pipeline_thread.start(_run_pipeline.bind(selected_path))


func _run_pipeline(mesh_path: String) -> void:
	var stem := mesh_path.get_file().get_basename()
	var cache := repo_root.path_join("cache")
	DirAccess.make_dir_recursive_absolute(cache)

	var search_out := cache.path_join(stem + "_search")
	var search_cfg := {
		"input_mesh": mesh_path, "tier": TIER,
		"output_dir": search_out,
		"search_lo": 50, "search_hi": 5000, "max_iter": 12,
		"render_resolution": 256, "bake_resolution": 1024,
		"merge_distance": 0.0, "blender_bin": BLENDER_BIN,
		"camera_distance": 2.5,
	}
	_write_json(cache.path_join("_godot_search.json"), search_cfg)

	var out := []
	var code := OS.execute(PYTHON_BIN,
		[repo_root.path_join("blender_scripts/search.py"),
		 cache.path_join("_godot_search.json")], out, true)
	if code != 0:
		push_error("[search] exit %d\n%s" % [code, "\n".join(out)])
		_finish.call_deferred(false,
			"[color=red]Search failed (exit %d) — see Godot output.[/color]" % code, "")
		return

	var geo_log := _read_json(search_out.path_join("search_log.json"))
	if geo_log.is_empty():
		_finish.call_deferred(false, "[color=red]search_log.json missing.[/color]", "")
		return
	var best_tris := int(geo_log.get("best_tris", 500))

	_set_status.call_deferred(
		"[color=cyan]%d tris found — sweeping textures…[/color]" % best_tris)

	var tex_out := cache.path_join(stem + "_tex")
	var tex_cfg := {
		"input_mesh": mesh_path, "fixed_tri_count": best_tris,
		"tier": TIER, "output_dir": tex_out,
		"resolutions": [16, 32, 64, 128, 256],
		"render_resolution": 256, "merge_distance": 0.0,
		"blender_bin": BLENDER_BIN, "camera_distance": 2.5,
	}
	_write_json(cache.path_join("_godot_tex.json"), tex_cfg)

	out.clear()
	code = OS.execute(PYTHON_BIN,
		[repo_root.path_join("blender_scripts/texture_sweep.py"),
		 cache.path_join("_godot_tex.json")], out, true)
	if code != 0:
		push_error("[tex_sweep] exit %d\n%s" % [code, "\n".join(out)])
		_finish.call_deferred(false,
			"[color=red]Texture sweep failed (exit %d) — see Godot output.[/color]" % code, "")
		return

	var tex_log := _read_json(tex_out.path_join("texture_sweep_log.json"))
	if tex_log.is_empty():
		_finish.call_deferred(false, "[color=red]texture_sweep_log.json missing.[/color]", "")
		return

	var glb: String = (tex_log.get("output_dir", "") as String).path_join("mesh_lo.glb")
	var best_res := int(tex_log.get("best_resolution", 0))
	_finish.call_deferred(true,
		"[color=green]Done!  %d tris  ·  %dpx tex[/color]" % [best_tris, best_res], glb)


func _finish(ok: bool, msg: String, glb_path: String) -> void:
	_set_status(msg)
	upload_btn.disabled = false
	process_btn.disabled = false
	if ok and glb_path != "":
		_load_glb(glb_path)
	if pipeline_thread and pipeline_thread.is_started():
		pipeline_thread.wait_to_finish()


# ─── GLB loading ─────────────────────────────────────────────────────────────

func _load_glb(path: String) -> void:
	for c in model_root.get_children():
		c.queue_free()

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		_set_status("[color=red]Failed to load: %s[/color]" % path.get_file())
		return

	var scene := doc.generate_scene(state)
	model_root.add_child(scene)

	if psx_shader:
		_apply_psx(scene)

	_frame_model.call_deferred()


func _apply_psx(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i)
			var mat := ShaderMaterial.new()
			mat.shader = psx_shader
			if orig is BaseMaterial3D:
				var bm := orig as BaseMaterial3D
				if bm.albedo_texture:
					mat.set_shader_parameter("albedo_map", bm.albedo_texture)
			mat.set_shader_parameter("snap_vertices", snap_btn.button_pressed)
			mat.set_shader_parameter("use_affine_uv",  affine_btn.button_pressed)
			mat.set_shader_parameter("use_dither",     dither_btn.button_pressed)
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_apply_psx(c)


func _set_all_shader_param(param: String, value: Variant) -> void:
	_patch_params(model_root, param, value)

func _patch_params(node: Node, param: String, value: Variant) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter(param, value)
	for c in node.get_children():
		_patch_params(c, param, value)


# ─── Camera framing ──────────────────────────────────────────────────────────

func _frame_model() -> void:
	_aabb_empty = true
	_aabb_acc   = AABB()
	_accumulate_aabb(model_root)
	if _aabb_empty:
		return
	orbit_center = _aabb_acc.get_center()
	orbit_dist   = maxf(_aabb_acc.get_longest_axis_size() * 1.8, 0.3)
	_update_camera()


func _accumulate_aabb(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var world := mi.global_transform * mi.get_aabb()
		if _aabb_empty:
			_aabb_acc  = world
			_aabb_empty = false
		else:
			_aabb_acc = _aabb_acc.merge(world)
	for c in node.get_children():
		_accumulate_aabb(c)


func _update_camera() -> void:
	if cam == null:
		return
	var yr := deg_to_rad(orbit_yaw)
	var pr := deg_to_rad(orbit_pitch)
	cam.position = orbit_center + Vector3(
		orbit_dist * cos(pr) * sin(yr),
		orbit_dist * sin(pr),
		orbit_dist * cos(pr) * cos(yr),
	)
	cam.look_at(orbit_center, Vector3.UP)


# ─── Input ───────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Exclude clicks on the side panel
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var mouse_pos: Vector2
		if event is InputEventMouseButton:
			mouse_pos = (event as InputEventMouseButton).global_position
		else:
			mouse_pos = (event as InputEventMouseMotion).global_position
		if side_panel.get_global_rect().has_point(mouse_pos):
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			orbit_dist = maxf(orbit_dist * 0.9, 0.05)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			orbit_dist = minf(orbit_dist * 1.1, 500.0)
			_update_camera()

	elif event is InputEventMouseMotion and is_dragging:
		var mm := event as InputEventMouseMotion
		orbit_yaw   -= mm.relative.x * 0.4
		orbit_pitch  = clampf(orbit_pitch + mm.relative.y * 0.4, -89.0, 89.0)
		_update_camera()


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _set_status(msg: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = msg
