import * as THREE from 'three';
import { Water } from 'three/examples/jsm/objects/Water.js';
import { Sky } from 'three/examples/jsm/objects/Sky.js';

export class SceneSetup {
    // =======================
    // Scene setup controller
    // - Manages water, sky, and sun lighting
    // - Connects environment lighting to renderer and camera
    // =======================
    constructor(scene, renderer, camera) {
        this.scene = scene;
        this.renderer = renderer;
        this.camera = camera;

        // References to environment objects
        this.water = null;
        this.sky = null;

        // Shared sun direction vector
        this.sun = new THREE.Vector3();
    }

    // =======================
    // Initialize environment
    // - Creates ocean surface
    // - Injects custom vertex wave logic
    // - Creates sky and lighting
    // =======================
    init() {
        // Large, highly subdivided plane for detailed wave displacement
        const waterGeometry = new THREE.PlaneGeometry(10000, 10000, 512, 512);

        // Generate a procedural normal map for small surface detail
        const waterNormals = this.createProceduralNormalMap();

        // Create Three.js Water object
        // Handles reflections, refractions, and lighting internally
        this.water = new Water(
            waterGeometry,
            {
                textureWidth: 512,
                textureHeight: 512,

                // Normal map used for high-frequency wave detail
                waterNormals: waterNormals,

                // Directional light input (set later)
                sunDirection: new THREE.Vector3(),

                // Sun color used for specular highlights
                sunColor: 0xffffff,

                // Base water tint
                waterColor: 0x004060,

                // Strength of distortion caused by waves
                distortionScale: 30.0,

                // Respect scene fog if present
                fog: this.scene.fog !== undefined
            }
        );

        // =======================
        // Inject custom vertex wave logic
        // - Modifies the built-in Water shader
        // - Adds large-scale Gerstner waves
        // =======================
        this.water.material.onBeforeCompile = (shader) => {
            // Custom time uniform for vertex animation
            shader.uniforms.uTime = { value: 0 };

            // Store shader reference for per-frame updates
            this.water.material.userData.shader = shader;

            // Add Gerstner wave function and elevation varying
            shader.vertexShader = `
                uniform float uTime;
                varying float vElevation;

                // Gerstner wave implementation
                // Produces steep, directional ocean waves
                vec3 gerstnerWave(vec2 coord, vec2 direction, float steepness, float wavelength, float speed) {
                    float k = 2.0 * 3.14159 / wavelength;
                    float c = sqrt(9.8 / k);
                    vec2 d = normalize(direction);
                    float f = k * (dot(d, coord) - speed * uTime);
                    float a = steepness / k;
                    
                    return vec3(
                        d.x * (a * cos(f)),
                        a * sin(f),
                        d.y * (a * cos(f))
                    );
                }
            ` + shader.vertexShader;

            // Replace the vertex position logic to apply wave displacement
            shader.vertexShader = shader.vertexShader.replace(
                '#include <begin_vertex>',
                `
                #include <begin_vertex>

                // Multiple Gerstner waves with different directions and scales
                // Creates complex, chaotic ocean motion
                vec3 wave1 = gerstnerWave(position.xy, vec2(1.0, 0.1), 0.9, 300.0, 15.0);
                vec3 wave2 = gerstnerWave(position.xy, vec2(0.7, 1.0), 0.8, 150.0, 20.0);
                vec3 wave3 = gerstnerWave(position.xy, vec2(-0.2, -0.4), 0.8, 80.0, 25.0);
                vec3 wave4 = gerstnerWave(position.xy, vec2(0.5, -0.6), 0.7, 40.0, 35.0);

                // Combine all wave displacements
                vec3 totalDisplacement = wave1 + wave2 + wave3 + wave4;

                // Amplify vertical motion for dramatic wave height
                totalDisplacement.y *= 5.0;

                // Add very large, slow-moving ocean swells
                float giantSwell = sin(position.x * 0.003 + uTime * 3.0) * 50.0;
                float secondarySwell = cos(position.y * 0.003 + uTime * 2.5) * 40.0;
                totalDisplacement.y += giantSwell + secondarySwell;

                // Apply final displacement to vertex
                transformed += totalDisplacement;

                // Pass elevation value for potential shading use
                vElevation = transformed.z;
                `
            );

            // Note:
            // The Water material relies heavily on the normal map for lighting.
            // Precise analytic normals are intentionally skipped for performance.
        };

        // Rotate water plane to lie flat
        this.water.rotation.x = -Math.PI / 2;
        this.scene.add(this.water);

        // =======================
        // Sky setup
        // - Physically based atmospheric scattering
        // - Used for lighting and reflections
        // =======================
        this.sky = new Sky();
        this.sky.scale.setScalar(10000);
        this.scene.add(this.sky);

        // Atmospheric parameters controlling sky appearance
        const skyUniforms = this.sky.material.uniforms;
        skyUniforms['turbidity'].value = 10;
        skyUniforms['rayleigh'].value = 2;
        skyUniforms['mieCoefficient'].value = 0.005;
        skyUniforms['mieDirectionalG'].value = 0.8;

        // Initial sun placement
        this.updateSunPosition(2, 180);
    }

    // =======================
    // Update sun position
    // - Converts elevation and azimuth to world direction
    // - Updates sky, water, and environment lighting
    // =======================
    updateSunPosition(elevation, azimuth) {
        const pmremGenerator = new THREE.PMREMGenerator(this.renderer);

        // Convert spherical angles to Cartesian direction
        const phi = THREE.MathUtils.degToRad(90 - elevation);
        const theta = THREE.MathUtils.degToRad(azimuth);

        this.sun.setFromSphericalCoords(1, phi, theta);

        // Update sky and water lighting
        this.sky.material.uniforms['sunPosition'].value.copy(this.sun);
        this.water.material.uniforms['sunDirection'].value.copy(this.sun).normalize();

        // Generate environment map for realistic reflections
        this.scene.environment = pmremGenerator.fromScene(this.sky).texture;
    }

    // =======================
    // Per-frame update
    // - Advances built-in water animation
    // - Advances custom vertex wave time
    // =======================
    update() {
        if (this.water) {
            // Built-in Water shader time
            this.water.material.uniforms['time'].value += 1.0 / 60.0;

            // Custom injected wave time
            if (this.water.material.userData.shader) {
                this.water.material.userData.shader.uniforms.uTime.value += 1.0 / 60.0;
            }
        }
    }

    // =======================
    // Procedural normal map generator
    // - Creates a noisy normal texture at runtime
    // - Used for small-scale surface detail
    // =======================
    createProceduralNormalMap() {
        const size = 512;
        const canvas = document.createElement('canvas');
        canvas.width = size;
        canvas.height = size;
        const ctx = canvas.getContext('2d');

        // Base flat normal color
        ctx.fillStyle = '#8080ff';
        ctx.fillRect(0, 0, size, size);

        // Inject random noise into normals
        const imageData = ctx.getImageData(0, 0, size, size);
        const data = imageData.data;

        for (let i = 0; i < data.length; i += 4) {
            data[i] = 128 + (Math.random() - 0.5) * 50;
            data[i + 1] = 128 + (Math.random() - 0.5) * 50;
            data[i + 2] = 255;
        }

        ctx.putImageData(imageData, 0, 0);

        // Convert canvas to texture
        const texture = new THREE.CanvasTexture(canvas);

        // Tile the normal map heavily for dense surface detail
        texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
        texture.repeat.set(50, 50);

        return texture;
    }
}
