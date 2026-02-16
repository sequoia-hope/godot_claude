shader_type canvas_item;
render_mode unshaded;

// Fisheye / barrel distortion shader
// Creates the characteristic bulging effect of wide-angle lenses
// Used with SubViewportContainer for proper post-processing

uniform float distortion_strength : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Convert UV to centered coordinates (-1 to 1)
	vec2 centered_uv = UV * 2.0 - 1.0;

	// Calculate distance from center
	float dist = length(centered_uv);

	// Barrel distortion formula: r_distorted = r * (1 + k * r^2)
	float distorted_dist = dist * (1.0 + distortion_strength * dist * dist);

	// Apply distortion
	vec2 distorted_uv;
	if (dist > 0.0) {
		distorted_uv = centered_uv * (distorted_dist / dist);
	} else {
		distorted_uv = centered_uv;
	}

	// Convert back to 0-1 range
	distorted_uv = (distorted_uv + 1.0) / 2.0;

	// Sample with black edges for out-of-bounds
	if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 ||
		distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = texture(TEXTURE, distorted_uv);
	}

	// Apply vignette for more realistic fisheye look
	float vignette = 1.0 - dist * vignette_strength;
	COLOR.rgb *= vignette;
}
