shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, fog_disabled;

// Architectural Line Art / Technical Illustration Edge Detection
// Детекция нормалей (Собель 3х3) + Детекция глубины по касательной плоскости (Tangent-Plane Distance)
// Оптимизировано: кэширование 9 выборок глубины на пиксель + сглаживание силуэта неба (антиалиасинг)

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, filter_linear;

uniform vec4 line_color : source_color = vec4(0.08, 0.09, 0.10, 1.0);
uniform float line_width : hint_range(0.5, 3.0) = 1.25;
uniform float normal_threshold : hint_range(0.05, 0.8) = 0.28;
uniform float normal_smoothing : hint_range(0.01, 0.3) = 0.14;
uniform float depth_base_threshold : hint_range(0.002, 0.05) = 0.008;
uniform float depth_distance_factor : hint_range(0.0005, 0.01) = 0.0025;
uniform float depth_smoothing : hint_range(0.002, 0.05) = 0.015;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Реконструкция позиции в пространстве вида из кэшированной сырой глубины (без повторного чтения текстуры)
vec3 reconstruct_view_pos(vec2 uv, float raw_depth, mat4 inv_proj) {
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
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

	// 1. Оптимизированная выборка глубины: ровно 9 сэмплов на весь шейдер (сокращение с 26 до 9)
	float raw_c  = texture(depth_texture, SCREEN_UV).x;
	float raw_tl = texture(depth_texture, uv_tl).x;
	float raw_t  = texture(depth_texture, uv_t ).x;
	float raw_tr = texture(depth_texture, uv_tr).x;
	float raw_l  = texture(depth_texture, uv_l ).x;
	float raw_r  = texture(depth_texture, uv_r ).x;
	float raw_bl = texture(depth_texture, uv_bl).x;
	float raw_b  = texture(depth_texture, uv_b ).x;
	float raw_br = texture(depth_texture, uv_br).x;

	// 2. Детекция нормалей (Собель 3x3) — стыки деталей оружия, грани колонн, углы 90°
	// Соседи из неба подменяются нормалью центрального пикселя, чтобы граница неба не вызывала ложный контур нормалей
	vec3 n_c  = texture(normal_roughness_texture, SCREEN_UV).xyz * 2.0 - 1.0;
	float normal_edge = 0.0;
	if (raw_c > 0.00001) {
		vec3 n_tl = raw_tl > 0.00001 ? (texture(normal_roughness_texture, uv_tl).xyz * 2.0 - 1.0) : n_c;
		vec3 n_t  = raw_t  > 0.00001 ? (texture(normal_roughness_texture, uv_t ).xyz * 2.0 - 1.0) : n_c;
		vec3 n_tr = raw_tr > 0.00001 ? (texture(normal_roughness_texture, uv_tr).xyz * 2.0 - 1.0) : n_c;
		vec3 n_l  = raw_l  > 0.00001 ? (texture(normal_roughness_texture, uv_l ).xyz * 2.0 - 1.0) : n_c;
		vec3 n_r  = raw_r  > 0.00001 ? (texture(normal_roughness_texture, uv_r ).xyz * 2.0 - 1.0) : n_c;
		vec3 n_bl = raw_bl > 0.00001 ? (texture(normal_roughness_texture, uv_bl).xyz * 2.0 - 1.0) : n_c;
		vec3 n_b  = raw_b  > 0.00001 ? (texture(normal_roughness_texture, uv_b ).xyz * 2.0 - 1.0) : n_c;
		vec3 n_br = raw_br > 0.00001 ? (texture(normal_roughness_texture, uv_br).xyz * 2.0 - 1.0) : n_c;

		vec3 n_gx = ((n_tr + 2.0 * n_r + n_br) - (n_tl + 2.0 * n_l + n_bl)) * 0.25;
		vec3 n_gy = ((n_bl + 2.0 * n_b + n_br) - (n_tl + 2.0 * n_t + n_tr)) * 0.25;
		float normal_grad = sqrt(dot(n_gx, n_gx) + dot(n_gy, n_gy));
		float n_smooth = max(normal_smoothing, fwidth(normal_grad) * 1.5);
		normal_edge = smoothstep(normal_threshold, normal_threshold + n_smooth, normal_grad);
	}

	// 3. Детекция глубины методом расстояния до касательной плоскости (Tangent-Plane Distance)
	// На плоском полу, потолке и стенах расстояние до плоскости математически равно 0 независимо от дистанции и угла!
	// На перепадах глубины (силуэты столбов, выступающая дверь 20 см на стене 30 м, стыки оружия) расстояние равно реальному перепаду.
	float depth_edge = 0.0;
	if (raw_c > 0.00001) {
		vec3 p_c  = reconstruct_view_pos(SCREEN_UV, raw_c, INV_PROJECTION_MATRIX);
		vec3 p_tl = raw_tl > 0.00001 ? reconstruct_view_pos(uv_tl, raw_tl, INV_PROJECTION_MATRIX) : p_c;
		vec3 p_t  = raw_t  > 0.00001 ? reconstruct_view_pos(uv_t,  raw_t,  INV_PROJECTION_MATRIX) : p_c;
		vec3 p_tr = raw_tr > 0.00001 ? reconstruct_view_pos(uv_tr, raw_tr, INV_PROJECTION_MATRIX) : p_c;
		vec3 p_l  = raw_l  > 0.00001 ? reconstruct_view_pos(uv_l,  raw_l,  INV_PROJECTION_MATRIX) : p_c;
		vec3 p_r  = raw_r  > 0.00001 ? reconstruct_view_pos(uv_r,  raw_r,  INV_PROJECTION_MATRIX) : p_c;
		vec3 p_bl = raw_bl > 0.00001 ? reconstruct_view_pos(uv_bl, raw_bl, INV_PROJECTION_MATRIX) : p_c;
		vec3 p_b  = raw_b  > 0.00001 ? reconstruct_view_pos(uv_b,  raw_b,  INV_PROJECTION_MATRIX) : p_c;
		vec3 p_br = raw_br > 0.00001 ? reconstruct_view_pos(uv_br, raw_br, INV_PROJECTION_MATRIX) : p_c;

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
		float d_smooth = max(depth_smoothing, fwidth(max_plane_dist) * 1.5);
		depth_edge = smoothstep(depth_thresh, depth_thresh + d_smooth, max_plane_dist);
	}

	// 4. Сглаженный силуэт против неба (Reverse-Z: глубина неба <= 0.00001)
	// Устранение «лесенок» (ступенчатого алиасинга) на силуэтах зданий против неба:
	// вычисляем субпиксельное взвешенное покрытие геометрии и градиент Собеля
	float s_tl = raw_tl > 0.00001 ? 1.0 : 0.0;
	float s_t  = raw_t  > 0.00001 ? 1.0 : 0.0;
	float s_tr = raw_tr > 0.00001 ? 1.0 : 0.0;
	float s_l  = raw_l  > 0.00001 ? 1.0 : 0.0;
	float s_c  = raw_c  > 0.00001 ? 1.0 : 0.0;
	float s_r  = raw_r  > 0.00001 ? 1.0 : 0.0;
	float s_bl = raw_bl > 0.00001 ? 1.0 : 0.0;
	float s_b  = raw_b  > 0.00001 ? 1.0 : 0.0;
	float s_br = raw_br > 0.00001 ? 1.0 : 0.0;

	float geom_coverage = (s_tl + s_tr + s_bl + s_br) * 0.0625 + (s_t + s_l + s_r + s_b) * 0.125 + s_c * 0.25;

	float s_gx = ((s_tr + 2.0 * s_r + s_br) - (s_tl + 2.0 * s_l + s_bl)) * 0.25;
	float s_gy = ((s_bl + 2.0 * s_b + s_br) - (s_tl + 2.0 * s_t + s_tr)) * 0.25;
	float s_grad = sqrt(s_gx * s_gx + s_gy * s_gy);

	float sky_edge = 0.0;
	if (geom_coverage > 0.001 && geom_coverage < 0.999) {
		float coverage_factor = clamp(1.0 - abs(geom_coverage - 0.5) * 2.0, 0.0, 1.0);
		sky_edge = smoothstep(0.1, 0.6, s_grad) * clamp(coverage_factor * 1.5, 0.0, 1.0);
	}

	// Итоговый контур
	float edge = clamp(max(max(normal_edge, depth_edge), sky_edge), 0.0, 1.0);

	ALBEDO = line_color.rgb;
	ALPHA = edge * line_color.a;
}
