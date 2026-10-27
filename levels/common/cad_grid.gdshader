shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// CAD Drafting Grid Shader (Monochrome Architectural Line Art)
// Процедурный трипланарный шейдер архитектурной координатной сетки чертежа.

uniform vec4 background_color : source_color = vec4(0.94, 0.94, 0.95, 1.0);
uniform vec4 grid_color : source_color = vec4(0.18, 0.20, 0.22, 1.0);
uniform vec4 subgrid_color : source_color = vec4(0.75, 0.77, 0.80, 1.0);

uniform float grid_size : hint_range(0.1, 10.0) = 1.0;
uniform float subgrid_divisions : hint_range(1.0, 10.0) = 5.0;
uniform float line_width : hint_range(0.001, 0.1) = 0.018;
uniform float subline_width : hint_range(0.001, 0.05) = 0.008;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

// Вычисление интенсивности линии сетки в 2D координатах с экранным сглаживанием
float get_grid_line(vec2 uv, float spacing, float width) {
	vec2 coord = uv / spacing;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) * spacing;
	vec2 fw = fwidth(uv) * 1.5;
	vec2 line_factor = 1.0 - smoothstep(vec2(0.0), fw + vec2(width), grid - vec2(width * 0.5));
	return clamp(max(line_factor.x, line_factor.y), 0.0, 1.0);
}

void fragment() {
	// Трипланарные веса смешивания граней с резким переходом (pow 8)
	vec3 blend_weights = pow(abs(world_normal), vec3(8.0));
	blend_weights /= max(blend_weights.x + blend_weights.y + blend_weights.z, 0.0001);

	// Проекции на три координатные плоскости
	float sub_spacing = grid_size / subgrid_divisions;

	// XZ (пол и потолок)
	float main_xz = get_grid_line(world_pos.xz, grid_size, line_width);
	float sub_xz = get_grid_line(world_pos.xz, sub_spacing, subline_width);

	// XY (стены с нормалью по Z)
	float main_xy = get_grid_line(world_pos.xy, grid_size, line_width);
	float sub_xy = get_grid_line(world_pos.xy, sub_spacing, subline_width);

	// YZ (стены с нормалью по X)
	float main_yz = get_grid_line(world_pos.yz, grid_size, line_width);
	float sub_yz = get_grid_line(world_pos.yz, sub_spacing, subline_width);

	float main_grid = main_yz * blend_weights.x + main_xz * blend_weights.y + main_xy * blend_weights.z;
	float sub_grid = sub_yz * blend_weights.x + sub_xz * blend_weights.y + sub_xy * blend_weights.z;

	// Плавное затухание сетки по дистанции от камеры для устранения муара и ряби вдалеке
	float dist_to_cam = length(world_pos - INV_VIEW_MATRIX[3].xyz);
	float sub_fade = 1.0 - smoothstep(10.0, 20.0, dist_to_cam);
	sub_grid *= sub_fade;

	float main_fade = 1.0 - smoothstep(25.0, 50.0, dist_to_cam) * 0.75;
	main_grid *= main_fade;

	// Смешивание цветов: бумага -> вспомогательная сетка -> основная сетка
	vec3 color = mix(background_color.rgb, subgrid_color.rgb, sub_grid);
	color = mix(color, grid_color.rgb, main_grid);

	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
