import * as THREE from 'three';
import vertexShader from './shaders/vertex.glsl?raw';
import fragmentShader from './shaders/fragment.glsl?raw';

export class Ocean {
    // =======================
    // Ocean system constructor
    // - Receives the main scene
    // - Creates and manages a full-screen shader mesh
    // =======================
    constructor(scene) {
        this.scene = scene;
        this.mesh = null;
        this.init();
    }

    // =======================
    // Initialize ocean rendering
    // - Creates a screen-aligned quad
    // - Applies raymarching shaders
    // - Sets up time and resolution uniforms
    // =======================
    init() {
        // Screen-sized plane in clip space
        // Used to render the shader across the entire viewport
        const geometry = new THREE.PlaneGeometry(2, 2);

        // Shader material driving the ocean + sky raymarching
        this.material = new THREE.ShaderMaterial({
            vertexShader: vertexShader,
            fragmentShader: fragmentShader,

            // Uniforms passed into the shaders
            // uTime: drives animation
            // uResolution: used for aspect ratio and ray direction
            uniforms: {
                uTime: { value: 0 },
                uResolution: {
                    value: new THREE.Vector2(
                        window.innerWidth,
                        window.innerHeight
                    )
                }
            },

            // Disable depth interaction
            // This shader renders as a full-screen background
            depthWrite: false,
            depthTest: false
        });

        // Mesh combining the full-screen geometry and shader
        this.mesh = new THREE.Mesh(geometry, this.material);

        // Prevent Three.js from culling the quad
        // Ensures it always renders regardless of camera frustum
        this.mesh.frustumCulled = false;

        // Add ocean shader quad to the scene
        this.scene.add(this.mesh);
    }

    // =======================
    // Per-frame update
    // - Updates time uniform
    // - Drives wave motion and sky animation
    // =======================
    update(time) {
        if (this.material) {
            this.material.uniforms.uTime.value = time;
        }
    }

    // =======================
    // Handle viewport resize
    // - Updates resolution uniform
    // - Keeps raymarching correct after resize
    // =======================
    resize() {
        if (this.material) {
            this.material.uniforms.uResolution.value.set(
                window.innerWidth,
                window.innerHeight
            );
        }
    }
}
