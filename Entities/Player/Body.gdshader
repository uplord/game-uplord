shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 20.0, 0.1) = 2.0;
uniform float scale_factor = 1.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

void fragment() {
    vec4 col = texture(screen_texture, SCREEN_UV);

    vec2 ps = SCREEN_PIXEL_SIZE;

    // keep outline 4px at scale = 1
    float width = outline_width;

    // OPTIONAL: comment this out if you DON'T want scaling to affect outline
    width *= scale_factor;

    vec2 offset = ps * width;

    float maxa = col.a;

    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2( offset.x, 0.0)).a);
    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2(-offset.x, 0.0)).a);
    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2(0.0, offset.y)).a);
    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2(0.0,-offset.y)).a);

    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2( offset.x, offset.y)).a);
    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2(-offset.x, offset.y)).a);
    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2( offset.x,-offset.y)).a);
    maxa = max(maxa, texture(screen_texture, SCREEN_UV + vec2(-offset.x,-offset.y)).a);

    if (col.a == 0.0 && maxa > 0.0) {
        COLOR = outline_color;
    } else {
        COLOR = col;
    }
}