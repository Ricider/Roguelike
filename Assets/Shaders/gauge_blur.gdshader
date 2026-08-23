shader_type canvas_item;

// Blurry soft edges for gauge background
uniform float edge_soft : hint_range(0.0, 0.5) = 0.18;
uniform float blur_radius : hint_range(0.0, 0.03) = 0.012;

void fragment() {
    vec2 uv = UV;
    float dx = min(uv.x, 1.0 - uv.x);
    float dy = min(uv.y, 1.0 - uv.y);
    float d = min(dx, dy);
    float edge_fade = smoothstep(0.0, edge_soft, d);
    vec4 col = texture(TEXTURE, uv);
    // box blur only near edges to keep center sharp and save perf
    if (d < edge_soft) {
        vec4 sum = vec4(0.0);
        sum += texture(TEXTURE, uv + vec2(-blur_radius, 0.0));
        sum += texture(TEXTURE, uv + vec2( blur_radius, 0.0));
        sum += texture(TEXTURE, uv + vec2(0.0, -blur_radius));
        sum += texture(TEXTURE, uv + vec2(0.0,  blur_radius));
        sum += texture(TEXTURE, uv + vec2(-blur_radius, -blur_radius) * 0.7);
        sum += texture(TEXTURE, uv + vec2( blur_radius,  blur_radius) * 0.7);
        sum += texture(TEXTURE, uv + vec2(-blur_radius,  blur_radius) * 0.7);
        sum += texture(TEXTURE, uv + vec2( blur_radius, -blur_radius) * 0.7);
        sum += col;
        col = sum / 9.0;
    }
    col.a *= edge_fade;
    COLOR = col;
}
