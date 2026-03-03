#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - Helpers
float3 hash13(float p) {
    float3 p3 = fract(float3(p) * float3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(float3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

struct Drop {
    float3 normal;
    float mask;
};

// MARK: - Drop Logic
Drop splashDrops(float2 uv, float time, float scale, float2 wind) {
    float2 id = floor(uv * scale);
    float2 st = fract(uv * scale) - 0.5;
    
    float timeOffset = hash21(id) * 100.0;
    // Slower lifecycle for splashes
    float localTime = (time + timeOffset) * 0.08;
    float cycle = floor(localTime);
    float t = fract(localTime);
    
    float3 rand = hash13(id.x * 123.4 + id.y * 567.8 + cycle * 987.6);
    
    if (rand.x > 0.2) {
        Drop empty;
        empty.mask = 0.0;
        empty.normal = float3(0,0,1);
        return empty;
    }
    
    float2 p = (rand.yz - 0.5) * 0.4;
    p.y -= 0.15;
    
    // Physics sliding
    p.x += t * wind.x * 0.8;
    p.y += t * (0.15 + max(0.0, wind.y * 0.5));
    
    float maxRadius = rand.x * 0.25 + 0.15;
    float popIn = smoothstep(0.0, 0.02, t);
    float fadeOut = smoothstep(1.0, 0.7, t);
    float radius = maxRadius * popIn * fadeOut;
    
    float ringR = (t * 15.0) * maxRadius;
    float splashRing = smoothstep(ringR, ringR - 0.03, length(st - p)) * smoothstep(ringR + 0.03, ringR - 0.03, length(st - p));
    float splashStart = smoothstep(0.0, 0.015, t) * smoothstep(0.04, 0.015, t);
    
    float2 diff = st - p;
    float d = length(diff);
    float beadMask = smoothstep(radius, radius - 0.05, d);
    
    float mask = max(beadMask, splashRing * splashStart * 0.5);
    
    float2 nd = diff / (radius + 0.0001);
    if (dot(nd, nd) > 1.0) nd = normalize(nd);
    
    float nZ = sqrt(max(1.0 - dot(nd, nd), 0.0));
    nZ = mix(1.0, nZ, fadeOut);
    
    return { float3(-nd.x, -nd.y, nZ), mask };
}

Drop dynamicDrops(float2 uv, float time, float scale, float2 wind) {
    float2 UV = uv;
    // Physics shear and gravity
    UV.x += UV.y * wind.x;
    UV.y += time * max(0.01, 0.03 + wind.y * 0.5);
    
    float2 grid = float2(scale, scale * 0.25);
    float2 id = floor(UV * grid);
    UV.y += hash21(float2(id.x, 0.0));
    id = floor(UV * grid);
    
    float3 rand = hash13(id.x * 35.2 + id.y * 237.6);
    float2 st = fract(UV * grid) - float2(0.5, 0.0);
    
    float x = (rand.x - 0.5) + (sin((UV.y - time) * 10.0) * 0.1 * rand.z);
    x *= 0.7;
    
    float ti = fract(time * 0.15 + rand.y);
    float y = st.y - ti;
    
    float2 center = float2(x, y);
    float2 diff = st - center;
    diff.y *= grid.x / grid.y;
    
    float rMain = 0.09 + rand.z * 0.06;
    float mainMask = smoothstep(rMain, rMain - 0.04, length(diff));
    
    float trailD = abs(st.x - x);
    float trailR = sqrt(max(0.0, st.y - y)) * 0.04;
    float trailBounds = smoothstep(trailR, trailR - 0.02, trailD) * smoothstep(y, y + 0.3, st.y);
    
    float2 trailLocal = float2(diff.x, fract(diff.y * 12.0) - 0.5);
    float trailDrops = smoothstep(0.05, 0.01, length(trailLocal)) * trailBounds;
    
    float mask = max(mainMask, trailDrops);
    float2 nd = (mainMask > trailDrops) ? (diff / rMain) : (trailLocal / 0.05);
    
    if (dot(nd, nd) > 1.0) nd = normalize(nd);
    float nZ = sqrt(max(1.0 - dot(nd, nd), 0.0));
    
    float cellFade = smoothstep(0.0, 0.1, st.y) * smoothstep(1.0, 0.8, st.y);
    return { float3(-nd.x, -nd.y, nZ), mask * cellFade * 0.6 };
}

Drop mixLayer(Drop base, Drop top) {
    return (top.mask > base.mask) ? top : base;
}

// MARK: - Main Shader
[[ stitchable ]] half4 rainDistortion(float2 position, SwiftUI::Layer layer, float2 size, float3 params) {
    float time = params.x;
    float motionX = params.y;
    float motionY = params.z;

    float2 uv = position / min(size.x, size.y);
    
    // Global Gravity Sag
    uv.x -= motionX * 0.1;
    uv.y -= motionY * 0.1;
    
    float2 wind = float2(motionX * 0.6, motionY * 0.2);
    
    Drop drop;
    drop.mask = 0.0;
    drop.normal = float3(0,0,1);
    
    // Layers
    drop = mixLayer(drop, splashDrops(uv, time, 15.0, wind));
    drop = mixLayer(drop, splashDrops(uv * 1.3 + float2(0.1, 0.5), time * 0.9, 10.0, wind));
    drop = mixLayer(drop, dynamicDrops(uv, time, 6.0, wind));
    drop = mixLayer(drop, dynamicDrops(uv * 1.62 - float2(0.2, 0.5), time * 1.2, 4.0, wind));
    
    // Refraction
    float2 refractionOffset = drop.normal.xy * drop.mask;
    float2 refractedPos = position + refractionOffset * 20.0;
    
    half4 bgColor = layer.sample(refractedPos);
    
    // --- Frosted Condensation ---
    // If mask is low (no drop), apply blur and frost tint
    if (drop.mask < 0.1) {
        float2 blurOffset = float2(0.002, 0.002) * size;
        half4 blurSample = (layer.sample(position + blurOffset) + layer.sample(position - blurOffset)) * 0.5;
        half4 frostColor = half4(0.85, 0.85, 0.9, 1.0);
        bgColor = mix(bgColor, blurSample, 0.6);
        bgColor = mix(bgColor, frostColor, 0.08);
    }

    // Specular / Lighting
    if (drop.mask > 0.0) {
        float3 lightDir = normalize(float3(-0.8, 0.8, 1.0));
        float3 viewDir = normalize(float3(0.0, 0.0, 1.0));
        float3 N = drop.normal;
        
        float3 H = normalize(lightDir + viewDir);
        float specular = pow(max(dot(N, H), 0.0), 60.0);
        
        float NdotL = dot(N, lightDir);
        float3 volumeShadow = mix(float3(0.65, 0.75, 0.85), float3(1.0), smoothstep(-0.8, 0.6, NdotL));
        float fresnel = pow(max(1.0 - dot(N, viewDir), 0.0), 4.0);
        
        bgColor.rgb *= half3(volumeShadow);
        bgColor.rgb += half3(specular * 1.2);
        bgColor.rgb += half3(fresnel * float3(0.25));
    }
    
    half4 pureBG = layer.sample(position);
    return mix(pureBG, bgColor, smoothstep(0.0, 0.2, drop.mask));
}
