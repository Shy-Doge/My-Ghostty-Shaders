// Adjustable parameters
float blurStrength = 2;   // 1.0 = original size, >1 = bigger glow
float bloomBrightness = 2; // 1.0 = original brightness, >1 = brighter

// Simple max channel - treats all pure colors equally
float colorIntensity(vec4 c) {
    return max(max(c.r, c.g), c.b);
}

// Hash function for per-pixel randomness
float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

// Enhanced circular blur: jittered sampling, more directions, weighted center, quadratic radii
vec4 circularBlur(sampler2D tex, vec2 uv, float radius) {
    const int NUM_DIRECTIONS = 16; // More directions for rounder blur
    const int NUM_STEPS = 4;       // More steps for smoother gradient
    float sigma = radius * 0.5;
    float twoSigma2 = 2.0 * sigma * sigma;
    vec2 texelSize = 1.0 / iResolution.xy;
    vec4 color = vec4(0.0);
    float totalWeight = 0.0;

    // Per-pixel random angle offset for jittered sampling
    float jitter = hash12(uv * iResolution.xy) * 6.2831853; // 2*PI

    for (int d = 0; d < NUM_DIRECTIONS; d++) {
        float angle = 6.2831853 * float(d) / float(NUM_DIRECTIONS) + jitter;
        vec2 dir = vec2(cos(angle), sin(angle));
        for (int s = 1; s <= NUM_STEPS; s++) {
            // Quadratic spacing for radii: more samples near center
            float t = float(s) / float(NUM_STEPS);
            float dist = radius * t * t;
            vec2 offset = dir * dist * texelSize;
            float weight = exp(-(dist * dist) / twoSigma2);
            color += texture(tex, uv + offset) * weight;
            totalWeight += weight;
        }
    }
    // Weighted center sample (reduced weight for smoother transition)
    float centerWeight = 1.2;
    color += texture(tex, uv) * centerWeight;
    totalWeight += centerWeight;

    return color / totalWeight;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 originalColor = texture(iChannel0, uv);

    vec4 bloom = vec4(0.0);

    // Small tight glow
    vec4 blur1 = circularBlur(iChannel0, uv, 2.0 * blurStrength);
    float intensity1 = colorIntensity(blur1);
    if (intensity1 > 0.005) {
        float strength1 = smoothstep(0.005, 0.15, intensity1);
        strength1 = pow(strength1, 0.6);
        bloom += blur1 * strength1 * 0.3;
    }

    // Medium glow
    vec4 blur2 = circularBlur(iChannel0, uv, 4.0 * blurStrength);
    float intensity2 = colorIntensity(blur2);
    if (intensity2 > 0.003) {
        float strength2 = smoothstep(0.003, 0.12, intensity2);
        strength2 = pow(strength2, 0.7);
        bloom += blur2 * strength2 * 0.2;
    }

    // Large soft glow
    vec4 blur3 = circularBlur(iChannel0, uv, 8.0 * blurStrength);
    float intensity3 = colorIntensity(blur3);
    if (intensity3 > 0.001) {
        float strength3 = smoothstep(0.001, 0.08, intensity3);
        strength3 = pow(strength3, 0.5);
        bloom += blur3 * strength3 * 0.15;
    }

    fragColor = originalColor + bloom * bloomBrightness;
}
