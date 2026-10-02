// CRT-style scanlines plus a slow rolling brightness band driven by `time`.
extern float time;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
  vec4 px = Texel(tex, uv) * color;
  float line = mod(floor(screen_coords.y), 2.0) == 0.0 ? 0.78 : 1.0;
  float band = 0.08 * sin(uv.y * 8.0 - time * 1.5);
  px.rgb = px.rgb * line + band;
  return px;
}
