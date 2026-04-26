shader_type canvas_item;

uniform vec4 skin_color : source_color = vec4(0.6, 0.4, 0.2, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

    vec3 final_color;

    if (brightness < 0.1 || brightness > 0.9) {
        final_color = tex.rgb;
    } else {
        final_color = mix(vec3(0.0), skin_color.rgb, brightness * 1.2);
    }

    COLOR = vec4(final_color, tex.a);
}