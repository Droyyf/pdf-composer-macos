#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float2 resolution;
    float blurRadius;
    float noiseIntensity;
    float grainIntensity;
    float textureMix;
    float4 colorTint;
    float vignette;
};

// Simple hash for noise
float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Animated noise
float noise(float2 uv, float t) {
    float n = hash21(uv * 100.0 + t * 0.1);
    return n;
}

fragment float4 backgroundShader(VertexOut in [[stage_in]],
                                constant Uniforms &u [[buffer(0)]],
                                texture2d<float> tex [[texture(0)]],
                                sampler s [[sampler(0)]]) {
    float2 uv = in.texCoord;
    float4 color = float4(0.0, 0.0, 0.0, 0.0);

    // Animated noise
    float n = noise(uv * u.resolution, u.time);
    float grain = noise(uv * u.resolution * 2.0, u.time * 2.0);
    float noiseVal = mix(n, grain, 0.5) * u.noiseIntensity;

    // Optional texture overlay
    float4 texColor = tex.sample(s, uv);
    color.rgb = mix(color.rgb, texColor.rgb, u.textureMix);

    // Add noise/grain
    color.rgb += noiseVal * u.grainIntensity;

    // Simple blur (box blur, for demo)
    float blur = u.blurRadius;
    if (blur > 0.01) {
        float4 sum = float4(0.0);
        int samples = 5;
        for (int x = -samples; x <= samples; ++x) {
            for (int y = -samples; y <= samples; ++y) {
                float2 offset = float2(x, y) / u.resolution * blur;
                sum += tex.sample(s, uv + offset);
            }
        }
        color.rgb = mix(color.rgb, sum.rgb / pow(float(2 * samples + 1), 2.0), 0.5);
    }

    // Color tint
    color.rgb = mix(color.rgb, color.rgb * u.colorTint.rgb, u.colorTint.a);

    // Vignette
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);
    float vignette = smoothstep(0.7, 0.95, dist);
    color.rgb = mix(color.rgb, color.rgb * (1.0 - u.vignette), vignette * u.vignette);

    // Alpha for transparency
    color.a = 0.7;
    return color;
}
