local CRT = {}

CRT.name = "CRT"
CRT.enabled = true

CRT.shader = love.graphics.newShader([[
  extern vec2 resolution;
  extern float time;
  extern float signalStrength; // 0.0 = full interference, 1.0 = clean picture

  vec2 barrelDistort(vec2 uv, float interference) {
    vec2 cc = uv - 0.5;
    float dist = dot(cc, cc);
    float strength = 0.1 + interference * 0.15;
    return uv + cc * dist * strength;
  }

  // Pseudo-random hash
  float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }

  vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 pc) {
    float interference = 1.0 - signalStrength;

    vec2 uv = barrelDistort(tc, interference);

    // Static horizontal jitter — shifts scanlines sideways
    float jitter = interference * 0.01 * sin(time * 50.0 + uv.y * 200.0);
    uv.x += jitter;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
      return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // Chromatic aberration — increases with interference
    float aberration = 0.002 + interference * 0.008;
    float r = Texel(tex, vec2(uv.x + aberration, uv.y)).r;
    float g = Texel(tex, uv).g;
    float b = Texel(tex, vec2(uv.x - aberration, uv.y)).b;
    vec3 col = vec3(r, g, b);

    // Scanlines — deepen with interference
    float scanlineIntensity = 0.04 + interference * 0.12;
    float scanline = sin(uv.y * resolution.y * 3.14159) * scanlineIntensity;
    col -= scanline;

    // Static noise grain — scales with interference
    float noise = hash(uv * resolution + vec2(time * 100.0)) * interference * 0.3;
    col += vec3(noise);

    // Rolling bar — a dark band that scrolls down the screen
    if (interference > 0.3) {
      float barStrength = (interference - 0.3) / 0.7;
      float bar = smoothstep(0.0, 0.05, abs(fract(uv.y - time * 0.15) - 0.5) - 0.1);
      col *= mix(1.0, bar, barStrength * 0.4);
    }

    // Vignette — tightens with interference
    float vignette = length(uv - 0.5);
    col *= 1.0 - vignette * (0.5 + interference * 0.5);

    // Phosphor glow
    col *= 1.0 + 0.01 * sin(time * 2.0);

    return vec4(col, 1.0) * colour;
  }
]])

---@param shader love.Shader
---@param time number
---@param w number
---@param h number
---@param uniforms table|nil Extra uniforms from PostProcessing
function CRT.sendUniforms(shader, time, w, h, uniforms)
  shader:send("resolution", { w, h })
  shader:send("time", time)
  shader:send("signalStrength", uniforms and uniforms.signalStrength or 1.0)
end

return CRT
