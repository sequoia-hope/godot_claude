shader_type canvas_item;

// Fisheye barrel distortion shader
// Strength controls the amount of distortion (0.0 = none, 1.0 = strong fisheye)
uniform float strength : hint_range(0.0, 2.0) = 0.8;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Get UV coordinates centered at (0,0) with range [-1, 1]
	vec2 uv = SCREEN_UV * 2.0 - 1.0;

	// Calculate distance from center
	float dist = length(uv);

	// Apply barrel distortion
	// Using a polynomial distortion model
	float distortion = 1.0 + dist * dist * strength;

	// Apply distortion to UV coordinates
	vec2 distorted_uv = uv / distortion;

	// Convert back to [0, 1] range
	distorted_uv = distorted_uv * 0.5 + 0.5;

	// Check if we're outside the valid texture range (creates circular vignette)
	if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 ||
		distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = texture(screen_texture, distorted_uv);
	}
}
