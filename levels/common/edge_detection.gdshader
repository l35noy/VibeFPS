shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, fog_disabled;

// Architectural Line Art / Technical Illustration Edge Detection
// Детекция нормалей (Собель 3х3) + Детекция глубины по касательной плоскости (Tangent-Plane Distance)

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, filter_nearest;

uniform vec4 line_color : source_color = vec4(0.08, 0.09, 0.10, 1.0);
uniform float line_width : hint_range(0.5, 3.0) = 1.0;
uniform float normal_threshold : hint_range(0.05, 0.8) = 0.28;
uniform float normal_smoothing : hint_range(0.01, 0.3) = 0.08;
uniform float depth_base_threshold : hint_range(0.002, 0.05) = 0.008;
uniform float depth_distance_factor : hint_range(0.0005, 0.01) = 0.0025;
uniform float depth_smoothing : hint_range(0.002, 0.05) = 0.008;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 get_view_pos(vec2 uv, mat4 inv_proj) {
	float raw = texture(depth_texture, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return view.xyz / max(view.w, 0.00001);
}

void fragment() {
	vec2 texel = (1.0 / VIEWPORT_SIZE) * line_width;

	// Координаты окрестности 3x3
	vec2 uv_tl = SCREEN_UV + vec2(-texel.x, -texel.y);
	vec2 uv_t  = SCREEN_UV + vec2( 0.0,     -texel.y);
	vec2 uv_tr = SCREEN_UV + vec2( texel.x, -texel.y);
	vec2 uv_l  = SCREEN_UV + vec2(-texel.x,  0.0);
	vec2 uv_r  = SCREEN_UV + vec2( texel.x,  0.0);
	vec2 uv_bl = SCREEN_UV + vec2(-texel.x,  texel.y);
	vec2 uv_b  = SCREEN_UV + vec2( 0.0,      texel.y);
	vec2 uv_br = SCREEN_UV + vec2( texel.x,  texel.y);

	// 1. Детекция нормалей (Собель 3x3) — стыки деталей оружия, грани колонн, углы 90°
	vec3 n_tl = texture(normal_roughness_texture, uv_tl).xyz * 2.0 - 1.0;
	vec3 n_t  = texture(normal_roughness_texture, uv_t ).xyz * 2.0 - 1.0;
	vec3 n_tr = texture(normal_roughness_texture, uv_tr).xyz * 2.0 - 1.0;
	vec3 n_l  = texture(normal_roughness_texture, uv_l ).xyz * 2.0 - 1.0;
	vec3 n_c  = texture(normal_roughness_texture, SCREEN_UV).xyz * 2.0 - 1.0;
	vec3 n_r  = texture(normal_roughness_texture, uv_r ).xyz * 2.0 - 1.0;
	vec3 n_bl = texture(normal_roughness_texture, uv_bl).xyz * 2.0 - 1.0;
	vec3 n_b  = texture(normal_roughness_texture, uv_b ).xyz * 2.0 - 1.0;
	vec3 n_br = texture(normal_roughness_texture, uv_br).xyz * 2.0 - 1.0;

	vec3 n_gx = ((n_tr + 2.0 * n_r + n_br) - (n_tl + 2.0 * n_l + n_bl)) * 0.25;
	vec3 n_gy = ((n_bl + 2.0 * n_b + n_br) - (n_tl + 2.0 * n_t + n_tr)) * 0.25;
	float normal_grad = sqrt(dot(n_gx, n_gx) + dot(n_gy, n_gy));
	float normal_edge = smoothstep(normal_threshold, normal_threshold + normal_smoothing, normal_grad);

	// 2. Детекция глубины методом расстояния до касательной плоскости (Tangent-Plane Distance)
	// На плоском полу, потолке и стенах расстояние до плоскости математически равно 0 независимо от дистанции и угла!
	// На перепадах глубины (силуэты столбов, выступающая дверь 20 см на стене 30 м, стыки оружия) расстояние равно реальному перепаду.
	float raw_c = texture(depth_texture, SCREEN_UV).x;
	float depth_edge = 0.0;

	vec3 p_c = get_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);

	if (raw_c > 0.00001) {
		vec3 p_tl = get_view_pos(uv_tl, INV_PROJECTION_MATRIX);
		vec3 p_t  = get_view_pos(uv_t,  INV_PROJECTION_MATRIX);
		vec3 p_tr = get_view_pos(uv_tr, INV_PROJECTION_MATRIX);
		vec3 p_l  = get_view_pos(uv_l,  INV_PROJECTION_MATRIX);
		vec3 p_r  = get_view_pos(uv_r,  INV_PROJECTION_MATRIX);
		vec3 p_bl = get_view_pos(uv_bl, INV_PROJECTION_MATRIX);
		vec3 p_b  = get_view_pos(uv_b,  INV_PROJECTION_MATRIX);
		vec3 p_br = get_view_pos(uv_br, INV_PROJECTION_MATRIX);

		// Проекция смещения соседей на нормаль центрального пикселя
		float d_tl = abs(dot(p_tl - p_c, n_c));
		float d_t  = abs(dot(p_t  - p_c, n_c));
		float d_tr = abs(dot(p_tr - p_c, n_c));
		float d_l  = abs(dot(p_l  - p_c, n_c));
		float d_r  = abs(dot(p_r  - p_c, n_c));
		float d_bl = abs(dot(p_bl - p_c, n_c));
		float d_b  = abs(dot(p_b  - p_c, n_c));
		float d_br = abs(dot(p_br - p_c, n_c));

		float max_plane_dist = max(max(max(d_tl, d_t), max(d_tr, d_l)),
		                           max(max(d_r, d_bl), max(d_b, d_br)));

		// Адаптивный порог: точный на близких дистанциях (оружие) и устойчивый к погрешностям буфера глубины на 30+ м
		float dist_to_cam = max(-p_c.z, 0.2);
		float depth_thresh = clamp(depth_base_threshold + depth_distance_factor * dist_to_cam, 0.008, 0.12);
		depth_edge = smoothstep(depth_thresh, depth_thresh + depth_smoothing, max_plane_dist);
	}

	// 3. Силуэт против неба (Reverse-Z: глубина неба <= 0.00001)
	float raw_min = min(min(min(texture(depth_texture, uv_tl).x, texture(depth_texture, uv_t).x),
	                        min(texture(depth_texture, uv_tr).x, texture(depth_texture, uv_l).x)),
	                    min(min(texture(depth_texture, uv_r).x,  texture(depth_texture, uv_bl).x),
	                        min(texture(depth_texture, uv_b).x,  texture(depth_texture, uv_br).x)));
	float raw_max = max(max(max(texture(depth_texture, uv_tl).x, texture(depth_texture, uv_t).x),
	                        max(texture(depth_texture, uv_tr).x, texture(depth_texture, uv_l).x)),
	                    max(max(texture(depth_texture, uv_r).x,  texture(depth_texture, uv_bl).x),
	                        max(texture(depth_texture, uv_b).x,  texture(depth_texture, uv_br).x)));

	float sky_edge = (raw_min <= 0.00001 && raw_max > 0.00001) ? 1.0 : 0.0;

	// Итоговый контур
	float edge = clamp(max(max(normal_edge, depth_edge), sky_edge), 0.0, 1.0);

	ALBEDO = line_color.rgb;
	ALPHA = edge * line_color.a;
}
