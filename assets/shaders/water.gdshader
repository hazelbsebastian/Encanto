shader_type spatial;
// Gentle stylised water: rolling vertex waves, depth-free colour gradient
// from shallow turquoise to deep blue, sparkly highlights. Works in the
// Compatibility renderer.

uniform vec4 shallow : source_color = vec4(0.36, 0.84, 0.82, 1.0);
uniform vec4 deep : source_color = vec4(0.07, 0.36, 0.58, 1.0);
uniform float wave_height = 0.18;
uniform float wave_scale = 0.18;
uniform float speed = 0.8;
uniform float alpha = 0.9;
uniform vec3 shore_center = vec3(0.0, 0.0, 0.0);
uniform float shore_radius = 30.0;
uniform float shore_fade = 60.0;

varying float v_dist;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	float h = sin(w.x * wave_scale + t) * 0.5 + sin(w.z * wave_scale * 1.3 + t * 1.2) * 0.35 + sin((w.x + w.z) * wave_scale * 2.1 - t * 1.7) * 0.15;
	VERTEX.y += h * wave_height;
	v_dist = length(w.xz - shore_center.xz);
	float dx = cos(w.x * wave_scale + t) * wave_scale * 0.5;
	float dz = cos(w.z * wave_scale * 1.3 + t * 1.2) * wave_scale * 0.45;
	NORMAL = normalize(vec3(-dx * wave_height * 4.0, 1.0, -dz * wave_height * 4.0));
}

void fragment() {
	float d = clamp((v_dist - shore_radius) / shore_fade, 0.0, 1.0);
	ALBEDO = mix(shallow.rgb, deep.rgb, d);
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.8;
	float sparkle = pow(max(0.0, sin(UV.x * 900.0 + TIME * 2.0) * sin(UV.y * 900.0 - TIME * 1.6)), 30.0);
	EMISSION = vec3(sparkle) * 0.6;
	ALPHA = alpha;
}
