precision highp float;

varying vec3 vWorldPosition;

uniform vec3 uSunPosition;
uniform float uTime;

// Rich oceanic sky colors
const vec3 SKY_DARK = vec3(0.01, 0.04, 0.08);
const vec3 SKY_MID = vec3(0.04, 0.1, 0.2);
const vec3 SKY_HORIZON = vec3(0.1, 0.2, 0.3);
const vec3 CLOUD_DARK = vec3(0.02, 0.05, 0.1);
const vec3 CLOUD_LIGHT = vec3(0.1, 0.2, 0.3);

// Simple noise for clouds
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 5; i++) {
        value += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return value;
}

void main() {
    vec3 viewDir = normalize(vWorldPosition);
    vec3 sunDir = normalize(uSunPosition);
    
    float elevation = viewDir.y;
    
    // === BASE SKY GRADIENT (dark overcast) ===
    vec3 skyColor = SKY_DARK;
    
    float horizonBlend = 1.0 - smoothstep(-0.1, 0.3, elevation);
    skyColor = mix(skyColor, SKY_HORIZON, horizonBlend);
    
    float midBlend = smoothstep(0.0, 0.4, elevation) * (1.0 - smoothstep(0.4, 0.8, elevation));
    skyColor = mix(skyColor, SKY_MID, midBlend * 0.5);
    
    // === HEAVY CLOUD LAYER ===
    // Project view direction onto cloud plane
    vec2 cloudUV = viewDir.xz / (abs(viewDir.y) + 0.1) * 2.0;
    cloudUV += uTime * 0.02; // Slow cloud movement
    
    // Turbulent cloud noise
    float cloudNoise = fbm(cloudUV * 0.5);
    float cloudNoise2 = fbm(cloudUV * 1.2 + vec2(100.0));
    
    float clouds = cloudNoise * 0.6 + cloudNoise2 * 0.4;
    clouds = smoothstep(0.3, 0.7, clouds);
    
    // Cloud coverage 0.9 = very overcast
    clouds *= 0.9;
    
    vec3 cloudColor = mix(CLOUD_DARK, CLOUD_LIGHT, clouds * 0.5);
    skyColor = mix(skyColor, cloudColor, clouds * (1.0 - abs(elevation) * 0.5));
    
    // === VISIBLE SUN DISC ===
    float sunDist = acos(clamp(dot(viewDir, sunDir), -1.0, 1.0));
    
    // Sharp sun disk
    float sunDisc = smoothstep(0.015, 0.012, sunDist);
    
    // Multi-layer sun glow
    float sunGlow1 = exp(-sunDist * 10.0) * 0.8;
    float sunGlow2 = exp(-sunDist * 2.0) * 0.3;
    
    vec3 sunColor = vec3(1.0, 0.8, 0.5);
    skyColor += sunColor * (sunDisc * 5.0 + sunGlow1 + sunGlow2) * (1.0 - clouds * 0.5);
    
    // === ATMOSPHERE DARKENING ===
    // Darker at zenith
    float zenithDark = smoothstep(0.3, 0.9, elevation);
    skyColor *= 1.0 - zenithDark * 0.3;
    
    // === HORIZON HAZE ===
    float haze = exp(-abs(elevation) * 3.0) * 0.2;
    vec3 hazeColor = vec3(0.15, 0.16, 0.20);
    skyColor = mix(skyColor, hazeColor, haze);
    
    gl_FragColor = vec4(skyColor, 1.0);
    
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
}
