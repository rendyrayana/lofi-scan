"""
gen_html.py — Generate a self-contained HTML PSX viewer from a GLB.

Rendering pipeline (matches Godot renderer):
  Pass 1 — 3-D scene rendered to a low-res WebGLRenderTarget (pixelTarget)
            with NearestFilter so upscaling is chunky/pixelated.
  Pass 2 — Fullscreen CRT quad reads pixelTarget and applies:
              warble, chromatic aberration, film grain (soft-light),
              vignette, scanlines, CRT radial vignette.

Usage:
    python3 blender_scripts/gen_html.py config.json

Config JSON (all optional except input/output):
    input_glb           str
    output_html         str
    model_name          str
    exposure            float  1.0
    brightness          float  1.0
    contrast            float  1.0
    use_dither          bool   true
    dither_gamma        float  1.0
    snap_vertices       bool   true
    pixelate            bool   false
    pixelate_scale      float  0.15   (fraction of viewport, e.g. 0.15 = 15%)
    sun_intensity       float  2.0
    sun_pitch           float  -45
    sun_yaw             float  45
    ambient             float  0.2
    grain_intensity     float  0.0
    chroma              float  0.0
    scanlines           float  0.0
    vignette_darkness   float  0.0
    crt_vignette_power  float  0.0
    warble_amount       float  0.0
    warble_speed        float  5.0
    bg_color            [r,g,b] 0-1
"""

import sys, json, base64, struct
from io import BytesIO


# ── GLB texture upscaling ────────────────────────────────────────────────────

_GLB_JSON_CHUNK = 0x4E4F534A
_GLB_BIN_CHUNK  = 0x004E4942


def _align4(n: int) -> int:
    return (n + 3) & ~3


def _upscale_glb_textures(glb_bytes: bytes, min_size: int) -> bytes:
    """Bilinear-upscale every embedded texture in a GLB to at least min_size px."""
    try:
        from PIL import Image
    except ImportError:
        return glb_bytes  # Pillow unavailable — return unchanged

    magic, version, _ = struct.unpack_from("<4sII", glb_bytes, 0)
    if magic != b"glTF" or version != 2:
        return glb_bytes

    chunks: dict[int, bytes] = {}
    offset = 12
    while offset < len(glb_bytes):
        chunk_len, chunk_type = struct.unpack_from("<II", glb_bytes, offset)
        chunks[chunk_type] = glb_bytes[offset + 8: offset + 8 + chunk_len]
        offset += 8 + chunk_len

    json_bytes = chunks.get(_GLB_JSON_CHUNK, b"{}")
    bin_bytes  = chunks.get(_GLB_BIN_CHUNK)
    if not bin_bytes:
        return glb_bytes

    gltf         = json.loads(json_bytes)
    images       = gltf.get("images", [])
    buffer_views = gltf.get("bufferViews", [])
    mod_bin      = bytearray(bin_bytes)

    for img_info in images:
        bv_idx = img_info.get("bufferView")
        if bv_idx is None:
            continue
        bv     = buffer_views[bv_idx]
        start  = bv.get("byteOffset", 0)
        length = bv["byteLength"]
        raw    = bytes(mod_bin[start: start + length])

        try:
            pil = Image.open(BytesIO(raw))
            w, h = pil.size
            if w >= min_size and h >= min_size:
                continue
            scale = min_size / max(w, h)
            nw, nh = int(w * scale), int(h * scale)
            pil = pil.convert("RGBA").resize((nw, nh), Image.BILINEAR)
            out = BytesIO()
            pil.save(out, format="PNG", optimize=False)
            new_raw = out.getvalue()
        except Exception:
            continue

        if len(new_raw) <= length:
            mod_bin[start: start + length] = new_raw + b"\x00" * (length - len(new_raw))
        else:
            new_offset = _align4(len(mod_bin))
            mod_bin   += b"\x00" * (new_offset - len(mod_bin))
            mod_bin   += new_raw
            bv["byteOffset"] = new_offset
            bv["byteLength"] = len(new_raw)

    if gltf.get("buffers"):
        gltf["buffers"][0]["byteLength"] = len(mod_bin)

    new_json = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    jp = new_json + b" " * (_align4(len(new_json)) - len(new_json))
    bp = bytes(mod_bin) + b"\x00" * (_align4(len(mod_bin)) - len(mod_bin))
    total = 12 + 8 + len(jp) + 8 + len(bp)
    out_buf = bytearray()
    out_buf += struct.pack("<4sII", b"glTF", 2, total)
    out_buf += struct.pack("<II", len(jp), _GLB_JSON_CHUNK) + jp
    out_buf += struct.pack("<II", len(bp), _GLB_BIN_CHUNK)  + bp
    return bytes(out_buf)

TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>__TITLE__</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#1a1a1a;color:#ccc;font-family:monospace;overflow:hidden}
canvas{display:block}
#bar{
  position:fixed;bottom:20px;left:50%;transform:translateX(-50%);
  display:flex;gap:5px;background:rgba(0,0,0,.6);padding:8px 12px;
  border-radius:4px;border:1px solid #333;flex-wrap:wrap;
  justify-content:center;max-width:calc(100vw - 40px);
}
#bar button{
  background:#222;color:#999;border:1px solid #444;padding:5px 10px;
  cursor:pointer;font-family:monospace;font-size:11px;border-radius:2px;
  transition:background .1s,color .1s;
}
#bar button.on{background:#3a3a3a;color:#fff;border-color:#666}
#info{position:fixed;top:10px;left:12px;font-size:11px;color:#555}
</style>
</head>
<body>
<div id="info">__TITLE__</div>
<div id="bar">
  <button id="b-rotate" class="on">&#x27F3; ROTATE</button>
  <button id="b-pixel"  class="__PIXEL_ON__">&#x25A3; PIXEL</button>
  <button id="b-snap"   class="__SNAP_ON__">&#x229E; SNAP</button>
  <button id="b-dither" class="__DITHER_ON__">&#x25C6; DITHER</button>
  <button id="b-grain"  class="__GRAIN_ON__">&#x2726; GRAIN</button>
  <button id="b-chroma" class="__CHROMA_ON__">&#x2295; CHROMA</button>
  <button id="b-scan"   class="__SCAN_ON__">&#x2261; SCAN</button>
  <button id="b-vig"    class="__VIG_ON__">&#x25C9; VIG</button>
  <button id="b-warble" class="__WARBLE_ON__">&#x2307; WARBLE</button>
</div>

<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script>
/* ── params + GLB ─────────────────────────────────────────────── */
var P   = __PARAMS__;
var GLB = "__GLB_B64__";

/* ── renderer ────────────────────────────────────────────────── */
var W = window.innerWidth, H = window.innerHeight;
var renderer = new THREE.WebGLRenderer({antialias:false, precision:'lowp'});
renderer.setSize(W, H);
renderer.setPixelRatio(1);
renderer.autoClear = false;
document.body.appendChild(renderer.domElement);

/* ── 3-D scene ───────────────────────────────────────────────── */
var scene  = new THREE.Scene();
var bg = P.bg_color || [0.102, 0.102, 0.102];
scene.background = new THREE.Color(bg[0], bg[1], bg[2]);

var camera = new THREE.PerspectiveCamera(45, W/H, 0.001, 5000);
camera.position.set(0, 0, 3);

var controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;

// Lighting is handled per-vertex in the PSX shader uniforms (uSunDir, uSunInt, uAmbient)
// No Three.js lights needed — ShaderMaterial ignores them anyway.

/* ── PS1 3-D vertex/fragment shader ─────────────────────────── */
var vert3d = [
'uniform bool  snapVertices;',
'uniform vec3  uSunDir;',
'uniform float uSunInt;',
'uniform float uAmbient;',
'varying vec2  vUv;',
'varying vec3  vLight;',
'void main(){',
'  vUv = uv;',
'  vec3 wn = normalize(mat3(modelMatrix)*normal);',
'  float d = max(dot(wn, uSunDir), 0.0);',
'  vLight = vec3(uAmbient) + d * vec3(uSunInt);',
'  vec4 clip = projectionMatrix*modelViewMatrix*vec4(position,1.0);',
'  if(snapVertices){float r=240.0;clip.xy=floor(clip.xy/clip.w*r)/r*clip.w;}',
'  gl_Position=clip;',
'}'
].join('\n');

var frag3d = [
'uniform sampler2D map;',
'uniform bool  useDither;',
'uniform float ditherGamma;',
'uniform float exposure;',
'uniform float brightness;',
'uniform float contrast;',
'varying vec2 vUv;',
'varying vec3 vLight;',
'float bayer(int x,int y){',
'  int i=x+y*4;',
'  if(i==0)return -4.;if(i==1)return 0.;if(i==2)return -3.;if(i==3)return 1.;',
'  if(i==4)return 2.;if(i==5)return -2.;if(i==6)return 3.;if(i==7)return -1.;',
'  if(i==8)return -3.;if(i==9)return 1.;if(i==10)return -4.;if(i==11)return 0.;',
'  if(i==12)return 3.;if(i==13)return -1.;if(i==14)return 2.;return -2.;',
'}',
'void main(){',
'  vec3 col=texture2D(map,vUv).rgb*vLight;',
'  col=clamp(col*exposure,0.,1.);',
'  col=clamp((col-0.5)*contrast+0.5,0.,1.);',
'  col=clamp(col*brightness,0.,1.);',
'  if(useDither){',
'    int bx=int(mod(gl_FragCoord.x,4.));',
'    int by=int(mod(gl_FragCoord.y,4.));',
'    float off=bayer(bx,by);',
'    float g=ditherGamma;',
'    vec3 gc=vec3(pow(col.r,1./g),pow(col.g,1./g),pow(col.b,1./g));',
'    vec3 sh=gc*255.+off;',
'    vec3 cl2=clamp(floor(sh+.5),0.,255.);',
'    vec3 q=clamp(floor(cl2/8.),0.,31.)/31.;',
'    col=vec3(pow(q.r,g),pow(q.g,g),pow(q.b,g));',
'  }',
'  gl_FragColor=vec4(col,1.);',
'}'
].join('\n');

/* ── CRT fullscreen pass (vertex) ────────────────────────────── */
// Use standard transform — OrthographicCamera(-1,1,1,-1) maps PlaneGeometry(2,2) to fill clip space
var vertCRT = [
'varying vec2 vUv;',
'void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}'
].join('\n');

/* ── CRT fullscreen pass (fragment) ─────────────────────────── */
var fragCRT = [
'uniform sampler2D tDiffuse;',
'uniform float uTime;',
'uniform vec2  uRes;',
'uniform float uGrain;',
'uniform float uChroma;',
'uniform float uScanlines;',
'uniform float uVignette;',
'uniform float uCrtVigPower;',
'uniform float uWarble;',
'uniform float uWarbleSpeed;',
'varying vec2 vUv;',

'float noise(vec2 p){',
'  return(fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453)-0.5)*2.0;',
'}',
'vec3 softLight(vec3 A,vec3 B){',
'  vec3 b1=2.0*A*B+A*A*(1.0-2.0*B);',
'  vec3 b2=2.0*A*(1.0-B)+sqrt(max(A,vec3(0.0)))*(2.0*B-1.0);',
'  return mix(b1,b2,step(vec3(0.5),B));',
'}',
'void main(){',
'  vec2 uv=vUv;',
  // warble
'  vec2 wb=vec2(',
'    sin(uTime*uWarbleSpeed+uv.x*10.0)*cos(uTime*uWarbleSpeed*0.7+uv.y*7.0),',
'    cos(uTime*uWarbleSpeed*0.8+uv.y*11.0)*sin(uTime*uWarbleSpeed*0.9+uv.x*8.0)',
'  )*uWarble;',
'  vec2 suv=clamp(uv+wb,0.0,1.0);',
  // chroma
'  vec3 col;',
'  col.r=texture2D(tDiffuse,suv+vec2(uChroma,0.0)).r;',
'  col.g=texture2D(tDiffuse,suv).g;',
'  col.b=texture2D(tDiffuse,suv-vec2(uChroma,0.0)).b;',
  // grain (soft-light, stronger in shadows)
'  float lum=dot(col,vec3(0.299,0.587,0.114));',
'  float fac=1.0-smoothstep(0.0,1.0,lum);',
'  vec2 off=vec2(sin(uTime*0.5),cos(uTime*0.5))*20.0;',
'  vec3 gr=vec3(noise(uv+off),noise(uv+off+vec2(0.1,0.2)),noise(uv+off+vec2(0.3,0.4)))*uGrain*fac;',
'  col=clamp(softLight(col,clamp(vec3(0.5)+gr,0.0,1.0)),0.0,1.0);',
  // vignette (aspect-corrected)
'  float asp=uRes.x/uRes.y;',
'  vec2 vu=(uv-0.5)*vec2(asp,1.0);',
'  float vd=length(vu);',
'  float vp=smoothstep(0.7,0.2,vd);',
'  col*=mix(1.0-uVignette,1.0,vp);',
  // scanlines
'  float sc=sin(uv.y*uRes.y*3.0);',
'  sc=clamp(sc*0.5+0.5,0.0,1.0);',
'  col*=1.0-sc*uScanlines;',
  // CRT radial vignette
'  vec2 cv=uv-0.5;',
'  float r2=dot(cv,cv);',
'  col*=pow(max(1.0-r2,0.0),uCrtVigPower);',
'  gl_FragColor=vec4(col,1.0);',
'}'
].join('\n');

/* ── pixel render target ─────────────────────────────────────── */
var pixelTarget = null;
var pixelScale  = P.pixelate ? (P.pixelate_scale || 0.15) : 1.0;
var pixelEnabled = P.pixelate || false;

function makePixelTarget(scale) {
  if (pixelTarget) pixelTarget.dispose();
  var pw = Math.max(2, Math.round(W * scale));
  var ph = Math.max(2, Math.round(H * scale));
  var f  = scale < 1.0 ? THREE.NearestFilter : THREE.LinearFilter;
  pixelTarget = new THREE.WebGLRenderTarget(pw, ph, {
    minFilter: f, magFilter: f,
    depthBuffer: true, stencilBuffer: false,
  });
  crtUniforms.tDiffuse.value = pixelTarget.texture;
}

/* ── CRT material / fullscreen quad ─────────────────────────── */
var crtUniforms = {
  tDiffuse:     {value: null},
  uTime:        {value: 0.0},
  uRes:         {value: new THREE.Vector2(W, H)},
  uGrain:       {value: 0.0},
  uChroma:      {value: 0.0},
  uScanlines:   {value: 0.0},
  uVignette:    {value: 0.0},
  uCrtVigPower: {value: 0.0},
  uWarble:      {value: 0.0},
  uWarbleSpeed: {value: P.warble_speed || 5.0},
};

var crtMat = new THREE.ShaderMaterial({
  uniforms:       crtUniforms,
  vertexShader:   vertCRT,
  fragmentShader: fragCRT,
  depthTest:  false,
  depthWrite: false,
});

var quadScene  = new THREE.Scene();
var quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
quadScene.add(new THREE.Mesh(new THREE.PlaneGeometry(2, 2), crtMat));

/* ── apply effect toggles ────────────────────────────────────── */
var grainEnabled  = P.grain_intensity > 0;
var chromaEnabled = P.chroma > 0;
var scanEnabled   = P.scanlines > 0;
var vigEnabled    = (P.vignette_darkness > 0) || (P.crt_vignette_power > 0);
var warbleEnabled = P.warble_amount > 0;

function applyCRT() {
  crtUniforms.uGrain.value       = grainEnabled  ? P.grain_intensity    : 0.0;
  crtUniforms.uChroma.value      = chromaEnabled ? P.chroma             : 0.0;
  crtUniforms.uScanlines.value   = scanEnabled   ? P.scanlines          : 0.0;
  crtUniforms.uVignette.value    = vigEnabled    ? P.vignette_darkness  : 0.0;
  crtUniforms.uCrtVigPower.value = vigEnabled    ? P.crt_vignette_power : 0.0;
  crtUniforms.uWarble.value      = warbleEnabled ? P.warble_amount      : 0.0;
}
applyCRT();

// Init pixel target after crtUniforms exist
makePixelTarget(pixelScale);

/* ── PS1 model material helpers ──────────────────────────────── */
var root         = null;
var snapEnabled  = P.snap_vertices;
var ditherEnabled= P.use_dither;
var autoRotate   = true;

// Compute sun direction from pitch/yaw (same formula as Three.js light + Godot export)
var _pitch = P.sun_pitch * Math.PI / 180;
var _yaw   = P.sun_yaw   * Math.PI / 180;
var _sunDir = new THREE.Vector3(
  Math.cos(_pitch)*Math.sin(_yaw),
  Math.sin(_pitch),
  Math.cos(_pitch)*Math.cos(_yaw)
).normalize();

function makeUniforms3d() {
  return {
    map:          {value: null},
    snapVertices: {value: snapEnabled},
    useDither:    {value: ditherEnabled},
    ditherGamma:  {value: P.dither_gamma},
    exposure:     {value: P.exposure},
    brightness:   {value: P.brightness},
    contrast:     {value: P.contrast},
    uSunDir:      {value: _sunDir},
    uSunInt:      {value: P.sun_intensity},
    uAmbient:     {value: P.ambient},
  };
}

function applyPSX(model) {
  model.traverse(function(c) {
    if (!c.isMesh) return;
    var map = (c.material && c.material.map) ? c.material.map : null;
    if (c.material) c.material.dispose();
    var u = makeUniforms3d();
    u.map.value = map;
    c.material = new THREE.ShaderMaterial({
      uniforms:       u,
      vertexShader:   vert3d,
      fragmentShader: frag3d,
      side:           THREE.FrontSide,
    });
  });
}

/* ── load GLB ────────────────────────────────────────────────── */
function b64ToBuffer(b64) {
  var bin = atob(b64), buf = new ArrayBuffer(bin.length), u8 = new Uint8Array(buf);
  for (var i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  return buf;
}
new THREE.GLTFLoader().parse(b64ToBuffer(GLB), '', function(gltf) {
  root = gltf.scene;
  applyPSX(root);
  var box  = new THREE.Box3().setFromObject(root);
  var ctr  = box.getCenter(new THREE.Vector3());
  var sz   = box.getSize(new THREE.Vector3());
  var maxD = Math.max(sz.x, sz.y, sz.z) || 1;
  root.position.sub(ctr);
  camera.position.set(0, maxD*0.15, maxD*1.9);
  camera.near = maxD*0.001;
  camera.far  = maxD*50;
  camera.updateProjectionMatrix();
  controls.target.set(0, 0, 0);
  scene.add(root);
}, function(e){console.error('[lofi-scan]', e);});

/* ── UI toggles ──────────────────────────────────────────────── */
function tog(id, get, set) {
  document.getElementById(id).addEventListener('click', function(){
    set(!get()); this.classList.toggle('on', get());
  });
}

// Rotate
document.getElementById('b-rotate').addEventListener('click', function(){
  autoRotate = !autoRotate; this.classList.toggle('on', autoRotate);
});

// Pixelate — rebuild render target on toggle
tog('b-pixel', function(){return pixelEnabled;}, function(v){
  pixelEnabled = v;
  makePixelTarget(pixelEnabled ? (P.pixelate_scale || 0.15) : 1.0);
});

// Snap / Dither — update all mesh uniforms
function setMeshUniform(key, val) {
  if (!root) return;
  root.traverse(function(c){
    if (c.isMesh && c.material.uniforms && c.material.uniforms[key])
      c.material.uniforms[key].value = val;
  });
}
tog('b-snap',   function(){return snapEnabled;},   function(v){snapEnabled=v;   setMeshUniform('snapVertices',v);});
tog('b-dither', function(){return ditherEnabled;}, function(v){ditherEnabled=v; setMeshUniform('useDither',v);});

// CRT effects
tog('b-grain',  function(){return grainEnabled;},  function(v){grainEnabled=v;  applyCRT();});
tog('b-chroma', function(){return chromaEnabled;}, function(v){chromaEnabled=v; applyCRT();});
tog('b-scan',   function(){return scanEnabled;},   function(v){scanEnabled=v;   applyCRT();});
tog('b-vig',    function(){return vigEnabled;},    function(v){vigEnabled=v;    applyCRT();});
tog('b-warble', function(){return warbleEnabled;}, function(v){warbleEnabled=v; applyCRT();});

/* ── render loop ─────────────────────────────────────────────── */
var clock = new THREE.Clock();
function animate() {
  requestAnimationFrame(animate);
  crtUniforms.uTime.value = clock.getElapsedTime();
  if (autoRotate && root) root.rotation.y += 0.004;
  controls.update();

  // Pass 1: 3-D scene → low-res pixel target
  renderer.setRenderTarget(pixelTarget);
  renderer.clear();
  renderer.render(scene, camera);

  // Pass 2: CRT quad → screen
  renderer.setRenderTarget(null);
  renderer.clear();
  renderer.render(quadScene, quadCamera);
}
animate();

/* ── resize ──────────────────────────────────────────────────── */
window.addEventListener('resize', function(){
  W = window.innerWidth; H = window.innerHeight;
  camera.aspect = W/H;
  camera.updateProjectionMatrix();
  renderer.setSize(W, H);
  crtUniforms.uRes.value.set(W, H);
  makePixelTarget(pixelEnabled ? (P.pixelate_scale || 0.15) : 1.0);
});
</script>
</body>
</html>
"""


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 gen_html.py config.json")
        sys.exit(1)
    with open(sys.argv[1]) as f:
        cfg = json.load(f)

    input_glb   = cfg["input_glb"]
    output_html = cfg["output_html"]
    model_name  = cfg.get("model_name", "lofi-scan viewer")

    with open(input_glb, "rb") as f:
        glb_bytes = f.read()

    min_tex = int(cfg.get("min_texture_size", 0))
    if min_tex > 0:
        glb_bytes = _upscale_glb_textures(glb_bytes, min_tex)

    glb_b64 = base64.b64encode(glb_bytes).decode("ascii")

    params = {
        "exposure":           cfg.get("exposure",           1.0),
        "brightness":         cfg.get("brightness",          1.0),
        "contrast":           cfg.get("contrast",            1.0),
        "use_dither":         bool(cfg.get("use_dither",     True)),
        "dither_gamma":       cfg.get("dither_gamma",        1.0),
        "snap_vertices":      bool(cfg.get("snap_vertices",  True)),
        "pixelate":           bool(cfg.get("pixelate",       False)),
        "pixelate_scale":     cfg.get("pixelate_scale",      0.15),
        "sun_intensity":      cfg.get("sun_intensity",       2.0),
        "sun_pitch":          cfg.get("sun_pitch",           -45.0),
        "sun_yaw":            cfg.get("sun_yaw",              45.0),
        "ambient":            cfg.get("ambient",              0.2),
        "grain_intensity":    cfg.get("grain_intensity",      0.0),
        "chroma":             cfg.get("chroma",               0.0),
        "scanlines":          cfg.get("scanlines",            0.0),
        "vignette_darkness":  cfg.get("vignette_darkness",   0.0),
        "crt_vignette_power": cfg.get("crt_vignette_power",  0.0),
        "warble_amount":      cfg.get("warble_amount",        0.0),
        "warble_speed":       cfg.get("warble_speed",         5.0),
        "bg_color":           cfg.get("bg_color",             [0.102, 0.102, 0.102]),
    }

    def _on(val) -> str:
        return "on" if val else ""

    html = TEMPLATE
    html = html.replace("__TITLE__",      model_name)
    html = html.replace("__PARAMS__",     json.dumps(params))
    html = html.replace("__GLB_B64__",    glb_b64)
    html = html.replace("__PIXEL_ON__",   _on(params["pixelate"]))
    html = html.replace("__SNAP_ON__",    _on(params["snap_vertices"]))
    html = html.replace("__DITHER_ON__",  _on(params["use_dither"]))
    html = html.replace("__GRAIN_ON__",   _on(params["grain_intensity"] > 0))
    html = html.replace("__CHROMA_ON__",  _on(params["chroma"] > 0))
    html = html.replace("__SCAN_ON__",    _on(params["scanlines"] > 0))
    html = html.replace("__VIG_ON__",     _on(params["vignette_darkness"] > 0
                                               or params["crt_vignette_power"] > 0))
    html = html.replace("__WARBLE_ON__",  _on(params["warble_amount"] > 0))

    with open(output_html, "w", encoding="utf-8") as f:
        f.write(html)

    size_kb = len(html.encode("utf-8")) / 1024
    print(f"[gen_html] Saved → {output_html}  ({size_kb:.0f} KB)")


main()
