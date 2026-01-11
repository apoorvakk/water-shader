precision highp float;

uniform float uTime;
uniform vec2 uResolution;

// Raymarching steps for finding ocean surface
const int NUM_STEPS = 8;
const float PI = 3.14159265;
const float EPSILON = 1e-3;

// Ocean wave parameters
const int ITER_GEOMETRY = 3;    // Wave iterations for geometry pass
const int ITER_FRAGMENT = 5;    // Wave iterations for detail pass
const float SEA_HEIGHT = 0.6;   // Base wave height
const float SEA_CHOPPY = 4.0;   // Wave sharpness
const float SEA_SPEED = 0.8;    // Wave animation speed
const float SEA_FREQ = 0.16;    // Wave frequency
const vec3 SEA_BASE = vec3(0.05, 0.1, 0.15);           // Deep water color
const vec3 SEA_WATER_COLOR = vec3(1.0, 0.6, 0.3) * 0.5; // Surface water tint

// Sun parameters
const vec3 SUN_DIR = normalize(vec3(0.0, 0.15, -1.0)); // Low sun near horizon
const vec3 SUN_COLOR = vec3(1.0, 0.7, 0.3);            // Warm golden color
const float SUN_SIZE = 0.001;                           // Sun disc size
const float SUN_GLOW = 0.02;                            // Glow intensity
#define SEA_TIME (uTime * SEA_SPEED)
const mat2 octave_m = mat2(1.6, 1.2, -1.2, 1.6);       // Matrix for rotating wave layers

// Converts euler angles to rotation matrix
mat3 fromEuler(vec3 ang) {
    vec2 a1 = vec2(sin(ang.x), cos(ang.x));
    vec2 a2 = vec2(sin(ang.y), cos(ang.y));
    vec2 a3 = vec2(sin(ang.z), cos(ang.z));
    mat3 m;
    m[0] = vec3(a1.y * a3.y + a1.x * a2.x * a3.x, a1.y * a2.x * a3.x + a3.y * a1.x, -a2.y * a3.x);
    m[1] = vec3(-a2.y * a1.x, a1.y * a2.y, a2.x);
    m[2] = vec3(a3.y * a1.x * a2.x + a1.y * a3.x, a1.x * a3.x - a1.y * a3.y * a2.x, a2.y * a3.y);
    return m;
}

// Generates pseudo-random value from 2D position
float hash(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));	
    return fract(sin(h) * 43758.5453123);
}

// Generates smooth noise from 2D position
float noise(in vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);	
    vec2 u = f * f * (3.0 - 2.0 * f);
    return -1.0 + 2.0 * mix(
    	mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
    	mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), 
        u.y
    );
}

// Calculates diffuse lighting with wrap factor
float diffuse(vec3 n, vec3 l, float p) {
    return pow(dot(n, l) * 0.4 + 0.6, p);
}

// Calculates specular highlight intensity
float specular(vec3 n, vec3 l, vec3 e, float s) {    
    float nrm = (s + 8.0) / (PI * 8.0);
    return pow(max(dot(reflect(e, n), l), 0.0), s) * nrm;
}

// Returns sky color for a given ray direction
vec3 getSkyColor(vec3 e) {
    e.y = max(e.y, 0.0);
    
    // Sky gradient colors
    vec3 horizonColor = vec3(1.0, 0.4, 0.1);   // Orange at horizon
    vec3 midColor = vec3(1.0, 0.55, 0.25);     // Pink-orange mid sky
    vec3 zenithColor = vec3(0.2, 0.25, 0.5);   // Blue-purple at top
    
    // Blend colors based on vertical angle
    float horizonFade = pow(1.0 - e.y, 3.0);
    float midFade = pow(1.0 - e.y, 1.5) * (1.0 - pow(1.0 - e.y, 2.0));
    vec3 skyGradient = mix(zenithColor, midColor, pow(1.0 - e.y, 1.2));
    skyGradient = mix(skyGradient, horizonColor, horizonFade);
    
    // Calculate sun visibility
    float sunDot = dot(e, SUN_DIR);
    float sunDisc = smoothstep(1.0 - SUN_SIZE, 1.0 - SUN_SIZE * 0.5, sunDot);
    
    // Calculate sun glow falloff
    float sunGlow = pow(max(sunDot, 0.0), 16.0);
    float sunHalo = pow(max(sunDot, 0.0), 64.0);
    
    // Add sun to sky
    vec3 finalSky = skyGradient;
    finalSky += SUN_COLOR * sunGlow * 0.002;
    finalSky += vec3(1.0, 0.9, 0.7) * sunHalo * 0.2;
    finalSky = mix(finalSky, vec3(1.0, 0.95, 0.85), sunDisc);
    
    return finalSky;
}

// Generates one layer of wave height
float sea_octave(vec2 uv, float choppy) {
    uv += noise(uv);         
    vec2 wv = 1.0 - abs(sin(uv));
    vec2 swv = abs(cos(uv));    
    wv = mix(wv, swv, wv);
    return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}

// Calculates ocean height at position (low detail for raymarching)
float map(vec3 p) {
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    vec2 uv = p.xz; 
    uv.x *= 0.75;
    
    float h = 0.0;    
    for(int i = 0; i < ITER_GEOMETRY; i++) {        
        float d = sea_octave((uv + SEA_TIME) * freq, choppy);
        d += sea_octave((uv - SEA_TIME) * freq, choppy);
        h += d * amp;        
        uv *= octave_m;
        freq *= 1.9; 
        amp *= 0.22;
        choppy = mix(choppy, 1.0, 0.2);
    }
    return p.y - h;
}

// Calculates ocean height at position (high detail for normals)
float map_detailed(vec3 p) {
    float freq = SEA_FREQ;
    float amp = SEA_HEIGHT;
    float choppy = SEA_CHOPPY;
    vec2 uv = p.xz;
    uv.x *= 0.75;
    
    float h = 0.0;    
    for(int i = 0; i < ITER_FRAGMENT; i++) {        
        float d = sea_octave((uv + SEA_TIME) * freq, choppy);
        d += sea_octave((uv - SEA_TIME) * freq, choppy);
        h += d * amp;        
        uv *= octave_m;
        freq *= 1.9; 
        amp *= 0.22;
        choppy = mix(choppy, 1.0, 0.2);
    }
    return p.y - h;
}

// Calculates final ocean surface color
vec3 getSeaColor(vec3 p, vec3 n, vec3 l, vec3 eye, vec3 dist) {  
    // Fresnel effect - more reflection at grazing angles
    float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
    fresnel = pow(fresnel, 3.0) * 0.65;

    // Get reflected sky color and underwater color
    vec3 reflected = getSkyColor(reflect(eye, n));    
    vec3 refracted = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12; 

    // Blend reflection and refraction based on fresnel
    vec3 color = mix(refracted, reflected, fresnel);

    // Add depth-based color variation
    float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
    color += SEA_WATER_COLOR * (p.y - SEA_HEIGHT) * 0.18 * atten;

    // Add sun specular highlight on water
    color += SUN_COLOR * specular(n, l, eye, 60.0) * 1.5;

    return color;
}

// Calculates surface normal using height differences
vec3 getNormal(vec3 p, float eps) {
    vec3 n;
    n.y = map_detailed(p);    
    n.x = map_detailed(vec3(p.x + eps, p.y, p.z)) - n.y;
    n.z = map_detailed(vec3(p.x, p.y, p.z + eps)) - n.y;
    n.y = eps;
    return normalize(n);
}

// Finds where ray intersects ocean surface
float heightMapTracing(vec3 ori, vec3 dir, out vec3 p) {  
    float tm = 0.0;
    float tx = 1000.0;    
    float hx = map(ori + dir * tx);
    if(hx > 0.0) return tx;   
    float hm = map(ori + dir * tm);    
    float tmid = 0.0;
    for(int i = 0; i < NUM_STEPS; i++) {
        tmid = mix(tm, tx, hm / (hm - hx));                   
        p = ori + dir * tmid;                   
        float hmid = map(p);
        if(hmid < 0.0) {
            tx = tmid;
            hx = hmid;
        } else {
            tm = tmid;
            hm = hmid;
        }
    }
    return tmid;
}

void main() {
    // Convert pixel to normalized coordinates
    float EPSILON_NRM = 0.1 / uResolution.x;
    vec2 uv = gl_FragCoord.xy / uResolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= uResolution.x / uResolution.y;    
    float time = uTime * 0.3;

    // Set up camera position and ray direction
    vec3 ang = vec3(sin(time * 3.0) * 0.1, sin(time) * 0.1 + 0.01, time);    
    vec3 ori = vec3(0.0, 2.5, time * 5.0);
    vec3 dir = normalize(vec3(uv.x, uv.y - 0.6, -2.0));
    dir.z += length(uv) * 0.15;
    dir = normalize(dir);

    // Find ocean surface intersection point
    vec3 p;
    heightMapTracing(ori, dir, p);
    vec3 dist = p - ori;
    vec3 n = getNormal(p, dot(dist, dist) * EPSILON_NRM);
    vec3 light = SUN_DIR;

    // Blend sky and ocean based on ray direction
    vec3 color = mix(
        getSkyColor(dir),
        getSeaColor(p, n, light, dir, dist),
        pow(smoothstep(0.0, -0.05, dir.y), 0.3)
    );

    // Apply gamma correction
    gl_FragColor = vec4(pow(color, vec3(0.75)), 1.0);
}
