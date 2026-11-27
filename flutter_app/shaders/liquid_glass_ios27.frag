#version 460 core
#include <flutter/runtime_effect.glsl>

// Pure GPU iOS 27 Liquid Glass optical surface shader:
// - Continuous Superellipse Squircle SDF for authentic Apple corner curvature
// - Optical edge prism dispersion & Fresnel specular highlight along curved bevel
// - Granular Clear <-> Tinted diffusion + press-reactive caustic gleam
// - iOS 27 darkened perimeter contrast edge framing for crisp separation
uniform vec2 uSize;
uniform float uRadius;
uniform float uOpacity;
uniform float uIsDark;
uniform float uPress;
uniform vec4 uTint;

out vec4 fragColor;

float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Smooth iOS continuous squircle SDF (blends superellipse n=4.2 on cards,
// seamlessly preserving circular/stadium pills when r approaches half-extent)
float sdLiquidSquircle(vec2 p, vec2 b, float r) {
  float minExtent = min(b.x, b.y);
  float pillBlend = smoothstep(minExtent * 0.72, minExtent * 0.96, r);
  float dRound = sdRoundedBox(p, b, r);
  if (pillBlend > 0.99) {
    return dRound;
  }
  vec2 cornerBox = max(b - vec2(r * 1.15), vec2(0.5));
  vec2 q = max(abs(p) - cornerBox, 0.0) / max(r * 1.15, 1.0);
  float pNorm = mix(4.2, 2.0, pillBlend);
  float superDist = (pow(pow(q.x, pNorm) + pow(q.y, pNorm), 1.0 / pNorm) - 1.0) * (r * 1.15);
  vec2 dBox = abs(p) - b;
  float interior = min(max(dBox.x, dBox.y), 0.0);
  float dSquircle = (q.x > 0.0 && q.y > 0.0) ? superDist : interior;
  return mix(dSquircle, dRound, 0.28 + 0.72 * pillBlend);
}

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 safeSize = max(uSize, vec2(2.0));
  vec2 halfSize = safeSize * 0.5;
  float maxR = min(halfSize.x, halfSize.y);
  float r = clamp(uRadius, 1.0, maxR);

  vec2 p = pos - halfSize;
  float d = sdLiquidSquircle(p, halfSize, r);

  // Smooth anti-aliased edge mask
  float aa = 1.0 - smoothstep(-0.75, 0.75, d);
  if (aa <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }

  // Analytical SDF gradient normal for optical bevel & specular reflection
  vec2 eps = vec2(1.0, 0.0);
  vec2 grad = vec2(
    sdLiquidSquircle(p + eps.xy, halfSize, r) - sdLiquidSquircle(p - eps.xy, halfSize, r),
    sdLiquidSquircle(p + eps.yx, halfSize, r) - sdLiquidSquircle(p - eps.yx, halfSize, r)
  );
  float gradLen = max(length(grad), 0.0001);
  vec2 n = grad / gradLen;

  // Vertical normalized position (top-down for milky diffusion gradient)
  float vy = clamp(pos.y / safeSize.y, 0.0, 1.0);

  // Curved glass bevel zone along outer ~14px
  float bevel = smoothstep(-14.0, 0.0, d);
  float rimBand = smoothstep(-2.4, -0.35, d) * (1.0 - smoothstep(-0.35, 0.8, d));
  float outerDarkEdge = smoothstep(-1.7, -0.35, d);

  // iOS 27 dual-balanced specular directions (upper-left key + subtle lower-right bounce)
  vec2 keyDir = normalize(vec2(-0.56, -0.83));
  vec2 bounceDir = normalize(vec2(0.55, 0.78));
  float keySpec = pow(max(dot(n, keyDir), 0.0), 2.3);
  float bounceSpec = pow(max(dot(n, bounceDir), 0.0), 3.0);

  // Diagonal caustic sheen across the glass face
  vec2 uv = pos / safeSize;
  float diag = clamp(1.0 - abs((uv.x * 0.65 + uv.y * 0.85) - 0.36) * 1.45, 0.0, 1.0);

  // Chromatic RGB optical dispersion along curved bevel rim
  vec3 prism = vec3(
    0.93 + 0.16 * max(n.x, 0.0),
    0.96 + 0.09 * (1.0 - abs(n.x)),
    0.99 + 0.18 * max(-n.x, 0.0)
  );
  vec3 tintAccent = mix(vec3(0.54, 0.75, 0.98), uTint.rgb, clamp(uTint.a, 0.0, 1.0));
  vec3 bevelColor = mix(prism, tintAccent, 0.34);

  // Base milky content diffusion color modulated by uOpacity (Clear 0 -> Tinted 1)
  vec3 lightBase = mix(vec3(1.0), vec3(0.955, 0.968, 0.988), vy);
  vec3 darkBase = mix(vec3(0.15, 0.18, 0.235), vec3(0.075, 0.094, 0.128), vy);
  vec3 baseColor = mix(lightBase, darkBase, uIsDark);

  // Subtle ambient chromatic edge scatter inside glass body
  float edgeTintStrength = (0.15 + 0.14 * uPress) * bevel * clamp(uTint.a, 0.0, 1.0);
  baseColor = mix(baseColor, tintAccent, edgeTintStrength);

  // Transparency curve: Clear (~0.18) -> iOS 27 Standard (~0.48) -> Tinted (~0.84)
  float baseAlpha = mix(
    mix(0.18, 0.84, uOpacity),
    mix(0.24, 0.86, uOpacity),
    uIsDark
  );

  // Add subtle inner milky veil + diagonal sheen
  float sheenAlpha = (1.0 - vy) * mix(0.17, 0.065, uIsDark) + diag * mix(0.08, 0.045, uIsDark);
  vec3 col = baseColor;
  float alpha = baseAlpha + sheenAlpha * (0.45 + 0.55 * (1.0 - uOpacity));

  // iOS 27 Brighter Specular Highlight along curved bevel & touch gleam
  float specIntensity = (keySpec * 0.92 + bounceSpec * 0.44) * bevel + rimBand * 0.58;
  specIntensity *= (1.0 + 0.42 * uPress);
  vec3 specColor = mix(vec3(1.0), bevelColor, 0.28);
  col = mix(col, specColor, clamp(specIntensity * mix(0.78, 0.54, uIsDark), 0.0, 0.94));
  alpha = max(alpha, rimBand * mix(0.64, 0.46, uIsDark));

  // iOS 27 Darkened Edge Framing (distinct separation on light/white/busy backgrounds)
  float darkFrameFactor = outerDarkEdge * mix(0.24, 0.42, uIsDark) * (0.65 + 0.35 * (1.0 - keySpec));
  vec3 darkRimColor = mix(vec3(0.18, 0.22, 0.28), vec3(0.02, 0.03, 0.05), uIsDark);
  col = mix(col, darkRimColor, darkFrameFactor);
  alpha = max(alpha, outerDarkEdge * mix(0.22, 0.45, uIsDark));

  // Premultiplied alpha output for Flutter FragmentShader compositor
  float finalAlpha = clamp(alpha, 0.0, 0.96) * aa;
  vec3 premul = clamp(col, 0.0, 1.0) * finalAlpha;
  fragColor = vec4(premul, finalAlpha);
}
