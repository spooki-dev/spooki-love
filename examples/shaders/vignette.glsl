// Darkens the edges of the screen. `strength` 0..1 is sent every frame from the
// scene's updateShaderUniforms hook via the shader definition's sendUniforms.
extern float strength;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
  vec4 px = Texel(tex, uv) * color;
  float d = distance(uv, vec2(0.5, 0.5));
  float v = smoothstep(0.3, 0.85, d) * strength;
  px.rgb *= 1.0 - v;
  return px;
}
