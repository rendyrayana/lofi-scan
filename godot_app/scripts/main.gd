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
@onready var tier_option:    OptionButton     = $CanvasLayer/SidePanel/VBox/TierRow/TierOption
@onready var result_label:   Label            = $CanvasLayer/SidePanel/VBox/ResultLabel
@onready var export_btn:     Button           = $CanvasLayer/SidePanel/VBox/ExportBtn
@onready var bg_color_btn:   ColorPickerButton = $CanvasLayer/SidePanel/VBox/BGRow/BGColor
@onready var turntable_btn:  CheckButton      = $CanvasLayer/SidePanel/VBox/TurntableBtn
@onready var speed_slider:   HSlider          = $CanvasLayer/SidePanel/VBox/SpeedRow/SpeedSlider
@onready var batch_btn:      Button           = $CanvasLayer/SidePanel/VBox/BatchBtn
@onready var file_dialog:    FileDialog       = $CanvasLayer/FileDialog
@onready var export_dialog:  FileDialog       = $CanvasLayer/ExportDialog
@onready var batch_dialog:   FileDialog       = $CanvasLayer/BatchDialog

# ─── 3D scene nodes (built in _ready) ────────────────────────────────────────
var cam:        Camera3D
var model_root: Node3D
var world_env:  WorldEnvironment
var psx_shader: Shader
var crt_shader: Shader

# ─── App state ───────────────────────────────────────────────────────────────
var selected_path:         String = ""
var selected_texture_path: String = ""
var last_glb_path:         String = ""
var repo_root:             String = ""
var pipeline_thread:  Thread
var batch_thread:     Thread
var batch_results:    Array = []

const PYTHON_BIN  := "/usr/bin/python3"
const BLENDER_BIN := "/Applications/Blender.app/Contents/MacOS/blender"

# Tier 1=draft 2=fast 3=quality 4=max  (index matches OptionButton selected)
const TIER_SSIM  := [0.70, 0.85, 0.92, 0.97]
const TIER_RES   := [[64, 128], [64, 128, 256], [128, 256, 512], [256, 512, 1024]]

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
	batch_btn.pressed.connect(_on_batch_pressed)
	process_btn.pressed.connect(_on_process_pressed)
	export_btn.pressed.connect(_on_export_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	export_dialog.file_selected.connect(_on_export_path_selected)
	batch_dialog.dir_selected.connect(_on_batch_folder_selected)
	snap_btn.toggled.connect(func(v): _set_all_shader_param("snap_vertices", v))
	affine_btn.toggled.connect(func(v): _set_all_shader_param("use_affine_uv", v))
	dither_btn.toggled.connect(func(v): _set_all_shader_param("use_dither", v))
	bg_color_btn.color_changed.connect(_on_bg_color_changed)

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
	world_env = WorldEnvironment.new()
	world_env.environment = env
	viewport3d.add_child(world_env)

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
	selected_texture_path = ""
	if path.get_extension().to_lower() == "obj":
		var base := path.get_basename()
		for ext: String in ["jpg", "jpeg", "png", "tga"]:
			var candidate := base + "." + ext
			if FileAccess.file_exists(candidate):
				selected_texture_path = candidate
				break
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
	var tier_idx: int = tier_option.selected  # 0-3
	var tier_num: int = tier_idx + 1
	var ssim_thresh: float = TIER_SSIM[tier_idx]
	var res_list: Array = TIER_RES[tier_idx]

	var stem := mesh_path.get_file().get_basename()
	var cache := repo_root.path_join("cache")
	DirAccess.make_dir_recursive_absolute(cache)

	var search_out := cache.path_join(stem + "_search")
	var search_cfg := {
		"input_mesh": mesh_path, "tier": tier_num,
		"output_dir": search_out,
		"search_lo": 50, "search_hi": 5000, "max_iter": 12,
		"render_resolution": 512, "bake_resolution": 1024,
		"merge_distance": 0.0, "blender_bin": BLENDER_BIN,
		"camera_distance": 2.5,
		"input_texture": selected_texture_path if selected_texture_path != "" else null,
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
		"tier": tier_num, "output_dir": tex_out,
		"resolutions": res_list,
		"render_resolution": 512, "merge_distance": 0.0,
		"blender_bin": BLENDER_BIN, "camera_distance": 2.5,
		"input_texture": selected_texture_path if selected_texture_path != "" else null,
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
		"[color=green]Done![/color]",
		glb, best_tris, best_res)


func _finish(ok: bool, msg: String, glb_path: String,
		best_tris: int = 0, best_res: int = 0) -> void:
	_set_status(msg)
	upload_btn.disabled = false
	process_btn.disabled = false
	if ok and glb_path != "":
		last_glb_path = glb_path
		export_btn.disabled = false
		result_label.text = "%d tris  ·  %dpx tex" % [best_tris, best_res]
		result_label.visible = true
		_load_glb(glb_path)
	if pipeline_thread and pipeline_thread.is_started():
		pipeline_thread.wait_to_finish()


func _on_export_pressed() -> void:
	if last_glb_path.is_empty():
		return
	var stem := selected_path.get_file().get_basename() if selected_path != "" else "export"
	export_dialog.current_file = stem + "_lofi.glb"
	export_dialog.popup_centered()


func _on_export_path_selected(dest: String) -> void:
	if not dest.ends_with(".glb"):
		dest += ".glb"
	var src := FileAccess.open(last_glb_path, FileAccess.READ)
	var dst := FileAccess.open(dest, FileAccess.WRITE)
	if src == null or dst == null:
		_set_status("[color=red]Export failed — could not copy file.[/color]")
		return
	dst.store_buffer(src.get_buffer(src.get_length()))
	_set_status("[color=green]Exported: %s[/color]" % dest.get_file())


# ─── Batch ───────────────────────────────────────────────────────────────────

func _on_batch_pressed() -> void:
	batch_dialog.popup_centered()


func _on_batch_folder_selected(folder: String) -> void:
	upload_btn.disabled = true
	batch_btn.disabled  = true
	process_btn.disabled = true
	export_btn.disabled  = true
	batch_results.clear()
	_set_status("[color=cyan]Scanning folder…[/color]")
	batch_thread = Thread.new()
	batch_thread.start(_run_batch.bind(folder))


func _run_batch(folder: String) -> void:
	var tier_idx: int  = tier_option.selected
	var tier_num: int  = tier_idx + 1
	var res_list: Array = TIER_RES[tier_idx]

	# Collect .obj files
	var meshes: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.get_extension().to_lower() == "obj":
				meshes.append(folder.path_join(f))
			f = dir.get_next()
		dir.list_dir_end()

	if meshes.is_empty():
		_batch_done.call_deferred(folder, false)
		return

	var total := meshes.size()
	for i: int in total:
		var mesh_path: String = meshes[i]
		_set_status.call_deferred(
			"[color=cyan][%d/%d] %s[/color]" % [i + 1, total, mesh_path.get_file()])

		# Auto-detect texture
		var tex_path: String = ""
		var base := mesh_path.get_basename()
		for ext: String in ["jpg", "jpeg", "png", "tga"]:
			var candidate := base + "." + ext
			if FileAccess.file_exists(candidate):
				tex_path = candidate
				break

		var stem := mesh_path.get_file().get_basename()
		var cache := repo_root.path_join("cache")
		var search_out := cache.path_join(stem + "_search")
		var search_cfg := {
			"input_mesh": mesh_path, "tier": tier_num,
			"output_dir": search_out,
			"search_lo": 50, "search_hi": 5000, "max_iter": 12,
			"render_resolution": 512, "bake_resolution": 1024,
			"merge_distance": 0.0, "blender_bin": BLENDER_BIN,
			"camera_distance": 2.5,
			"input_texture": tex_path if tex_path != "" else null,
		}
		_write_json(cache.path_join("_batch_search.json"), search_cfg)

		var out: Array = []
		var code := OS.execute(PYTHON_BIN,
			[repo_root.path_join("blender_scripts/search.py"),
			 cache.path_join("_batch_search.json")], out, true)
		var best_tris := 500
		if code == 0:
			var geo_log := _read_json(search_out.path_join("search_log.json"))
			best_tris = int(geo_log.get("best_tris", 500))

		var tex_out := cache.path_join(stem + "_tex")
		var tex_cfg := {
			"input_mesh": mesh_path, "fixed_tri_count": best_tris,
			"tier": tier_num, "output_dir": tex_out,
			"resolutions": res_list,
			"render_resolution": 512, "merge_distance": 0.0,
			"blender_bin": BLENDER_BIN, "camera_distance": 2.5,
			"input_texture": tex_path if tex_path != "" else null,
		}
		_write_json(cache.path_join("_batch_tex.json"), tex_cfg)

		out.clear()
		code = OS.execute(PYTHON_BIN,
			[repo_root.path_join("blender_scripts/texture_sweep.py"),
			 cache.path_join("_batch_tex.json")], out, true)

		var best_res := 0
		var glb_path := ""
		var ssim := 0.0
		if code == 0:
			var tex_log := _read_json(tex_out.path_join("texture_sweep_log.json"))
			best_res  = int(tex_log.get("best_resolution", 0))
			ssim      = float(tex_log.get("best_ssim", 0.0))
			glb_path  = (tex_log.get("output_dir", "") as String).path_join("mesh_lo.glb")

		batch_results.append({
			"file":     mesh_path.get_file(),
			"tris":     best_tris,
			"tex_res":  best_res,
			"ssim":     ssim,
			"glb":      glb_path,
			"ok":       code == 0,
		})

	_batch_done.call_deferred(folder, true)


func _batch_done(folder: String, ok: bool) -> void:
	upload_btn.disabled  = false
	batch_btn.disabled   = false
	process_btn.disabled = selected_path.is_empty()

	if not ok:
		_set_status("[color=red]No .obj files found in folder.[/color]")
		if batch_thread and batch_thread.is_started():
			batch_thread.wait_to_finish()
		return

	# Write manifest JSON
	var manifest_path := folder.path_join("lofi_manifest.json")
	_write_json(manifest_path, {"results": batch_results})

	# Write manifest CSV
	var csv_path := folder.path_join("lofi_manifest.csv")
	var csv := FileAccess.open(csv_path, FileAccess.WRITE)
	if csv:
		csv.store_line("file,tris,tex_res,ssim,ok,glb")
		for r: Dictionary in batch_results:
			csv.store_line("%s,%d,%d,%.4f,%s,%s" % [
				r["file"], r["tris"], r["tex_res"], r["ssim"],
				"true" if r["ok"] else "false", r["glb"]
			])

	var done_count := batch_results.filter(func(r): return r["ok"]).size()
	_set_status("[color=green]Batch done: %d/%d  —  manifest saved.[/color]" \
		% [done_count, batch_results.size()])

	# Preview last successful GLB
	for r: Dictionary in batch_results:
		if r["ok"] and FileAccess.file_exists(r["glb"] as String):
			last_glb_path = r["glb"]
			export_btn.disabled = false
			_load_glb(r["glb"])

	if batch_thread and batch_thread.is_started():
		batch_thread.wait_to_finish()


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


# ─── Turntable & BG ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if turntable_btn.button_pressed and not _aabb_empty:
		orbit_yaw += speed_slider.value * delta
		_update_camera()


func _on_bg_color_changed(color: Color) -> void:
	if world_env and world_env.environment:
		world_env.environment.background_color = color


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
