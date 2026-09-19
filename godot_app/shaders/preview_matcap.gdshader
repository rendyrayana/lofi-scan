// Mathematical clay matcap for low-poly preview — no texture needed.
// NORMAL in fragment is view-space, so highlights follow the camera (true matcap behaviour).
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	vec3 n = normalize(NORMAL);

	// Primary key light (upper-left in view space)
	vec3 L = normalize(vec3(-0.4, 0.8, 0.5));
	float diffuse = max(dot(n, L), 0.0);

	// Soft specular
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L + V);
	float spec = pow(max(dot(n, H), 0.0), 80.0);

	// Warm fill from the right
	vec3 Lf = normalize(vec3(0.7, 0.2, 0.5));
	float fill = max(dot(n, Lf), 0.0) * 0.22;

	// Fake cavity / AO: faces angled away from the camera (low n.z) are darker
	float ao = mix(0.42, 1.0, pow(abs(n.z), 0.4));

	// Neutral clay: slightly warm off-white
	vec3 clay = vec3(0.76, 0.72, 0.68);

	vec3 color = clay * (0.15 + diffuse * 0.72 + fill) * ao;
	color += vec3(1.0, 0.98, 0.95) * spec * 0.55;

	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
}
