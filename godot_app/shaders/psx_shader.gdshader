shader_type spatial;
render_mode skip_vertex_transform, specular_disabled;

// --- Surface ---
uniform sampler2D albedo_map : source_color, filter_nearest, repeat_disable;
uniform vec3 color_tint : source_color = vec3(1.0);
uniform bool use_billboard = false;

// --- PS1 Geometry ---
uniform bool snap_vertices = true;
uniform bool use_affine_uv = true;

// --- PS1 Lighting ---
uniform bool dynamic_lighting = false;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float sun_intensity = 1.0;
uniform vec3 fill_light : source_color = vec3(0.0);

// --- PS1 Color ---
uniform bool use_dither = true;
uniform float dither_gamma = 1.0;

// --- Fog ---
uniform bool use_fog = false;
uniform vec3 fog_tint : source_color = vec3(0.42, 0.42, 0.45);
uniform vec2 fog_range = vec2(10.0, 100.0);

varying vec4 screen_pos;
varying float fog_amount;

void vertex() {
    mat4 world_mat = MODEL_MATRIX;

    if (use_billboard) {
        world_mat = mat4(
            normalize(INV_VIEW_MATRIX[0]),
            vec4(0.0, 1.0, 0.0, 0.0),
            normalize(INV_VIEW_MATRIX[2]),
            MODEL_MATRIX[3]
        );
        MODELVIEW_MATRIX = VIEW_MATRIX * world_mat;
        MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
    }

    vec4 world_pos = world_mat * vec4(VERTEX, 1.0);
    vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * world_pos;

    // PS1 integer vertex snapping
    if (snap_vertices) {
        vec2 half_res = VIEWPORT_SIZE.xy * 0.5;
        clip.xy = round(clip.xy / clip.w * half_res) / half_res * clip.w;
    }

    POSITION = clip;
    screen_pos = clip;

    // Distance fog factor
    float cam_dist = length(CAMERA_POSITION_WORLD - world_pos.xyz);
    float raw_fog = (fog_range.y - cam_dist) / (fog_range.y - fog_range.x);
    fog_amount = 1.0 - clamp(raw_fog, 0.0, 1.0);

    // Vertex lighting (Gouraud)
    NORMAL = MODEL_NORMAL_MATRIX * NORMAL;
    if (dynamic_lighting) {
        float n_dot_l = clamp(dot(NORMAL, normalize(sun_direction)), 0.0, 1.0);
        vec3 lit = fill_light + n_dot_l * sun_intensity;
        COLOR.rgb *= clamp(lit, vec3(0.0), vec3(1.0));
    }

    // Affine UV — multiply here, divide in fragment
    if (use_affine_uv) {
        UV *= screen_pos.w;
        COLOR *= screen_pos.w;
        fog_amount *= screen_pos.w;
    }
}

void fragment() {
    vec2 uv = UV;
    vec3 lighting = COLOR.rgb;
    float fog = fog_amount;

    // Reverse affine correction
    if (use_affine_uv) {
        float inv_w = 1.0 / screen_pos.w;
        uv *= inv_w;
        lighting *= inv_w;
        fog *= inv_w;
    }

    vec3 surface = texture(albedo_map, uv).rgb * lighting * color_tint;

    // Fog blend
    if (use_fog) {
        surface = clamp(mix(surface, fog_tint, fog), 0.0, 1.0);
    }

    // PS1 15-bit dithering
    // Dither matrix sourced from: psx-spx.consoledev.net/graphicsprocessingunitgpu
    if (use_dither) {
        const int bayer[16] = {
            -4,  0, -3,  1,
             2, -2,  3, -1,
            -3,  1, -4,  0,
             3, -1,  2, -2
        };

        int bx = int(FRAGCOORD.x) % 4;
        int by = int(FRAGCOORD.y) % 4;
        float offset = float(bayer[bx + by * 4]);

        // Gamma → quantize to 5-bit per channel → back to linear
        vec3 gamma_col = pow(surface, vec3(1.0 / dither_gamma));
        vec3 shifted = gamma_col * 255.0 + offset;
        vec3 clamped = clamp(round(shifted), vec3(0.0), vec3(255.0));
        vec3 quantized = clamp(clamped / 8.0, vec3(0.0), vec3(31.0)) / 31.0;
        surface = pow(quantized, vec3(dither_gamma));
    }

    ALBEDO = surface;
}

void light() {
    DIFFUSE_LIGHT = vec3(1.0);
    SPECULAR_LIGHT = vec3(0.0);
}
