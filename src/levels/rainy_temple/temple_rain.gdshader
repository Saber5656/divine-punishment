shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;

uniform int roof_count = 0;
uniform vec4 roof_rects[16];
uniform float roof_heights[16];
varying vec3 drop_position;

void vertex() {
    // Face the camera while retaining each particle's world-space translation.
    mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_MATRIX = VIEW_MATRIX * facing;
    drop_position = (facing * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    for (int i = 0; i < 16; i++) {
        if (i >= roof_count) { break; }
        vec4 roof = roof_rects[i];
        if (drop_position.y < roof_heights[i] &&
            drop_position.x >= roof.x && drop_position.x <= roof.z &&
            drop_position.z >= roof.y && drop_position.z <= roof.w) {
            discard;
        }
    }
    ALBEDO = vec3(0.65, 0.75, 0.9);
    ALPHA = 0.45;
}
