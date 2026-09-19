extends Node3D

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var viewport3d:      SubViewport  = $SubViewport
@onready var crt_rect:        ColorRect    = $CanvasLayer/CRT
@onready var side_panel:      Panel        = $CanvasLayer/SidePanel
@onready var magnification_rect: TextureRect = $CanvasLayer/Magnification

const _VB := "CanvasLayer/SidePanel/Scroll/Margin/VBox"

# Phase 1 – Geometry
@onready var load_btn:       Button = $CanvasLayer/SidePanel/Scroll/Margin/VBox/LoadBtn
@onready var input_label:    Label  = $CanvasLayer/SidePanel/Scroll/Margin/VBox/InputLabel
@onready var load_tex_btn:   Button = $CanvasLayer/SidePanel/Scroll/Margin/VBox/LoadTexRow/LoadTexBtn
@onready var tex_label:      Label  = $CanvasLayer/SidePanel/Scroll/Margin/VBox/LoadTexRow/TexLabel
@onready var decimate_btn:   Button = $CanvasLayer/SidePanel/Scroll/Margin/VBox/DecimateBtn
@onready var poly_btns:   Array[Button] = []   # filled in _ready
@onready var geo_status:  RichTextLabel = $CanvasLayer/SidePanel/Scroll/Margin/VBox/GeoStatus
# Preview controls (geo phase)
@onready var tex_preview_btn:    CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PreviewRow/TexPreviewBtn
@onready var geo_wire_btn:       CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PreviewRow/GeoWireBtn
@onready var counter_toggle_btn: CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PreviewRow/CounterToggleBtn
@onready var poly_range_down:    Button      = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PolyRangeRow/PolyRangeDownBtn
@onready var poly_range_lbl:     Label       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PolyRangeRow/PolyRangeLbl
@onready var poly_range_up:      Button      = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PolyRangeRow/PolyRangeUpBtn
@onready var counter_label:      Label       = $CanvasLayer/CounterLabel

# Phase 2 – Texture
@onready var bake_btn:    Button        = $CanvasLayer/SidePanel/Scroll/Margin/VBox/BakeBtn
@onready var tex_btns:    Array[Button] = []
@onready var tex_range_down: Button     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/TexRangeRow/TexRangeDownBtn
@onready var tex_range_lbl:  Label      = $CanvasLayer/SidePanel/Scroll/Margin/VBox/TexRangeRow/TexRangeLbl
@onready var tex_range_up:   Button     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/TexRangeRow/TexRangeUpBtn
@onready var tex_status:  RichTextLabel = $CanvasLayer/SidePanel/Scroll/Margin/VBox/TexStatus
@onready var result_label: Label        = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ResultLabel
@onready var export_btn:        Button = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ExportBtn
@onready var export_baked_btn:  Button = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ExportBakedBtn
@onready var export_html_btn:   Button = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ExportHtmlBtn
@onready var export_3mf_btn:    Button = $CanvasLayer/SidePanel/Scroll/Margin/VBox/Export3MFBtn

# Render – PSX
@onready var pixelate_btn:    CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PixelateRow/PixelateBtn
@onready var pixelate_slider: HSlider     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PixelateRow/PixelateSlider
@onready var pixelate_val:    Label       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PixelateRow/PixelateVal
@onready var snap_btn:        CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PSXToggles1/SnapBtn
@onready var affine_btn:      CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PSXToggles1/AffineBtn
@onready var dither_btn:      CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PSXToggles2/DitherBtn
@onready var wireframe_btn:   CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/PSXToggles2/WireframeBtn

# Render – CRT
@onready var grain_btn:       CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/GrainRow/GrainBtn
@onready var grain_slider:    HSlider     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/GrainRow/GrainSlider
@onready var grain_val:       Label       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/GrainRow/GrainVal
@onready var chroma_btn:      CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ChromaRow/ChromaBtn
@onready var chroma_slider:   HSlider     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ChromaRow/ChromaSlider
@onready var chroma_val:      Label       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ChromaRow/ChromaVal
@onready var scanlines_btn:   CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ScanlinesRow/ScanlinesBtn
@onready var scanlines_slider:HSlider     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ScanlinesRow/ScanlinesSlider
@onready var scanlines_val:   Label       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/ScanlinesRow/ScanlinesVal
@onready var vignette_btn:    CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/VignetteRow/VignetteBtn
@onready var vignette_slider: HSlider     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/VignetteRow/VignetteSlider
@onready var vignette_val:    Label       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/VignetteRow/VignetteVal
@onready var warble_btn:      CheckButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/WarbleRow/WarbleBtn
@onready var warble_slider:   HSlider     = $CanvasLayer/SidePanel/Scroll/Margin/VBox/WarbleRow/WarbleSlider
@onready var warble_val:      Label       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/WarbleRow/WarbleVal

# Render – Scene
@onready var bg_color_btn:  ColorPickerButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/BGRow/BGColor
@onready var turntable_btn: CheckButton       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/TurntableRow/TurntableBtn
@onready var speed_slider:  HSlider           = $CanvasLayer/SidePanel/Scroll/Margin/VBox/TurntableRow/SpeedSlider
@onready var speed_val:     Label             = $CanvasLayer/SidePanel/Scroll/Margin/VBox/TurntableRow/SpeedVal

# Capture
@onready var snapshot_btn:    Button       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/CaptureRow/SnapshotBtn
@onready var record_btn:      Button       = $CanvasLayer/SidePanel/Scroll/Margin/VBox/CaptureRow/RecordBtn
@onready var fmt_option:      OptionButton = $CanvasLayer/SidePanel/Scroll/Margin/VBox/CaptureRow/FmtOption

# Dialogs
@onready var file_dialog:     FileDialog = $CanvasLayer/FileDialog
@onready var export_dialog:   FileDialog = $CanvasLayer/ExportDialog
@onready var video_dialog:    FileDialog = $CanvasLayer/VideoDialog
@onready var snapshot_dialog: FileDialog = $CanvasLayer/SnapshotDialog

# ─── 3D scene ────────────────────────────────────────────────────────────────
var cam:       Camera3D
var model_root:Node3D
var world_env: WorldEnvironment
var sun:       DirectionalLight3D
var _env:      Environment
var psx_shader:Shader
var crt_shader:Shader

# ─── Pipeline state ──────────────────────────────────────────────────────────
var selected_path:         String = ""
var selected_texture_path: String = ""
var last_glb_path:         String = ""
var repo_root:             String = ""

# 4 poly presets derived from search; index → tri count
var poly_presets:    Array[int]    = [0, 0, 0, 0]
var selected_poly:   int           = 0   # tri count chosen by user
var poly_selected:   bool          = false

# bake results: resolution (int) → glb path (String)
var bake_results:    Dictionary    = {}
var selected_tex_res:int           = 0

var pipeline_thread:       Thread
var bake_thread:           Thread
var preview_thread:        Thread
var _quick_preview_thread: Thread

# Progress polling while a thread runs
var _anim_base:    String        = ""
var _anim_target:  RichTextLabel = null
var _anim_on:      bool          = false
var _progress_file:String        = ""
var _poll_timer:   float         = 0.0
var _anim_step:    int           = 0

const PYTHON_BIN  := "/usr/bin/python3"
const BLENDER_BIN := "/Applications/Blender.app/Contents/MacOS/blender"

# Bump this when quick_preview.py or decimate_bake.py logic changes so
# old cached GLBs are ignored automatically (new dirs are created alongside old ones).
const CACHE_VER := "v4"

const ALL_TEX_RES  := [16, 32, 64, 128, 256, 512, 1024, 2048]
const POLY_FRACS   := [0.25, 0.5, 0.75, 1.0]

# Range state (adjusted with ↑/↓ buttons)
var poly_base_tris:   int   = 0    # best_tris from search
var poly_source_tris: int   = 0    # hi_res_tris from search log (source mesh after merge)
var poly_max_mult:    float = 1.0
var tex_res_start:    int   = 1    # index into ALL_TEX_RES; default gives 32/64/128/256

# Overlay counter
var current_tri_count: int = 0
var current_tex_res:   int = 0

# Batch poly preview cache (tri_count → glb path), populated after analysis
var _preview_cache:        Dictionary = {}
var _batch_preview_thread: Thread
# Pre-loaded texture scenes for instant switching (res → Node3D)
var _preloaded_tex_scenes: Dictionary = {}
var matcap_shader: Shader


const CRT_GRAIN     := 0.1
const CRT_CHROMA    := 0.005
const CRT_SCANLINES := 0.2
const CRT_VIGNETTE  := 0.5
const CRT_VIG_POWER := 2.0
const CRT_WARBLE    := 0.002

# Recording
const RECORD_FRAMES := 240
const RECORD_FPS    := 24
var recording:        bool   = false
var record_frame_idx: int    = 0
var record_dir:       String = ""
var record_format:    String = "mp4"

# ─── Orbit camera ────────────────────────────────────────────────────────────
var orbit_yaw:    float   = 30.0
var orbit_pitch:  float   = 20.0
var orbit_dist:   float   = 3.0
var orbit_center: Vector3 = Vector3.ZERO
var is_dragging:  bool    = false
var is_panning:   bool    = false
var _aspect_ratio: float  = 0.0   # 0 = free (match window)

# ─── Video / export ──────────────────────────────────────────────────────────
var _record_res:      Vector2i  = Vector2i(1920, 1080)
var _record_vp_size:  Vector2i  = Vector2i(0, 0)
var _baked_dialog:    FileDialog = null
var _html_dialog:     FileDialog = null
var _tex_dialog:      FileDialog = null
var _3mf_dialog:      FileDialog = null
var _3mf_palette:     int        = 0    # 0 = full, otherwise K-means target
var _3mf_subdivisions: int       = 0    # 0 = none, 1 = 4× tris, 2 = 16× tris
var _panel_visible:   bool    = true
var _capturing:       bool    = false
var _panel_w:        float   = 0.0   # computed on first _update_panel_size call
var _dragging_panel: bool    = false
var _panel_toggle_btn: Button = null
var _aabb_acc:   AABB = AABB()
var _aabb_empty: bool = true

# ─── Accordion ───────────────────────────────────────────────────────────────
var _acc_clips:   Array[Control]       = []
var _acc_content: Array[VBoxContainer] = []
var _acc_open:    Array[bool]          = [true, false, false, false, true]
var _acc_heights: Array[float]         = [0.0, 0.0, 0.0, 0.0, 0.0]
var _ACC_NAMES:   Array[String]        = ["SHAPE", "SURFACE", "LOOK", "MOTION", "EXPORT"]
var _look_master_btn: CheckButton      = null
var _look_enabled:    bool             = false

# ─── Per-preset quality scores ────────────────────────────────────────────────
var _poly_scores: Dictionary = {}  # tri_count(int) → display_str(String)


# ─── Ready ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	repo_root = ProjectSettings.globalize_path("res://").rstrip("/\\").get_base_dir()
	# Let mouse events pass through renderer nodes so scroll-zoom always reaches _input()
	magnification_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_rect.mouse_filter           = Control.MOUSE_FILTER_IGNORE
	_build_3d_scene()
	_load_shaders()
	_setup_crt()

	# Fill poly/tex button arrays
	var poly_row := get_node("CanvasLayer/SidePanel/Scroll/Margin/VBox/PolyRow")
	for i in 4:
		poly_btns.append(poly_row.get_child(i) as Button)
		poly_btns[i].pressed.connect(_on_poly_btn_pressed.bind(i))
		poly_btns[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		poly_btns[i].clip_text = true

	var tex_row := get_node("CanvasLayer/SidePanel/Scroll/Margin/VBox/TexRow")
	for i in 4:
		tex_btns.append(tex_row.get_child(i) as Button)
		tex_btns[i].pressed.connect(_on_tex_btn_pressed.bind(i))
		tex_btns[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex_btns[i].clip_text = true

	load_btn.pressed.connect(_on_load_pressed)
	load_tex_btn.pressed.connect(func(): _tex_dialog.popup_centered())
	decimate_btn.pressed.connect(_on_decimate_pressed)
	bake_btn.pressed.connect(_on_bake_pressed)
	export_btn.pressed.connect(_on_export_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	export_dialog.file_selected.connect(_on_export_path_selected)

	pixelate_btn.toggled.connect(_on_pixelate_toggled)
	pixelate_slider.value_changed.connect(func(v: float):
		pixelate_val.text = "%.2f" % v
		_on_pixelate_toggled(pixelate_btn.button_pressed))

	snap_btn.toggled.connect(func(v: bool): _set_all_shader_param("snap_vertices", v))
	affine_btn.toggled.connect(func(v: bool): _set_all_shader_param("use_affine_uv", v))
	dither_btn.toggled.connect(func(v: bool): _set_all_shader_param("use_dither", v))
	wireframe_btn.toggled.connect(_on_wireframe_toggled)
	geo_wire_btn.toggled.connect(_on_wireframe_toggled)

	tex_preview_btn.hide()   # clay matcap is always used in geo preview
	counter_toggle_btn.toggled.connect(func(v: bool): counter_label.visible = v)
	counter_toggle_btn.button_pressed = true   # show stats by default
	poly_range_up.pressed.connect(func(): _shift_poly_range(2.0))
	poly_range_down.pressed.connect(func(): _shift_poly_range(0.5))
	tex_range_up.pressed.connect(func(): _shift_tex_range(1))
	tex_range_down.pressed.connect(func(): _shift_tex_range(-1))
	_update_tex_btns()

	_wire_crt_row(grain_btn,    grain_slider,    grain_val,    "grain_intensity",      CRT_GRAIN)
	_wire_crt_row(chroma_btn,   chroma_slider,   chroma_val,   "chromatic_aberration", CRT_CHROMA)
	_wire_crt_row(scanlines_btn,scanlines_slider,scanlines_val,"scanline_intensity",   CRT_SCANLINES)
	_wire_crt_row(warble_btn,   warble_slider,   warble_val,   "warble_amount",        CRT_WARBLE)
	vignette_btn.toggled.connect(func(v: bool):
		vignette_slider.editable = v
		_set_slider_dim(vignette_val, v)
		_apply_vignette(v, vignette_slider.value))
	vignette_slider.value_changed.connect(func(v: float):
		vignette_val.text = "%.2f" % v
		_apply_vignette(vignette_btn.button_pressed, v))

	speed_slider.value_changed.connect(func(v: float): speed_val.text = "%d" % int(v))

	bg_color_btn.edit_alpha = false
	bg_color_btn.color_changed.connect(_on_bg_color_changed)
	snapshot_btn.pressed.connect(_on_snapshot_pressed)
	snapshot_dialog.file_selected.connect(_on_snapshot_path_selected)
	record_btn.pressed.connect(_on_record_pressed)
	video_dialog.file_selected.connect(_on_video_path_selected)

	# ── Video resolution picker (added after FmtOption in CaptureRow) ──────────
	var cap_row := record_btn.get_parent()
	var rec_res_opt := OptionButton.new()
	rec_res_opt.add_item("Match")
	rec_res_opt.add_item("720p")
	rec_res_opt.add_item("1080p")
	rec_res_opt.add_item("4K")
	rec_res_opt.select(2)
	rec_res_opt.add_theme_font_size_override("font_size", 11)
	rec_res_opt.item_selected.connect(func(idx: int):
		if   idx == 0: _record_res = Vector2i(0, 0)
		elif idx == 1: _record_res = Vector2i(1280, 720)
		elif idx == 2: _record_res = Vector2i(1920, 1080)
		else:          _record_res = Vector2i(3840, 2160))
	cap_row.add_child(rec_res_opt)

	# ── Baked GLB + HTML + 3MF export ───────────────────────────────────────────
	export_baked_btn.pressed.connect(_on_export_baked_pressed)
	export_html_btn.pressed.connect(_on_export_html_pressed)
	export_3mf_btn.pressed.connect(_on_export_3mf_pressed)

	var _cl := $CanvasLayer as CanvasLayer

	_baked_dialog = FileDialog.new()
	_baked_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_baked_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_baked_dialog.size = Vector2i(800, 550)
	_baked_dialog.add_filter("*.glb", "GLB 3D Model")
	_baked_dialog.file_selected.connect(_on_baked_path_selected)
	_cl.add_child(_baked_dialog)

	_html_dialog = FileDialog.new()
	_html_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_html_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_html_dialog.size = Vector2i(800, 550)
	_html_dialog.add_filter("*.html", "HTML Viewer")
	_html_dialog.file_selected.connect(_on_html_path_selected)
	_cl.add_child(_html_dialog)

	_tex_dialog = FileDialog.new()
	_tex_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_tex_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_tex_dialog.size = Vector2i(800, 550)
	_tex_dialog.add_filter("*.png", "PNG Image")
	_tex_dialog.add_filter("*.jpg", "JPEG Image")
	_tex_dialog.add_filter("*.jpeg", "JPEG Image")
	_tex_dialog.add_filter("*.tga", "TGA Image")
	_tex_dialog.file_selected.connect(_on_texture_file_selected)
	_cl.add_child(_tex_dialog)

	_3mf_dialog = FileDialog.new()
	_3mf_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_3mf_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_3mf_dialog.size = Vector2i(800, 550)
	_3mf_dialog.add_filter("*.3mf", "3MF Color Print")
	_3mf_dialog.file_selected.connect(_on_3mf_path_selected)
	_cl.add_child(_3mf_dialog)

	DisplayServer.window_set_drop_files_callback(_on_files_dropped)

	_apply_panel_theme()
	_build_accordion()
	_build_scene_controls()
	_build_3mf_palette_row()
	# Reset all LOOK effect buttons to off before wiring signals
	for _look_btn: CheckButton in [pixelate_btn, snap_btn, affine_btn, dither_btn,
			grain_btn, chroma_btn, scanlines_btn, vignette_btn, warble_btn]:
		_look_btn.set_block_signals(true)
		_look_btn.button_pressed = false
		_look_btn.set_block_signals(false)
	# Wire look master toggle AFTER accordion build to prevent init signal fire
	if is_instance_valid(_look_master_btn):
		_look_master_btn.toggled.connect(_on_look_master_toggled)
	_on_look_master_toggled(false)  # enforce off state on startup

	_build_panel_controls()
	_update_panel_size()
	get_viewport().size_changed.connect(func(): _update_panel_size())
	_try_autoload_latest_glb()


# ─── CRT helpers ─────────────────────────────────────────────────────────────

func _wire_crt_row(btn: CheckButton, slider: HSlider, lbl: Label,
		param: String, max_val: float) -> void:
	btn.toggled.connect(func(v: bool):
		slider.editable = v
		_set_slider_dim(lbl, v)
		_apply_crt_param(param, max_val, slider.value, v))
	slider.value_changed.connect(func(v: float):
		lbl.text = "%.2f" % v
		_apply_crt_param(param, max_val, v, btn.button_pressed))


func _set_slider_dim(lbl: Label, enabled: bool) -> void:
	lbl.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.35)


func _apply_crt_param(param: String, max_val: float, t: float, on: bool) -> void:
	if crt_rect.material is ShaderMaterial:
		(crt_rect.material as ShaderMaterial).set_shader_parameter(param, t * max_val if on else 0.0)
	_refresh_crt_visibility()


func _apply_vignette(on: bool, t: float) -> void:
	if crt_rect.material is ShaderMaterial:
		var mat := crt_rect.material as ShaderMaterial
		mat.set_shader_parameter("vignette_darkness",  t * CRT_VIGNETTE  if on else 0.0)
		mat.set_shader_parameter("crt_vignette_power", t * CRT_VIG_POWER if on else 0.0)
	_refresh_crt_visibility()


func _refresh_crt_visibility() -> void:
	crt_rect.visible = _look_enabled and (grain_btn.button_pressed or chroma_btn.button_pressed \
		or scanlines_btn.button_pressed or vignette_btn.button_pressed \
		or warble_btn.button_pressed)


func _on_look_master_toggled(on: bool) -> void:
	_look_enabled = on
	# Disable/enable all effect buttons so they can't be toggled when LOOK is off
	for _lb: CheckButton in [pixelate_btn, snap_btn, affine_btn, dither_btn,
			grain_btn, chroma_btn, scanlines_btn, vignette_btn, warble_btn]:
		_lb.disabled = not on
	if on:
		# Restore each effect to its current button state
		_on_pixelate_toggled(pixelate_btn.button_pressed)
		_set_all_shader_param("snap_vertices", snap_btn.button_pressed)
		_set_all_shader_param("use_affine_uv",  affine_btn.button_pressed)
		_set_all_shader_param("use_dither",     dither_btn.button_pressed)
		_apply_crt_param("grain_intensity",      CRT_GRAIN,     grain_slider.value,     grain_btn.button_pressed)
		_apply_crt_param("chromatic_aberration", CRT_CHROMA,    chroma_slider.value,    chroma_btn.button_pressed)
		_apply_crt_param("scanline_intensity",   CRT_SCANLINES, scanlines_slider.value, scanlines_btn.button_pressed)
		_apply_crt_param("warble_amount",        CRT_WARBLE,    warble_slider.value,    warble_btn.button_pressed)
		_apply_vignette(vignette_btn.button_pressed, vignette_slider.value)
	else:
		# Silence all effects without changing button states (settings preserved)
		_on_pixelate_toggled(false)
		_set_all_shader_param("snap_vertices", false)
		_set_all_shader_param("use_affine_uv",  false)
		_set_all_shader_param("use_dither",     false)
		_apply_crt_param("grain_intensity",      CRT_GRAIN,     0.0, false)
		_apply_crt_param("chromatic_aberration", CRT_CHROMA,    0.0, false)
		_apply_crt_param("scanline_intensity",   CRT_SCANLINES, 0.0, false)
		_apply_crt_param("warble_amount",        CRT_WARBLE,    0.0, false)
		_apply_vignette(false, 0.0)
		crt_rect.visible = false


# ─── 3D scene ────────────────────────────────────────────────────────────────

func _build_3d_scene() -> void:
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 45.0
	cam.near = 0.05
	viewport3d.add_child(cam)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	sun.light_energy = 2.0
	sun.light_color = Color(0.81, 0.81, 0.81)
	viewport3d.add_child(sun)

	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.118, 0.118, 0.118)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1, 1, 1)
	_env.ambient_light_energy = 0.2
	world_env = WorldEnvironment.new()
	world_env.environment = _env
	viewport3d.add_child(world_env)

	model_root = Node3D.new()
	viewport3d.add_child(model_root)

	_update_camera()


func _make_slider_row(label_text: String, min_v: float, max_v: float,
		def_v: float, step: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.value     = def_v
	sl.step      = step
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % def_v
	val_lbl.custom_minimum_size = Vector2(34, 0)
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)
	sl.value_changed.connect(func(v: float):
		val_lbl.text = "%.2f" % v
		cb.call(v))
	return row


func _make_section_header(title: String, content: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.22, 0.22))
	content.add_child(sep)
	var hdr := Label.new()
	hdr.text = title
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", Color(0.46, 0.46, 0.46))
	content.add_child(hdr)


func _build_scene_controls() -> void:
	if _acc_content.size() < 3:
		return
	var look := _acc_content[2]

	_make_section_header("FRAME", look)
	# ── Aspect ratio presets ──────────────────────────────────────────────────
	const ASPECT_PRESETS: Array = [
		["Free",   0.0],
		["1:1",    1.0],
		["4:3",    4.0/3.0],
		["16:9",   16.0/9.0],
		["16:10",  16.0/10.0],
		["1.85",   1.85],
		["2.39",   2.39],
		["9:16",   9.0/16.0],
		["Custom", -1.0],
	]
	var aspect_row := HBoxContainer.new()
	aspect_row.add_theme_constant_override("separation", 3)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 11)
	for p: Array in ASPECT_PRESETS:
		opt.add_item(p[0] as String)
	look.add_child(aspect_row)
	aspect_row.add_child(opt)

	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 4)
	custom_row.visible = false
	var cw_spin := SpinBox.new()
	cw_spin.min_value = 1; cw_spin.max_value = 999; cw_spin.value = 21
	cw_spin.suffix = "W"; cw_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cw_spin.add_theme_font_size_override("font_size", 11)
	var colon_lbl := Label.new()
	colon_lbl.text = ":"
	colon_lbl.add_theme_font_size_override("font_size", 11)
	var ch_spin := SpinBox.new()
	ch_spin.min_value = 1; ch_spin.max_value = 999; ch_spin.value = 9
	ch_spin.suffix = "H"; ch_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_spin.add_theme_font_size_override("font_size", 11)
	custom_row.add_child(cw_spin)
	custom_row.add_child(colon_lbl)
	custom_row.add_child(ch_spin)
	look.add_child(custom_row)

	var apply_custom := func():
		_apply_aspect_ratio(cw_spin.value / ch_spin.value)
	cw_spin.value_changed.connect(func(_v: float): apply_custom.call())
	ch_spin.value_changed.connect(func(_v: float): apply_custom.call())

	opt.item_selected.connect(func(idx: int):
		var ratio: float = ASPECT_PRESETS[idx][1] as float
		if ratio < 0.0:
			custom_row.visible = true
			apply_custom.call()
		else:
			custom_row.visible = false
			_apply_aspect_ratio(ratio)
		_init_acc_heights.call_deferred())

	_make_section_header("LIGHT", look)
	look.add_child(_make_slider_row("Intensity", 0.0, 5.0, 2.0, 0.05,
		func(v: float): if sun: sun.light_energy = v))
	look.add_child(_make_slider_row("Pitch", -90.0, 0.0, -45.0, 1.0,
		func(v: float): if sun: sun.rotation_degrees.x = v))
	look.add_child(_make_slider_row("Yaw", -180.0, 180.0, 45.0, 1.0,
		func(v: float): if sun: sun.rotation_degrees.y = v))
	look.add_child(_make_slider_row("Ambient", 0.0, 1.0, 0.2, 0.01,
		func(v: float): if _env: _env.ambient_light_energy = v))

	_make_section_header("EXPOSURE", look)
	look.add_child(_make_slider_row("Exposure",   0.5, 3.0, 1.0, 0.01,
		func(v: float): _set_all_shader_param("exposure",   v)))
	look.add_child(_make_slider_row("Brightness", 0.1, 2.0, 1.0, 0.01,
		func(v: float): _set_all_shader_param("brightness", v)))
	look.add_child(_make_slider_row("Contrast",   0.1, 2.0, 1.0, 0.01,
		func(v: float): _set_all_shader_param("contrast",   v)))

	_init_acc_heights.call_deferred()


func _load_shaders() -> void:
	var p := "res://shaders/psx_shader.gdshader"
	if ResourceLoader.exists(p):
		psx_shader = load(p)
	var c := "res://shaders/magnification.gdshader"
	if ResourceLoader.exists(c):
		crt_shader = load(c)
	var m := "res://shaders/preview_matcap.gdshader"
	if ResourceLoader.exists(m):
		matcap_shader = load(m)


func _setup_crt() -> void:
	if crt_shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = crt_shader
	mat.set_shader_parameter("grain_intensity",      0.0)
	mat.set_shader_parameter("chromatic_aberration", 0.0)
	mat.set_shader_parameter("warble_amount",        0.0)
	mat.set_shader_parameter("warble_speed",         5.0)
	mat.set_shader_parameter("scanline_intensity",   0.0)
	mat.set_shader_parameter("vignette_darkness",    0.0)
	mat.set_shader_parameter("crt_vignette_power",   0.0)
	crt_rect.material = mat
	crt_rect.visible = false


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
		_set_geo_status("[color=gray]Auto-loaded: %s[/color]" % newest_glb.get_file())


# ─── Phase 1: GEOMETRY ───────────────────────────────────────────────────────

func _on_load_pressed() -> void:
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
	_reset_poly_phase()
	_reset_tex_phase()

	if path.get_extension().to_lower() in ["glb", "gltf"]:
		# Show GLB immediately with its original textures via PSX shader.
		last_glb_path = path
		_load_glb(path)
		_set_geo_status("[color=gray]Hit Decimate to process, or skip to Bake.[/color]")
		load_tex_btn.disabled = false
		decimate_btn.disabled = false
	else:
		# OBJ/PLY: run quick preview so the model appears while user decides.
		# Analysis (Decimate) is still manual.
		load_btn.disabled = true
		load_tex_btn.disabled = false
		_set_geo_status("[color=gray]Loading preview…[/color]")
		_quick_preview_thread = Thread.new()
		_quick_preview_thread.start(_run_quick_preview.bind(path))


func _on_texture_file_selected(path: String) -> void:
	selected_texture_path = path
	tex_label.text = path.get_file()
	# Load and apply texture to whatever is currently in the viewport
	var img := Image.load_from_file(path)
	if img == null:
		_set_geo_status("[color=red]Failed to load texture.[/color]")
		return
	var tex := ImageTexture.create_from_image(img)
	_apply_texture_override(model_root, tex)
	_set_geo_status("[color=green]Texture loaded: %s[/color]" % path.get_file())


func _apply_texture_override(node: Node, tex: ImageTexture) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var sm := ShaderMaterial.new()
			sm.shader = psx_shader
			sm.set_shader_parameter("albedo_map", tex)
			sm.set_shader_parameter("snap_vertices", snap_btn.button_pressed and _look_enabled)
			sm.set_shader_parameter("use_affine_uv",  affine_btn.button_pressed and _look_enabled)
			sm.set_shader_parameter("use_dither",     dither_btn.button_pressed and _look_enabled)
			mi.set_surface_override_material(i, sm)
	for c in node.get_children():
		_apply_texture_override(c, tex)


func _on_decimate_pressed() -> void:
	if selected_path.is_empty():
		return
	_reset_poly_phase()
	decimate_btn.disabled = true
	load_btn.disabled = true
	var _pf := repo_root.path_join("cache/_progress.json")
	_set_geo_status("Analysing mesh…", _pf)
	_quick_preview_thread = Thread.new()
	_quick_preview_thread.start(_run_quick_preview.bind(selected_path))
	pipeline_thread = Thread.new()
	pipeline_thread.start(_run_analysis.bind(selected_path))


func _run_quick_preview(mesh_path: String) -> void:
	var stem := mesh_path.get_file().get_basename()
	var cache := repo_root.path_join("cache")
	var preview_out := cache.path_join(stem + "_hipreview_" + CACHE_VER)
	var preview_glb := preview_out.path_join("mesh_lo.glb")
	# Reuse if cached GLB is newer than the source mesh
	if FileAccess.file_exists(preview_glb) and \
			FileAccess.get_modified_time(preview_glb) > FileAccess.get_modified_time(mesh_path):
		_finish_quick_preview.call_deferred(preview_glb)
		return
	DirAccess.make_dir_recursive_absolute(preview_out)
	var cfg := {
		"input_mesh":        mesh_path,
		"input_texture":     selected_texture_path if selected_texture_path != "" else null,
		"target_tri_count":  0,
		"output_dir":        preview_out,
		"merge_distance":    0.0,
	}
	_write_json(cache.path_join("_godot_hipreview.json"), cfg)
	var _out := []
	OS.execute(BLENDER_BIN,
		["--background", "--python",
		 repo_root.path_join("blender_scripts/quick_preview.py"),
		 "--", cache.path_join("_godot_hipreview.json")], _out, true)
	if FileAccess.file_exists(preview_glb):
		_finish_quick_preview.call_deferred(preview_glb)


func _finish_quick_preview(glb_path: String) -> void:
	if _quick_preview_thread and _quick_preview_thread.is_started():
		_quick_preview_thread.wait_to_finish()
	# Don't overwrite if the user already picked a poly level
	if poly_selected:
		return
	_load_preview_glb(glb_path, true)
	load_btn.disabled = false
	# Only enable Decimate if analysis isn't already running
	if not (pipeline_thread and pipeline_thread.is_started()):
		decimate_btn.disabled = false
		_set_geo_status("[color=gray]Hit Decimate to analyse and decimate.[/color]")


func _run_analysis(mesh_path: String) -> void:
	var stem := mesh_path.get_file().get_basename()
	var cache := repo_root.path_join("cache")
	DirAccess.make_dir_recursive_absolute(cache)
	var search_out := cache.path_join(stem + "_search")
	var log_path   := search_out.path_join("search_log.json")

	# Skip analysis if a fresh cached result exists for this mesh
	if FileAccess.file_exists(log_path) and \
			FileAccess.get_modified_time(log_path) > FileAccess.get_modified_time(mesh_path):
		var geo_log     := _read_json(log_path)
		var best_tris   := int(geo_log.get("best_tris", 400))
		var hi_res_tris := int(geo_log.get("hi_res_tris", 0))
		_finish_analysis.call_deferred(true, best_tris, hi_res_tris)
		return

	var search_cfg := {
		"input_mesh": mesh_path, "tier": 2,
		"output_dir": search_out,
		"search_lo": 200, "search_hi": 8000, "max_iter": 14,
		"render_resolution": 256, "bake_resolution": 512,
		"merge_distance": 0.0, "blender_bin": BLENDER_BIN,
		"camera_distance": 2.5,
		"input_texture": selected_texture_path if selected_texture_path != "" else null,
		"progress_file": repo_root.path_join("cache/_progress.json"),
	}
	_write_json(cache.path_join("_godot_search.json"), search_cfg)

	var out := []
	var code := OS.execute(PYTHON_BIN,
		[repo_root.path_join("blender_scripts/search.py"),
		 cache.path_join("_godot_search.json")], out, true)

	if code != 0:
		_finish_analysis.call_deferred(false, 0)
		return

	var geo_log      := _read_json(search_out.path_join("search_log.json"))
	var best_tris    := int(geo_log.get("best_tris", 400))
	var hi_res_tris  := int(geo_log.get("hi_res_tris", 0))
	_finish_analysis.call_deferred(true, best_tris, hi_res_tris)


func _finish_analysis(ok: bool, best_tris: int, hi_res_tris: int = 0) -> void:
	load_btn.disabled = false
	decimate_btn.disabled = false
	if pipeline_thread and pipeline_thread.is_started():
		pipeline_thread.wait_to_finish()

	if not ok:
		_set_geo_status("[color=red]Analysis failed — see Godot output.[/color]")
		return

	poly_base_tris   = best_tris
	poly_source_tris = hi_res_tris
	poly_max_mult    = 1.0
	_update_poly_presets()
	for b: Button in poly_btns:
		b.disabled = false
	poly_range_up.disabled   = false
	poly_range_down.disabled = false
	_set_geo_status("[color=green]Found %d tris. Pick a polygon level.[/color]" % best_tris)
	# Pre-bake all 4 preview GLBs in the background for instant switching
	_preview_cache.clear()
	if _batch_preview_thread and _batch_preview_thread.is_started():
		_batch_preview_thread.wait_to_finish()
	_batch_preview_thread = Thread.new()
	_batch_preview_thread.start(_run_batch_previews.bind(selected_path, selected_texture_path, poly_presets.duplicate()))


func _on_poly_btn_pressed(idx: int) -> void:
	selected_poly = poly_presets[idx]
	poly_selected = true
	bake_btn.disabled = true
	_reset_tex_phase()
	var _old_children := model_root.get_children()
	for c in _old_children:
		model_root.remove_child(c)
		c.queue_free()

	if _preview_cache.has(selected_poly):
		# Instant: batch preview already baked this one
		poly_btns[idx].button_pressed = true
		bake_btn.disabled = false
		_load_preview_glb(_preview_cache[selected_poly])
		_set_geo_status("[color=white]Preview: %d tris — pick another or Bake Texture.[/color]" % selected_poly)
		return

	# Also check disk with freshness validation (handles post-range-change scenario)
	if selected_path != "":
		var stem := selected_path.get_file().get_basename()
		var disk_glb := repo_root.path_join("cache").path_join(
			"_preview_%s_%d_%s" % [stem, selected_poly, CACHE_VER]).path_join("mesh_lo.glb")
		if _preview_glb_is_fresh(disk_glb):
			_preview_cache[selected_poly] = disk_glb
			poly_btns[idx].button_pressed = true
			bake_btn.disabled = false
			_load_preview_glb(disk_glb)
			_set_geo_status("[color=white]Preview: %d tris — pick another or Bake Texture.[/color]" % selected_poly)
			return

	var _ppf := repo_root.path_join("cache/_progress.json")
	_set_geo_status("Loading %d tri preview…" % selected_poly, _ppf)
	if preview_thread and preview_thread.is_started():
		preview_thread.wait_to_finish()
	preview_thread = Thread.new()
	preview_thread.start(_run_poly_preview.bind(selected_path, selected_poly, idx))


func _run_poly_preview(mesh_path: String, tri_count: int, btn_idx: int) -> void:
	var stem := mesh_path.get_file().get_basename()
	var cache := repo_root.path_join("cache")
	var preview_out := cache.path_join("_preview_%s_%d_%s" % [stem, tri_count, CACHE_VER])
	var glb := preview_out.path_join("mesh_lo.glb")

	# If batch thread already wrote a fresh GLB while we were waiting, reuse it.
	# This prevents two Blender processes writing to the same file concurrently.
	var fresh := FileAccess.file_exists(glb) and \
		FileAccess.get_modified_time(glb) > FileAccess.get_modified_time(mesh_path)

	if not fresh:
		var cfg := {
			"input_mesh":        mesh_path,
			"input_texture":     selected_texture_path if selected_texture_path != "" else null,
			"target_tri_count":  tri_count,
			"output_dir":        preview_out,
			"merge_distance":    0.0,
			"progress_file":     repo_root.path_join("cache/_progress.json"),
		}
		_write_json(cache.path_join("_godot_preview.json"), cfg)

		var out := []
		var code := OS.execute(BLENDER_BIN, [
			"--background", "--python",
			repo_root.path_join("blender_scripts/quick_preview.py"),
			"--", cache.path_join("_godot_preview.json"),
		], out, true)
		fresh = (code == 0 and FileAccess.file_exists(glb))

	_finish_poly_preview.call_deferred(fresh, glb, btn_idx)


func _run_batch_previews(mesh_path: String, tex_path: String, presets: Array[int]) -> void:
	var cache := repo_root.path_join("cache")
	var stem  := mesh_path.get_file().get_basename()
	for tri in presets:
		if tri <= 0:
			continue
		var preview_out := cache.path_join("_preview_%s_%d_%s" % [stem, tri, CACHE_VER])
		var glb         := preview_out.path_join("mesh_lo.glb")
		if FileAccess.file_exists(glb):
			var mesh_mt := FileAccess.get_modified_time(mesh_path)
			var glb_mt  := FileAccess.get_modified_time(glb)
			if glb_mt > mesh_mt:
				_preview_cache_set.call_deferred(tri, glb)
				continue
		var cfg := {
			"input_mesh":        mesh_path,
			"input_texture":     tex_path if tex_path != "" else null,
			"target_tri_count":  tri,
			"output_dir":        preview_out,
			"merge_distance":    0.0,
		}
		_write_json(cache.path_join("_batch_preview_%d.json" % tri), cfg)
		var _out := []
		var code := OS.execute(BLENDER_BIN, [
			"--background", "--python",
			repo_root.path_join("blender_scripts/quick_preview.py"),
			"--", cache.path_join("_batch_preview_%d.json" % tri),
		], _out, true)
		if code == 0 and FileAccess.file_exists(glb):
			_preview_cache_set.call_deferred(tri, glb)


func _preview_cache_set(tri: int, glb: String) -> void:
	_preview_cache[tri] = glb
	# Read Hausdorff score written by quick_preview.py alongside the GLB
	var scores_path := glb.get_base_dir().path_join("scores.json")
	if FileAccess.file_exists(scores_path):
		var sc := _read_json(scores_path)
		var h := float(sc.get("hausdorff_normalized", -1.0))
		if h >= 0.0:
			_poly_scores[tri] = "dev %.1f%%" % (h * 100.0)
			call_deferred("_update_poly_presets")
	# Note: do NOT early-load here — the manual preview thread may still be writing
	# the same GLB file. _finish_poly_preview handles the load when the thread completes.


func _finish_poly_preview(ok: bool, glb: String, btn_idx: int) -> void:
	if preview_thread and preview_thread.is_started():
		preview_thread.wait_to_finish()
	# Re-enable poly buttons
	for i in 4:
		poly_btns[i].disabled = poly_presets[i] == 0

	# Always cache — even if selection changed while we were loading
	if ok:
		_preview_cache[poly_presets[btn_idx]] = glb

	if poly_presets[btn_idx] == selected_poly:
		poly_btns[btn_idx].button_pressed = true
		bake_btn.disabled = false
		if ok:
			_load_preview_glb(glb)
			_set_geo_status("[color=white]Preview: %d tris — pick another or Bake Texture.[/color]" % selected_poly)
		else:
			_set_geo_status("[color=yellow]%d tris selected (preview failed).[/color]" % selected_poly)


func _reset_poly_phase() -> void:
	poly_selected = false
	selected_poly = 0
	_preview_cache.clear()
	_poly_scores.clear()
	bake_btn.disabled = true
	decimate_btn.disabled = true
	load_tex_btn.disabled = true
	tex_label.text = ""
	for i in 4:
		poly_btns[i].disabled = true
		poly_btns[i].text = "—"
	_set_geo_status("[color=gray]Load a mesh to begin.[/color]")


# ─── Phase 2: TEXTURE ────────────────────────────────────────────────────────

func _on_bake_pressed() -> void:
	if not poly_selected:
		return
	bake_btn.disabled = true
	_reset_tex_phase()
	var _bpf := repo_root.path_join("cache/_progress.json")
	_set_tex_status("Baking %d tris" % selected_poly, _bpf)
	bake_thread = Thread.new()
	bake_thread.start(_run_bake.bind(selected_path, selected_poly))


func _run_bake(mesh_path: String, tri_count: int) -> void:
	var stem := mesh_path.get_file().get_basename()
	var cache := repo_root.path_join("cache")
	var tex_out := cache.path_join(stem + "_tex_%d" % tri_count)

	# Bake ALL resolutions so user can freely shift the tex range after baking.
	# lo_res_mesh is always null: the preview GLB may be voxel-remeshed (fills holes),
	# which breaks the hi→lo bake projection. Let decimate_bake derive lo_res fresh.
	var active_res := ALL_TEX_RES
	var tex_cfg := {
		"input_mesh": mesh_path,
		"fixed_tri_count": tri_count,
		"lo_res_mesh": null,
		"target_score": 2.0,
		"output_dir": tex_out,
		"resolutions": active_res,
		"render_resolution": 256,
		"cycles_samples": 8,
		"merge_distance": 0.0,
		"blender_bin": BLENDER_BIN,
		"camera_distance": 2.5,
		"input_texture": selected_texture_path if selected_texture_path != "" else null,
		"progress_file": repo_root.path_join("cache/_progress.json"),
	}
	_write_json(cache.path_join("_godot_tex.json"), tex_cfg)

	var out := []
	var code := OS.execute(PYTHON_BIN,
		[repo_root.path_join("blender_scripts/texture_sweep.py"),
		 cache.path_join("_godot_tex.json")], out, true)

	if code != 0:
		push_error("[bake] exit %d\n%s" % [code, "\n".join(out)])
		_finish_bake.call_deferred(false, {})
		return

	# Collect from _scratch_tex/bake_{res}px/ — all resolutions were baked
	var results: Dictionary = {}
	var scratch := tex_out.path_join("_scratch_tex")
	for res: int in active_res:
		var glb := scratch.path_join("bake_%dpx" % res).path_join("mesh_lo.glb")
		if FileAccess.file_exists(glb):
			results[res] = glb

	_finish_bake.call_deferred(results.size() > 0, results)


func _finish_bake(ok: bool, results: Dictionary) -> void:
	bake_btn.disabled = false
	if bake_thread and bake_thread.is_started():
		bake_thread.wait_to_finish()

	if not ok or results.is_empty():
		_set_tex_status("[color=red]Bake failed — see Godot output.[/color]")
		return

	bake_results = results
	_set_tex_status("[color=green]Baked. Pick a texture size.[/color]")

	# Preload all GLBs into the scene tree (hidden) for instant switching (Issue 6)
	_preloaded_tex_scenes.clear()
	for c in model_root.get_children():
		c.queue_free()
	for res in results:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(results[res], state) == OK:
			var s := doc.generate_scene(state)
			s.visible = false
			model_root.add_child(s)
			_preloaded_tex_scenes[res] = s
			if psx_shader:
				_apply_psx(s)

	var res_list := _get_tex_resolutions()
	for i in 4:
		tex_btns[i].disabled = not results.has(res_list[i])

	# Auto-select the highest available resolution
	for i in range(3, -1, -1):
		if results.has(res_list[i]):
			tex_btns[i].button_pressed = true
			_on_tex_btn_pressed(i)
			break

	tex_range_up.disabled   = false
	tex_range_down.disabled = false


func _on_tex_btn_pressed(idx: int) -> void:
	var res: int = _get_tex_resolutions()[idx]
	if not bake_results.has(res):
		return
	selected_tex_res = res
	last_glb_path = bake_results[res]
	_set_export_enabled(true)
	result_label.text = "%d tris  ·  %dpx tex" % [selected_poly, res]
	current_tri_count = selected_poly
	current_tex_res   = res
	_update_counter()
	_set_tex_status("[color=white]%dpx selected.[/color]" % res)
	if _preloaded_tex_scenes.has(res):
		_show_tex_scene(res)
	else:
		_load_glb(last_glb_path)


func _show_tex_scene(res: int) -> void:
	for child in model_root.get_children():
		child.visible = false
	if _preloaded_tex_scenes.has(res):
		_preloaded_tex_scenes[res].visible = true
	# Entering texture phase — turn off geo wireframe, restore render wireframe
	if geo_wire_btn.button_pressed:
		geo_wire_btn.button_pressed = false
	_on_pixelate_toggled(pixelate_btn.button_pressed and _look_enabled)
	_frame_model.call_deferred()
	if wireframe_btn.button_pressed:
		call_deferred("_on_wireframe_toggled", true)
	_update_counter()


func _reset_tex_phase() -> void:
	bake_results = {}
	selected_tex_res = 0
	# Free preloaded scenes from the tree before clearing the dictionary
	for s in _preloaded_tex_scenes.values():
		if is_instance_valid(s) and s.get_parent() == model_root:
			model_root.remove_child(s)
			s.queue_free()
	_preloaded_tex_scenes.clear()
	_set_export_enabled(false)
	for i in 4:
		tex_btns[i].disabled = true
		tex_btns[i].button_pressed = false
	_set_tex_status("")


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
		_set_tex_status("[color=red]Export failed.[/color]")
		return
	dst.store_buffer(src.get_buffer(src.get_length()))
	_set_tex_status("[color=green]Exported: %s[/color]" % dest.get_file())


# ─── Export helpers ───────────────────────────────────────────────────────────

func _set_export_enabled(v: bool) -> void:
	export_btn.disabled       = not v
	export_baked_btn.disabled = not v
	export_html_btn.disabled  = not v
	export_3mf_btn.disabled   = not v


func _collect_shader_params() -> Dictionary:
	var p := {
		"exposure": 1.0, "brightness": 1.0, "contrast": 1.0,
		"use_dither": true, "dither_gamma": 1.0, "snap_vertices": true,
		"sun_intensity": 2.0, "sun_pitch": -45.0, "sun_yaw": 45.0, "ambient": 0.2,
		"grain_intensity": 0.0, "chroma": 0.0, "scanlines": 0.0,
		"vignette_darkness": 0.0, "crt_vignette_power": 0.0,
		"warble_amount": 0.0, "warble_speed": 5.0,
		"bg_color": [0.102, 0.102, 0.102],
		"pixelate": false, "pixelate_scale": 0.15,
	}
	for c in model_root.get_children():
		if c is MeshInstance3D:
			var mat: Material = (c as MeshInstance3D).get_active_material(0)
			if mat is ShaderMaterial:
				var sm := mat as ShaderMaterial
				for key: String in ["exposure", "brightness", "contrast",
						"use_dither", "dither_gamma", "snap_vertices"]:
					var v: Variant = sm.get_shader_parameter(key)
					if v != null:
						p[key] = v
			break
	if sun:
		p["sun_intensity"] = sun.light_energy
		p["sun_pitch"]     = sun.rotation_degrees.x
		p["sun_yaw"]       = sun.rotation_degrees.y
	if _env:
		p["ambient"] = _env.ambient_light_energy
		var bc := _env.background_color
		p["bg_color"] = [bc.r, bc.g, bc.b]
	if is_instance_valid(pixelate_btn):
		p["pixelate"]       = pixelate_btn.button_pressed and _look_enabled
		p["pixelate_scale"] = pixelate_slider.value
	if crt_rect.material is ShaderMaterial:
		var cm := crt_rect.material as ShaderMaterial
		var _gi: Variant = cm.get_shader_parameter("grain_intensity")
		if _gi != null: p["grain_intensity"] = float(_gi)
		var _ca: Variant = cm.get_shader_parameter("chromatic_aberration")
		if _ca != null: p["chroma"] = float(_ca)
		var _si: Variant = cm.get_shader_parameter("scanline_intensity")
		if _si != null: p["scanlines"] = float(_si)
		var _vd: Variant = cm.get_shader_parameter("vignette_darkness")
		if _vd != null: p["vignette_darkness"] = float(_vd)
		var _vp: Variant = cm.get_shader_parameter("crt_vignette_power")
		if _vp != null: p["crt_vignette_power"] = float(_vp)
		var _wa: Variant = cm.get_shader_parameter("warble_amount")
		if _wa != null: p["warble_amount"] = float(_wa)
		var _ws: Variant = cm.get_shader_parameter("warble_speed")
		if _ws != null: p["warble_speed"] = float(_ws)
	return p


func _on_export_baked_pressed() -> void:
	if last_glb_path.is_empty():
		return
	var stem := selected_path.get_file().get_basename() if selected_path != "" else "export"
	_baked_dialog.current_file = stem + "_baked.glb"
	_baked_dialog.popup_centered()


func _on_baked_path_selected(dest: String) -> void:
	if not dest.ends_with(".glb"):
		dest += ".glb"
	var params := _collect_shader_params()
	params["input_glb"]  = last_glb_path
	params["output_glb"] = dest
	var cfg := OS.get_temp_dir().path_join("lofi_bake_looks.json")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string(JSON.stringify(params))
	f.close()
	_set_tex_status("[color=cyan]Baking looks…[/color]")
	var out: Array = []
	var code := OS.execute(PYTHON_BIN,
		[repo_root.path_join("blender_scripts/bake_looks.py"), cfg], out, true)
	if code == 0:
		_set_tex_status("[color=green]Baked GLB: %s[/color]" % dest.get_file())
	else:
		push_error("[bake_looks] %s" % "\n".join(out))
		_set_tex_status("[color=red]Bake looks failed.[/color]")


func _on_export_html_pressed() -> void:
	if last_glb_path.is_empty():
		return
	var stem := selected_path.get_file().get_basename() if selected_path != "" else "export"
	_html_dialog.current_file = stem + "_viewer.html"
	_html_dialog.popup_centered()


func _on_html_path_selected(dest: String) -> void:
	if not dest.ends_with(".html"):
		dest += ".html"
	var params := _collect_shader_params()
	# Use whatever GLB the user currently has loaded (their chosen resolution).
	# gen_html.py will bilinear-upscale the texture to min 2K for sharp display.
	params["input_glb"]   = last_glb_path
	params["min_texture_size"] = 2048
	params["output_html"] = dest
	params["model_name"]  = selected_path.get_file().get_basename() \
		if selected_path != "" else "lofi-scan model"
	var cfg := OS.get_temp_dir().path_join("lofi_gen_html.json")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string(JSON.stringify(params))
	f.close()
	_set_tex_status("[color=cyan]Generating HTML…[/color]")
	var out: Array = []
	var code := OS.execute(PYTHON_BIN,
		[repo_root.path_join("blender_scripts/gen_html.py"), cfg], out, true)
	if code == 0:
		_set_tex_status("[color=green]HTML: %s[/color]" % dest.get_file())
	else:
		push_error("[gen_html] %s" % "\n".join(out))
		_set_tex_status("[color=red]HTML export failed.[/color]")


func _on_export_3mf_pressed() -> void:
	if last_glb_path.is_empty():
		return
	var stem := selected_path.get_file().get_basename() if selected_path != "" else "export"
	_3mf_dialog.current_file = stem + "_lofi.3mf"
	_3mf_dialog.popup_centered()


func _on_3mf_path_selected(dest: String) -> void:
	if not dest.ends_with(".3mf"):
		dest += ".3mf"
	var cfg := {
		"input_glb":      last_glb_path,
		"output_3mf":     dest,
		"palette_colors": _3mf_palette,
		"subdivisions":   _3mf_subdivisions,
	}
	var cfg_path := OS.get_temp_dir().path_join("lofi_export_3mf.json")
	var f := FileAccess.open(cfg_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(cfg))
	f.close()
	_set_tex_status("[color=cyan]Exporting 3MF…[/color]")
	var out: Array = []
	var code := OS.execute(BLENDER_BIN, [
		"--background", "--python",
		repo_root.path_join("blender_scripts/export_3mf.py"),
		"--", cfg_path,
	], out, true)
	if code == 0:
		_set_tex_status("[color=green]3MF: %s[/color]" % dest.get_file())
	else:
		push_error("[export_3mf] %s" % "\n".join(out))
		_set_tex_status("[color=red]3MF export failed — see output.[/color]")


# ─── Range / counter helpers ─────────────────────────────────────────────────

func _get_tex_resolutions() -> Array[int]:
	var res: Array[int] = []
	for i in 4:
		res.append(ALL_TEX_RES[tex_res_start + i])
	return res

func _update_poly_presets() -> void:
	var max_tris := mini(maxi(int(poly_base_tris * poly_max_mult), 50), 10000)
	for i in 4:
		poly_presets[i] = maxi(int(max_tris * POLY_FRACS[i]), 50)
		if poly_btns.size() > i:
			var score_str := _poly_scores.get(poly_presets[i], "") as String
			var n := poly_presets[i]
			var short := ("%dk" % (n / 1000)) if n >= 1000 else ("%d" % n)
			var lbl := "%s\ntris" % short
			if score_str != "":
				lbl += "\n" + score_str
			poly_btns[i].text = lbl
	var at_limit := poly_source_tris > 0 and max_tris >= poly_source_tris
	poly_range_lbl.text = "max %d tris%s" % [max_tris, " (mesh limit)" if at_limit else ""]

func _shift_poly_range(mult: float) -> void:
	var cap := 16.0
	if poly_source_tris > 0 and poly_base_tris > 0:
		cap = maxf(ceil(float(poly_source_tris) / poly_base_tris), 1.0)
	# Also cap so that max preset never exceeds 10k tris
	if poly_base_tris > 0:
		cap = minf(cap, ceil(10000.0 / float(poly_base_tris)))
	poly_max_mult = clampf(poly_max_mult * mult, 1.0, cap)
	_update_poly_presets()

func _px_label(r: int) -> String:
	return ("%dk" % (r / 1000)) if r >= 1000 else ("%d" % r)

func _update_tex_btns() -> void:
	var res := _get_tex_resolutions()
	for i in 4:
		if tex_btns.size() > i:
			tex_btns[i].text = _px_label(res[i]) + "px"
	tex_range_lbl.text = "%spx–%spx" % [_px_label(res[0]), _px_label(res[3])]

func _shift_tex_range(delta: int) -> void:
	tex_res_start = clampi(tex_res_start + delta, 0, ALL_TEX_RES.size() - 4)
	_update_tex_btns()
	# Re-enable/disable buttons to reflect which resolutions were actually baked
	if not bake_results.is_empty():
		var res_list := _get_tex_resolutions()
		for i in 4:
			tex_btns[i].disabled = not bake_results.has(res_list[i])

func _update_counter() -> void:
	var parts: Array[String] = []
	if current_tri_count > 0:
		parts.append("%d tris" % current_tri_count)
	if current_tex_res > 0:
		parts.append("%dpx tex" % current_tex_res)
	counter_label.text = "  ·  ".join(parts)

func _preview_glb_is_fresh(glb: String) -> bool:
	if not FileAccess.file_exists(glb):
		return false
	if selected_path.is_empty():
		return true
	return FileAccess.get_modified_time(glb) > FileAccess.get_modified_time(selected_path)

# ─── GLB loading ─────────────────────────────────────────────────────────────

func _load_preview_glb(path: String, use_texture: bool = false) -> void:
	var _old := model_root.get_children()
	for c in _old:
		model_root.remove_child(c)
		c.queue_free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		_set_geo_status("[color=red]Failed to load preview[/color]")
		return
	var scene := doc.generate_scene(state)
	model_root.add_child(scene)
	# Show texture only for hi-res initial preview; poly selection always uses matcap
	if use_texture and selected_texture_path != "" and psx_shader:
		_apply_psx(scene)
	else:
		_apply_preview_mat(scene)
	# Force full resolution for preview so low-poly silhouette is legible
	_on_pixelate_toggled(false)
	current_tri_count = selected_poly
	current_tex_res   = 0
	_update_counter()
	_frame_model.call_deferred()
	# Auto-enable wireframe for geo preview (B) and restore if already on (Issue 3)
	if not geo_wire_btn.button_pressed:
		geo_wire_btn.button_pressed = true  # triggers _on_wireframe_toggled via signal
	else:
		call_deferred("_on_wireframe_toggled", true)


func _apply_preview_mat(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat: Material
		if matcap_shader:
			var sm := ShaderMaterial.new()
			sm.shader = matcap_shader
			mat = sm
		else:
			var std := StandardMaterial3D.new()
			std.albedo_color = Color(0.76, 0.72, 0.68, 1.0)
			std.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			std.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat = std
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		if c.name != "__wire__":
			_apply_preview_mat(c)


func _load_glb(path: String) -> void:
	for c in model_root.get_children():
		c.queue_free()

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		_set_geo_status("[color=red]Failed to load: %s[/color]" % path.get_file())
		return

	var scene := doc.generate_scene(state)
	model_root.add_child(scene)
	if psx_shader:
		_apply_psx(scene)
	# Entering texture phase — turn off geo wireframe, restore render wireframe
	if geo_wire_btn.button_pressed:
		geo_wire_btn.button_pressed = false
	# Restore pixelation only if LOOK master is on
	_on_pixelate_toggled(pixelate_btn.button_pressed and _look_enabled)
	_frame_model.call_deferred()
	if wireframe_btn.button_pressed:
		call_deferred("_on_wireframe_toggled", true)
	current_tri_count = _count_tris(scene)
	_update_counter()


func _count_tris(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var m := (node as MeshInstance3D).mesh
		if m:
			for s in m.get_surface_count():
				var arr: Array = m.surface_get_arrays(s)
				if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
					total += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
					total += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for c in node.get_children():
		total += _count_tris(c)
	return total


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
			# Only apply geometric PSX effects if Look master is enabled
			mat.set_shader_parameter("snap_vertices", snap_btn.button_pressed and _look_enabled)
			mat.set_shader_parameter("use_affine_uv",  affine_btn.button_pressed and _look_enabled)
			mat.set_shader_parameter("use_dither",     dither_btn.button_pressed and _look_enabled)
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
		if c.name != "__wire__":
			_patch_params(c, param, value)


# ─── Wireframe ───────────────────────────────────────────────────────────────

func _on_wireframe_toggled(on: bool) -> void:
	_update_wireframe(model_root, on)


func _update_wireframe(node: Node, on: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var old := mi.get_node_or_null(NodePath("__wire__"))
		if old:
			old.queue_free()
		if on and mi.mesh:
			var wire_mesh := _build_wire_mesh(mi.mesh)
			if wire_mesh.get_surface_count() > 0:
				var wire_mi := MeshInstance3D.new()
				wire_mi.name = "__wire__"
				wire_mi.mesh = wire_mesh
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.albedo_color = Color(0.2, 1.0, 0.3, 1.0)
				for i in wire_mesh.get_surface_count():
					wire_mi.set_surface_override_material(i, mat)
				mi.add_child(wire_mi)
	for c in node.get_children():
		if c.name != "__wire__":
			_update_wireframe(c, on)


func _build_wire_mesh(src_mesh: Mesh) -> ArrayMesh:
	var wire := ArrayMesh.new()
	for s in src_mesh.get_surface_count():
		var arrays := src_mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_indices = arrays[Mesh.ARRAY_INDEX]
		var line_verts := PackedVector3Array()
		if src_indices != null and src_indices.size() > 0:
			var idx := PackedInt32Array(src_indices)
			var i := 0
			while i + 2 < idx.size():
				var a := src_verts[idx[i]]; var b := src_verts[idx[i+1]]; var c := src_verts[idx[i+2]]
				line_verts.push_back(a); line_verts.push_back(b)
				line_verts.push_back(b); line_verts.push_back(c)
				line_verts.push_back(c); line_verts.push_back(a)
				i += 3
		else:
			var i := 0
			while i + 2 < src_verts.size():
				var a := src_verts[i]; var b := src_verts[i+1]; var c := src_verts[i+2]
				line_verts.push_back(a); line_verts.push_back(b)
				line_verts.push_back(b); line_verts.push_back(c)
				line_verts.push_back(c); line_verts.push_back(a)
				i += 3
		if line_verts.is_empty():
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = line_verts
		wire.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	return wire


# ─── Camera ──────────────────────────────────────────────────────────────────

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
		orbit_dist * cos(pr) * cos(yr))
	cam.look_at(orbit_center, Vector3.UP)


# ─── Turntable & BG ──────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if turntable_btn.button_pressed and not _aabb_empty and not recording:
		orbit_yaw += speed_slider.value * delta
		_update_camera()
	if recording:
		orbit_yaw += 360.0 / RECORD_FRAMES
		_update_camera()
		call_deferred("_capture_record_frame")
	if _anim_on and is_instance_valid(_anim_target):
		_poll_timer += delta
		if _poll_timer >= 0.3:
			_poll_timer = 0.0
			if _progress_file != "":
				var data := _read_json(_progress_file)
				if data.has("pct"):
					var pct := int(data.get("pct", 0))
					var msg := str(data.get("msg", _anim_base))
					_anim_target.text = "[color=cyan]%s  %d%%[/color]" % [msg, pct]
			else:
				_anim_step = (_anim_step + 1) % 4
				_anim_target.text = _anim_base + ".".repeat(_anim_step + 1)


func _on_bg_color_changed(color: Color) -> void:
	color.a = 1.0
	if world_env and world_env.environment:
		world_env.environment.background_color = color


func _on_record_pressed() -> void:
	if recording:
		return
	record_format = "gif" if fmt_option.selected == 1 else "mp4"
	var stem := selected_path.get_file().get_basename() if selected_path != "" else "lofi"
	video_dialog.current_file = stem + "_360." + record_format
	video_dialog.popup_centered()


func _get_record_size() -> Vector2i:
	if _record_res == Vector2i(0, 0):
		return viewport3d.size
	var s := _record_res
	if _aspect_ratio > 0.0:
		if float(s.x) / float(s.y) > _aspect_ratio:
			s.x = int(s.y * _aspect_ratio)
		else:
			s.y = int(s.x / _aspect_ratio)
	return s


func _on_video_path_selected(dest: String) -> void:
	record_dir = OS.get_temp_dir().path_join("lofi_rec_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(record_dir)
	record_frame_idx = 0
	record_btn.set_meta("dest", dest)

	# Hide panel so the full window shows the renderer (CRT effects included).
	side_panel.visible = false
	await get_tree().process_frame
	await get_tree().process_frame

	recording = true
	record_btn.disabled = true
	var vp: Vector2i = get_viewport().size
	_set_geo_status("[color=cyan]Recording %dx%d… 0/%d[/color]" % [vp.x, vp.y, RECORD_FRAMES])


func _capture_record_frame() -> void:
	if not recording:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(record_dir.path_join("frame_%04d.png" % record_frame_idx))
	record_frame_idx += 1
	if record_frame_idx >= RECORD_FRAMES:
		recording = false
		_encode_video(record_btn.get_meta("dest"))


func _encode_video(dest: String) -> void:
	_set_geo_status("[color=cyan]Encoding %s…[/color]" % record_format)
	var out: Array = []
	var code := OS.execute(PYTHON_BIN, [
		repo_root.path_join("blender_scripts/make_video.py"),
		record_dir, dest, str(RECORD_FPS),
	], out, true)
	side_panel.visible = _panel_visible
	record_btn.disabled = false
	if code == 0:
		_set_geo_status("[color=green]Video: %s[/color]" % dest.get_file())
	else:
		push_error("[make_video] %s" % "\n".join(out))
		_set_geo_status("[color=red]Encode failed.[/color]")


# ─── PSX effects ─────────────────────────────────────────────────────────────

func _on_pixelate_toggled(on: bool) -> void:
	var vp    := get_viewport().get_visible_rect().size
	var eff_w := _panel_w if _panel_visible else 0.0
	var w3d   := int(vp.x - eff_w)
	var h3d   := int(vp.y)
	if _aspect_ratio > 0.0:
		if float(w3d) / float(h3d) > _aspect_ratio:
			w3d = int(h3d * _aspect_ratio)
		else:
			h3d = int(w3d / _aspect_ratio)
		magnification_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		magnification_rect.stretch_mode = TextureRect.STRETCH_SCALE
	if on:
		var scale: float = pixelate_slider.value
		viewport3d.size = Vector2i(maxi(int(w3d * scale), 2), maxi(int(h3d * scale), 2))
		magnification_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		viewport3d.size = Vector2i(maxi(w3d, 2), maxi(h3d, 2))
		magnification_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _apply_aspect_ratio(ratio: float) -> void:
	_aspect_ratio = ratio
	_on_pixelate_toggled(is_instance_valid(pixelate_btn) and pixelate_btn.button_pressed)


# ─── Snapshot ────────────────────────────────────────────────────────────────

func _on_snapshot_pressed() -> void:
	var stem := selected_path.get_file().get_basename() if selected_path != "" else "lofi"
	snapshot_dialog.current_file = stem + "_snap.png"
	snapshot_dialog.popup_centered()


func _on_snapshot_path_selected(dest: String) -> void:
	if not dest.ends_with(".png"):
		dest += ".png"
	side_panel.visible = false
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	side_panel.visible = true
	img.save_png(dest)
	_set_geo_status("[color=green]Snapshot: %s[/color]" % dest.get_file())


# ─── Drag & drop ─────────────────────────────────────────────────────────────

func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	var path := files[0]
	if path.get_extension().to_lower() in ["obj", "glb", "gltf", "ply"]:
		_on_file_selected(path)
	else:
		_set_geo_status("[color=red]Drop a .obj, .glb, .gltf or .ply file.[/color]")


# ─── Accordion & Theme ───────────────────────────────────────────────────────

func _apply_panel_theme() -> void:
	# ── Palette ──────────────────────────────────────────────────────────────
	var C_BG        := Color(0.090, 0.090, 0.090)
	var C_SURF      := Color(0.140, 0.140, 0.140)
	var C_SURF_H    := Color(0.190, 0.190, 0.190)
	var C_SURF_P    := Color(0.080, 0.080, 0.080)
	var C_BORDER    := Color(0.240, 0.240, 0.240)
	var C_ACCENT    := Color(0.270, 0.510, 0.940)
	var C_ACCENT_D  := Color(0.150, 0.300, 0.580)
	var C_TEXT      := Color(0.870, 0.870, 0.870)
	var C_TEXT_DIM  := Color(0.460, 0.460, 0.460)
	var C_SEP       := Color(0.210, 0.210, 0.210)

	# ── Helper ───────────────────────────────────────────────────────────────
	var flat_box := func(bg: Color, brd: Color, brd_w: int = 1) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = brd
		s.set_border_width_all(brd_w)
		s.set_corner_radius_all(3)
		s.content_margin_left   = 8;  s.content_margin_right  = 8
		s.content_margin_top    = 5;  s.content_margin_bottom = 5
		return s

	# ── Panel background ─────────────────────────────────────────────────────
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = C_BG
	panel_bg.set_border_width(SIDE_LEFT, 1)
	panel_bg.border_color = C_SEP
	side_panel.add_theme_stylebox_override("panel", panel_bg)

	# ── Build theme ──────────────────────────────────────────────────────────
	var theme := Theme.new()

	# Fonts — base 13px, rich text slightly smaller
	for cls: String in ["Label", "Button", "CheckButton", "OptionButton", "HSlider"]:
		theme.set_font_size("font_size", cls, 13)
	theme.set_font_size("font_size", "RichTextLabel", 12)

	# Button
	theme.set_stylebox("normal",   "Button", flat_box.call(C_SURF,   C_BORDER))
	theme.set_stylebox("hover",    "Button", flat_box.call(C_SURF_H, C_BORDER))
	theme.set_stylebox("pressed",  "Button", flat_box.call(C_SURF_P, C_ACCENT))
	theme.set_stylebox("disabled", "Button", flat_box.call(C_SURF_P, C_SEP, 0))
	theme.set_stylebox("focus",    "Button", flat_box.call(C_SURF,   C_ACCENT))
	# Toggle-pressed state reuses "pressed" key — accent tint bg
	var btn_on: StyleBoxFlat = flat_box.call(C_ACCENT_D, C_ACCENT)
	theme.set_stylebox("pressed",  "Button", btn_on)
	theme.set_color("font_color",          "Button", C_TEXT)
	theme.set_color("font_hover_color",    "Button", Color.WHITE)
	theme.set_color("font_pressed_color",  "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", C_TEXT_DIM)
	theme.set_constant("outline_size", "Button", 0)

	# CheckButton — inherit Button colours, just let Godot draw the toggle switch
	theme.set_color("font_color",         "CheckButton", C_TEXT)
	theme.set_color("font_hover_color",   "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", Color.WHITE)
	theme.set_color("font_focus_color",   "CheckButton", C_TEXT)
	theme.set_stylebox("normal",   "CheckButton", flat_box.call(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	theme.set_stylebox("hover",    "CheckButton", flat_box.call(C_SURF_H, Color.TRANSPARENT, 0))
	theme.set_stylebox("pressed",  "CheckButton", flat_box.call(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	theme.set_stylebox("disabled", "CheckButton", flat_box.call(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	theme.set_stylebox("focus",    "CheckButton", flat_box.call(Color.TRANSPARENT, Color.TRANSPARENT, 0))

	# HSlider — flat track, accent fill
	var track := StyleBoxFlat.new()
	track.bg_color = C_SURF;  track.set_corner_radius_all(2)
	track.content_margin_top = 5;  track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_ACCENT;  fill.set_corner_radius_all(2)
	fill.content_margin_top = 5;  fill.content_margin_bottom = 5
	theme.set_stylebox("slider",                 "HSlider", track)
	theme.set_stylebox("grabber_area",           "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_constant("grabber_offset", "HSlider", 0)

	# HSeparator
	var sep_line := StyleBoxLine.new()
	sep_line.color = C_SEP;  sep_line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_line)

	# Label
	theme.set_color("font_color", "Label", C_TEXT)

	# ScrollContainer — no visible bg
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", empty)

	side_panel.theme = theme


func _update_panel_size() -> void:
	var vp_w := get_viewport().get_visible_rect().size.x
	# First-time init: default to 22 % of viewport width
	if _panel_w <= 0.0:
		_panel_w = clampf(vp_w * 0.22, 300.0, 620.0)
	# Always keep width in a sane range
	_panel_w = clampf(_panel_w, 200.0, vp_w * 0.60)
	var eff_w := _panel_w if _panel_visible else 0.0

	side_panel.visible      = _panel_visible
	side_panel.offset_left  = -_panel_w   # panel always occupies _panel_w (just hidden)
	magnification_rect.offset_right = -eff_w
	crt_rect.offset_right           = -eff_w

	if is_instance_valid(_panel_toggle_btn):
		_panel_toggle_btn.text         = "◀" if _panel_visible else "▶"
		_panel_toggle_btn.offset_left  = -eff_w - 20.0
		_panel_toggle_btn.offset_right = -eff_w

	# Re-apply viewport size / aspect ratio after panel width change
	if is_instance_valid(pixelate_btn):
		_on_pixelate_toggled(pixelate_btn.button_pressed)

	# Re-measure open accordion sections after width change
	if _acc_clips.size() > 0:
		_init_acc_heights.call_deferred()


func _build_3mf_palette_row() -> void:
	if _acc_content.size() < 5:
		return
	var export_content := _acc_content[4]
	var tmf_node := export_content.find_child("Export3MFBtn", true, false)
	var insert_idx := tmf_node.get_index() if is_instance_valid(tmf_node) else -1

	# ── Grouped container ─────────────────────────────────────────────────────
	var grp := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.11, 0.11)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8;  sb.content_margin_right = 8
	sb.content_margin_top  = 8;  sb.content_margin_bottom = 8
	grp.add_theme_stylebox_override("panel", sb)

	var grp_vbox := VBoxContainer.new()
	grp_vbox.add_theme_constant_override("separation", 6)
	grp.add_child(grp_vbox)

	var grp_lbl := Label.new()
	grp_lbl.text = "Color 3D print"
	grp_lbl.add_theme_font_size_override("font_size", 10)
	grp_lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.42))
	grp_vbox.add_child(grp_lbl)

	# ── Detail (subdivisions) row ─────────────────────────────────────────────
	var det_row := HBoxContainer.new()
	det_row.add_theme_constant_override("separation", 6)

	var det_lbl := Label.new()
	det_lbl.text = "Detail"
	det_lbl.add_theme_font_size_override("font_size", 11)
	det_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	det_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_row.add_child(det_lbl)

	var det_opt := OptionButton.new()
	det_opt.add_item("Normal")
	det_opt.add_item("+1 subdiv (4×)")
	det_opt.add_item("+2 subdiv (16×)")
	det_opt.select(0)
	_3mf_subdivisions = 0
	det_opt.add_theme_font_size_override("font_size", 11)
	det_opt.item_selected.connect(func(idx: int): _3mf_subdivisions = idx)
	det_row.add_child(det_opt)
	grp_vbox.add_child(det_row)

	# ── Colors (palette) row ──────────────────────────────────────────────────
	var pal_row := HBoxContainer.new()
	pal_row.add_theme_constant_override("separation", 6)

	var pal_lbl := Label.new()
	pal_lbl.text = "Colors"
	pal_lbl.add_theme_font_size_override("font_size", 11)
	pal_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	pal_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal_row.add_child(pal_lbl)

	var pal_opt := OptionButton.new()
	pal_opt.add_item("Full")
	pal_opt.add_item("32")
	pal_opt.add_item("16")
	pal_opt.add_item("8")
	pal_opt.add_item("4")
	pal_opt.select(2)
	_3mf_palette = 16
	pal_opt.add_theme_font_size_override("font_size", 11)
	pal_opt.item_selected.connect(func(idx: int):
		var vals := [0, 32, 16, 8, 4]
		_3mf_palette = vals[idx])
	pal_row.add_child(pal_opt)
	grp_vbox.add_child(pal_row)

	export_content.add_child(grp)
	if insert_idx >= 0:
		export_content.move_child(grp, insert_idx)

	_init_acc_heights.call_deferred()


func _build_panel_controls() -> void:
	var canvas := get_node("CanvasLayer") as CanvasLayer

	# ── Toggle tab ──────────────────────────────────────────────────────────
	_panel_toggle_btn = Button.new()
	_panel_toggle_btn.text      = "◀"
	_panel_toggle_btn.flat      = false
	_panel_toggle_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_toggle_btn.anchor_left   = 1.0;  _panel_toggle_btn.anchor_right  = 1.0
	_panel_toggle_btn.anchor_top    = 0.5;  _panel_toggle_btn.anchor_bottom = 0.5
	_panel_toggle_btn.offset_top    = -32.0;  _panel_toggle_btn.offset_bottom = 32.0
	_panel_toggle_btn.custom_minimum_size = Vector2(20, 64)
	# Style: same dark as section header
	var tab_n := StyleBoxFlat.new()
	tab_n.bg_color = Color(0.14, 0.14, 0.14)
	tab_n.set_border_width_all(1);  tab_n.border_color = Color(0.24, 0.24, 0.24)
	tab_n.set_corner_radius_all(0)
	tab_n.content_margin_left = 2;  tab_n.content_margin_right = 2
	tab_n.content_margin_top = 6;   tab_n.content_margin_bottom = 6
	var tab_h := tab_n.duplicate() as StyleBoxFlat
	tab_h.bg_color = Color(0.20, 0.20, 0.20)
	_panel_toggle_btn.add_theme_stylebox_override("normal",  tab_n)
	_panel_toggle_btn.add_theme_stylebox_override("hover",   tab_h)
	_panel_toggle_btn.add_theme_stylebox_override("pressed", tab_n)
	_panel_toggle_btn.add_theme_stylebox_override("focus",   tab_n)
	_panel_toggle_btn.add_theme_font_size_override("font_size", 10)
	_panel_toggle_btn.add_theme_color_override("font_color",       Color(0.75, 0.75, 0.75))
	_panel_toggle_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_panel_toggle_btn.pressed.connect(_toggle_panel_visible)
	canvas.add_child(_panel_toggle_btn)

	# ── Drag handle ─────────────────────────────────────────────────────────
	var handle := Control.new()
	handle.anchor_top    = 0.0;  handle.anchor_bottom = 1.0
	handle.anchor_left   = 0.0;  handle.anchor_right  = 0.0
	handle.offset_left   = 0.0;  handle.offset_right  = 5.0
	handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	handle.z_index = 10
	side_panel.add_child(handle)
	handle.gui_input.connect(_on_panel_handle_input)


func _toggle_panel_visible() -> void:
	_panel_visible = not _panel_visible
	_update_panel_size()


func _on_panel_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_panel = mb.pressed


func _build_accordion() -> void:
	var vbox := get_node(_VB) as VBoxContainer

	# Which existing scene nodes go into each section (order matters)
	var sections: Array[Array] = [
		# 0 SHAPE
		["LoadBtn", "InputLabel", "LoadTexRow", "DecimateBtn", "PolyRow", "PreviewRow", "PolyRangeRow", "GeoStatus"],
		# 1 SURFACE
		["BakeBtn", "TexRow", "TexRangeRow", "TexStatus", "ResultLabel"],
		# 2 LOOK
		["PixelateRow", "PSXToggles1", "PSXToggles2",
		 "GrainRow", "ChromaRow", "ScanlinesRow", "VignetteRow", "WarbleRow", "BGRow"],
		# 3 MOTION
		["TurntableRow"],
		# 4 EXPORT
		["ExportBtn", "ExportBakedBtn", "ExportHtmlBtn", "Export3MFBtn", "CaptureRow"],
	]

	# Hide + free old section headers / spacers (replaced by accordion headers)
	for nm in ["Spacer0", "GeoHeader", "Spacer1", "TexHeader", "Spacer2",
			   "RenderHeader", "PSXLabel", "CRTLabel", "SceneLabel", "CaptureLabel"]:
		var n := vbox.find_child(nm, false, false)
		if is_instance_valid(n):
			n.visible = false
			n.queue_free()

	for i in 5:
		var wrap := VBoxContainer.new()
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_theme_constant_override("separation", 0)
		vbox.add_child(wrap)

		# Header button — distinct bg, no border-radius
		var hdr := Button.new()
		hdr.text      = ("▾ " if _acc_open[i] else "▸ ") + _ACC_NAMES[i]
		hdr.alignment = HORIZONTAL_ALIGNMENT_LEFT
		hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr.add_theme_font_size_override("font_size", 13)
		hdr.add_theme_color_override("font_color",       Color(0.95, 0.95, 0.95))
		hdr.add_theme_color_override("font_hover_color", Color.WHITE)
		var _hdr_n := StyleBoxFlat.new()
		_hdr_n.bg_color = Color(0.12, 0.12, 0.12)
		_hdr_n.set_corner_radius_all(0)
		_hdr_n.content_margin_left = 12;  _hdr_n.content_margin_right = 8
		_hdr_n.content_margin_top  = 9;   _hdr_n.content_margin_bottom = 9
		_hdr_n.set_border_width(SIDE_BOTTOM, 1)
		_hdr_n.border_color = Color(0.22, 0.22, 0.22)
		var _hdr_h := _hdr_n.duplicate() as StyleBoxFlat
		_hdr_h.bg_color = Color(0.17, 0.17, 0.17)
		hdr.add_theme_stylebox_override("normal",  _hdr_n)
		hdr.add_theme_stylebox_override("hover",   _hdr_h)
		hdr.add_theme_stylebox_override("pressed", _hdr_n)
		hdr.add_theme_stylebox_override("focus",   _hdr_n)

		if i == 2:  # LOOK — wrap header in HBox + add master toggle
			var hdr_box := HBoxContainer.new()
			hdr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hdr_box.add_theme_constant_override("separation", 0)
			hdr_box.add_child(hdr)
			var look_on := CheckButton.new()
			# Block signals so setting button_pressed doesn't trigger toggled during init
			look_on.set_block_signals(true)
			look_on.button_pressed = false
			look_on.set_block_signals(false)
			look_on.text = "FX"
			look_on.add_theme_font_size_override("font_size", 11)
			look_on.add_theme_stylebox_override("normal",   _hdr_n)
			look_on.add_theme_stylebox_override("hover",    _hdr_h)
			look_on.add_theme_stylebox_override("pressed",  _hdr_n)
			look_on.add_theme_stylebox_override("focus",    _hdr_n)
			# Signal is wired in _ready() after accordion is built
			_look_master_btn = look_on
			hdr_box.add_child(look_on)
			wrap.add_child(hdr_box)
		else:
			wrap.add_child(hdr)

		# Clip control — plain Control so its minimum size = custom_minimum_size only
		var clip := Control.new()
		clip.clip_contents = true
		clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clip.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
		wrap.add_child(clip)

		# Content VBox anchored to clip's full width, starts at top
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		content.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		content.set_offset(SIDE_TOP, 8)   # top padding inside section
		clip.add_child(content)

		# Reparent relevant nodes into this section
		for nm: String in sections[i]:
			var n := vbox.find_child(nm, false, false)
			if is_instance_valid(n):
				n.reparent(content, false)

		_acc_clips.append(clip)
		_acc_content.append(content)

		var idx := i
		hdr.pressed.connect(func(): _toggle_acc(idx, hdr))

	_merge_range_row(_acc_content[0], "PolyRow", poly_range_down, poly_range_up, poly_range_lbl)
	_merge_range_row(_acc_content[1], "TexRow",  tex_range_down,  tex_range_up,  tex_range_lbl)

	# Put Export GLB + Baked GLB side by side in one row
	var export_ct := _acc_content[4]
	var btn_glb   := export_ct.find_child("ExportBtn",      true, false) as Button
	var btn_baked := export_ct.find_child("ExportBakedBtn", true, false) as Button
	if is_instance_valid(btn_glb) and is_instance_valid(btn_baked):
		var glb_row := HBoxContainer.new()
		glb_row.add_theme_constant_override("separation", 4)
		var glb_idx := btn_glb.get_index()
		export_ct.add_child(glb_row)
		export_ct.move_child(glb_row, glb_idx)
		btn_glb.reparent(glb_row, false)
		btn_baked.reparent(glb_row, false)
		btn_glb.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		btn_baked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_glb.custom_minimum_size   = Vector2(0, 30)
		btn_baked.custom_minimum_size = Vector2(0, 30)

	# Measure and set heights after one layout frame, then re-measure after layout settles
	_init_acc_heights.call_deferred()
	get_tree().create_timer(0.12).timeout.connect(_init_acc_heights)


func _merge_range_row(content: VBoxContainer, row_name: String,
		down_btn: Button, up_btn: Button, lbl: Label) -> void:
	var row := content.find_child(row_name, true, false) as HBoxContainer
	var range_row := content.find_child(row_name.replace("Row", "RangeRow"), true, false)
	if not is_instance_valid(row):
		return

	# Style range buttons to match step button height
	down_btn.custom_minimum_size = Vector2(34, 44)
	down_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	up_btn.custom_minimum_size = Vector2(34, 44)
	up_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Move ↓ to front of row, ↑ to end
	down_btn.reparent(row, false)
	row.move_child(down_btn, 0)
	up_btn.reparent(row, false)

	# Move label directly into content, just after the row
	var row_idx := row.get_index()
	lbl.reparent(content, false)
	content.move_child(lbl, row_idx + 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.46, 0.46, 0.46))

	# Free the now-empty RangeRow container
	if is_instance_valid(range_row):
		range_row.queue_free()


func _init_acc_heights() -> void:
	for i in 5:
		# +8 top offset (set on content) + 12 bottom breathing room
		var h := _acc_content[i].get_combined_minimum_size().y + 20.0
		_acc_heights[i] = h
		_acc_clips[i].custom_minimum_size.y = h if _acc_open[i] else 0.0


func _toggle_acc(i: int, hdr: Button) -> void:
	_acc_open[i] = not _acc_open[i]
	hdr.text = ("▾ " if _acc_open[i] else "▸ ") + _ACC_NAMES[i]
	var clip := _acc_clips[i]
	# Re-measure in case content changed (e.g. score lines added to buttons)
	if _acc_open[i]:
		_acc_heights[i] = _acc_content[i].get_combined_minimum_size().y + 20.0
	var target_h := _acc_heights[i] if _acc_open[i] else 0.0
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(clip, "custom_minimum_size:y", target_h, 0.22)


# ─── Input ───────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Panel drag takes highest priority — handle before any side_panel block check
	if _dragging_panel:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_dragging_panel = false
			return
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			var vp_w := get_viewport().get_visible_rect().size.x
			_panel_w = clampf(_panel_w - mm.relative.x, 200.0, vp_w * 0.60)
			_update_panel_size()
			return

	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var mouse_pos: Vector2
		if event is InputEventMouseButton:
			mouse_pos = (event as InputEventMouseButton).global_position
		else:
			mouse_pos = (event as InputEventMouseMotion).global_position
		if _panel_visible and side_panel.get_global_rect().has_point(mouse_pos):
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			orbit_dist = maxf(orbit_dist * 0.9, 0.05)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			orbit_dist = minf(orbit_dist * 1.1, 500.0)
			_update_camera()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_dragging:
			orbit_yaw   -= mm.relative.x * 0.4
			orbit_pitch  = clampf(orbit_pitch + mm.relative.y * 0.4, -89.0, 89.0)
			_update_camera()
		elif is_panning and cam:
			var speed := orbit_dist * 0.0012
			orbit_center -= cam.global_transform.basis.x * mm.relative.x * speed
			orbit_center += cam.global_transform.basis.y * mm.relative.y * speed
			_update_camera()


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _set_geo_status(msg: String, progress_path: String = "") -> void:
	if not is_instance_valid(geo_status):
		return
	var animate := progress_path != ""
	_anim_on       = animate
	_anim_target   = geo_status
	_progress_file = progress_path
	_poll_timer    = 0.0
	if animate:
		_anim_base  = msg
		_anim_step  = 0
		geo_status.text = "[color=cyan]%s  0%%[/color]" % msg
	else:
		geo_status.text = msg

func _set_tex_status(msg: String, progress_path: String = "") -> void:
	if not is_instance_valid(tex_status):
		return
	var animate := progress_path != ""
	_anim_on       = animate
	_anim_target   = tex_status
	_progress_file = progress_path
	_poll_timer    = 0.0
	if animate:
		_anim_base  = msg
		_anim_step  = 0
		tex_status.text = "[color=cyan]%s  0%%[/color]" % msg
	else:
		tex_status.text = msg

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
