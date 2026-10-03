shader_type canvas_item;

uniform float inner : hint_range(0.0, 1.0) = 0.3;
uniform float outer : hint_range(0.0, 1.0) = 0.5;

uniform vec4 dot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 0.5;
uniform float size : hint_range(0.001, 0.5) = 0.05;
uniform float intensity = 3.0;

void fragment() {
	float edge = 1.0 - abs(UV.y - 0.5) * 2.0;
	COLOR.a *= smoothstep(inner, outer, edge);
	
	float pos = fract(TIME * speed);
	float d = (UV.x - pos) / size;
	float glow = exp(-d * d);
	COLOR.rgb += dot_color.rgb * glow * intensity;
}
