#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

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

Drop splashDrops(float2 uv, float time, float scale) {
    float2 id = floor(uv * scale);
    float2 st = fract(uv * scale) - 0.5;
    
    float timeOffset = hash21(id) * 100.0;
    float localTime = (time + timeOffset) * 0.15;
    float cycle = floor(localTime);
    float t = fract(localTime);
    
    float3 rand = hash13(id.x * 123.4 + id.y * 567.8 + cycle * 987.6);
    
    if (rand.x > 0.2) {
        Drop empty;
        empty.mask = 0.0;
        empty.normal = float3(0,0,1);
        return empty;
    }
    
    float2 p = (rand.yz - 0.5) * 0.8;
    float maxRadius = rand.x * 0.25 + 0.15;
    
    float popIn = smoothstep(0.0, 0.02, t);
    float fadeOut = smoothstep(1.0, 0.7, t);
    float radius = maxRadius * popIn * fadeOut;
    
    float splashStart = smoothstep(0.0, 0.015, t) * smoothstep(0.04, 0.015, t);
    float ringR = (t * 15.0) * maxRadius;
    float splashRing = smoothstep(ringR, ringR - 0.03, length(st - p)) * smoothstep(ringR + 0.03, ringR - 0.03, length(st - p));
    
    float splashMask = splashRing * splashStart * 0.5;
    
    float2 diff = st - p;
    float d = length(diff);
    float beadMask = smoothstep(radius, radius - 0.05, d);
    float mask = max(beadMask, splashMask);
    
    float2 nd = diff / (radius + 0.0001);
    if (dot(nd, nd) > 1.0) nd = normalize(nd);
    
    float nZ = sqrt(max(1.0 - dot(nd, nd), 0.0));
    nZ = mix(1.0, nZ, fadeOut);
    
    Drop drop;
    drop.normal = float3(-nd.x, -nd.y, nZ);
    drop.mask = mask;
    
    return drop;
}

// NEW: Added wind parameter to control physics
Drop dynamicDrops(float2 uv, float time, float scale, float2 wind) {
    float2 UV = uv;
    
    // --- PHYSICS INTEGRATION ---
    // 1. Wind Shear: Slants the grid horizontally based on your X tilt
    UV.x += UV.y * wind.x;
    // 2. Gravity: Adjusts the fall speed based on your Y tilt
    UV.y += time * max(0.02, 0.08 + wind.y);
    
    float2 grid = float2(scale, scale * 0.25);
    float2 id = floor(UV * grid);
    
    float colShift = hash21(float2(id.x, 0.0));
    UV.y += colShift;
    id = floor(UV * grid);
    
    float3 rand = hash13(id.x * 35.2 + id.y * 237.6);
    float2 st = fract(UV * grid) - float2(0.5, 0.0);
    
    float x = rand.x - 0.5;
    
    float xWiggle = sin((UV.y - time) * 10.0) * 0.1 * rand.z;
    x += xWiggle;
    x *= 0.7;
    
    float ti = fract(time * 0.3 + rand.y);
    float y = st.y - ti;
    
    float2 center = float2(x, y);
    float2 diff = st - center;
    diff.y *= grid.x / grid.y;
    
    float d = length(diff);
    float rMain = 0.09 + rand.z * 0.06;
    
    float mainMask = smoothstep(rMain, rMain - 0.04, d);
    
    float trailD = abs(st.x - x);
    float trailR = sqrt(max(0.0, st.y - y)) * 0.04;
    float trailBounds = smoothstep(trailR, trailR - 0.02, trailD) * smoothstep(y, y + 0.3, st.y);
    
    float2 trailLocal = float2(diff.x, fract(diff.y * 12.0) - 0.5);
    float trailDrops = smoothstep(0.05, 0.01, length(trailLocal)) * trailBounds;
    
    float mask = max(mainMask, trailDrops);
    
    float2 nd = float2(0.0);
    if (mainMask > trailDrops) {
        nd = diff / rMain;
    } else if (trailDrops > 0.0) {
        nd = trailLocal / 0.05;
    }
    
    if (dot(nd, nd) > 1.0) nd = normalize(nd);
    float nZ = sqrt(max(1.0 - dot(nd, nd), 0.0));
    
    float cellFade = smoothstep(0.0, 0.1, st.y) * smoothstep(1.0, 0.8, st.y);
    mask *= cellFade * 0.6;
    
    Drop drop;
    drop.normal = float3(-nd.x, -nd.y, nZ);
    drop.mask = mask;
    return drop;
}

Drop mixLayer(Drop base, Drop top) {
    if (top.mask > base.mask) {
        return top;
    }
    return base;
}

[[ stitchable ]] half4 rainDistortion(float2 position, SwiftUI::Layer layer, float2 size, float3 params) {
    // Unpack our Swift parameters
    float time = params.x;
    float motionX = params.y;
    float motionY = params.z;

    float2 uv = position / min(size.x, size.y);
    
    // Scale the motion data into a wind/gravity vector
    float2 wind = float2(motionX * 0.6, motionY * 0.2);
    
    Drop drop;
    drop.mask = 0.0;
    drop.normal = float3(0,0,1);
    
    // Layer 1 & 2: Splashes stay mostly static on the glass
    drop = mixLayer(drop, splashDrops(uv, time, 15.0));
    drop = mixLayer(drop, splashDrops(uv * 1.3 + float2(0.1, 0.5), time * 0.9, 10.0));
    
    // Layer 3 & 4: Trickling trails react to the tilt physics
    drop = mixLayer(drop, dynamicDrops(uv, time, 6.0, wind));
    drop = mixLayer(drop, dynamicDrops(uv * 1.62 - float2(0.2, 0.5), time * 1.2, 4.0, wind));
    
    float3 lightDir = normalize(float3(-0.8, 0.8, 1.0));
    float3 viewDir = normalize(float3(0.0, 0.0, 1.0));
    
    float2 refractionOffset = drop.normal.xy * drop.mask;
    float2 refractedPos = position + refractionOffset * 20.0;
    
    half4 bgColor = layer.sample(refractedPos);
    
    if (drop.mask > 0.0) {
        float3 N = drop.normal;
        
        float3 H = normalize(lightDir + viewDir);
        float NdotH = max(dot(N, H), 0.0);
        float specular = pow(NdotH, 60.0);
        
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
