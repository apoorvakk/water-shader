import * as THREE from 'three';
import { Ocean } from './ocean.js';

// =======================
// Create the main 3D scene
// =======================
const scene = new THREE.Scene();

// =======================
// Camera setup
// - Perspective camera with narrow FOV for cinematic look
// - Positioned slightly above and to the side
// - Looking at the scene center
// =======================
const camera = new THREE.PerspectiveCamera(
  30,
  window.innerWidth / window.innerHeight,
  1,
  10000
);
camera.position.set(20, 10, 0);
camera.lookAt(0, 0, 0);

// =======================
// WebGL renderer
// - Antialiasing for smoother edges
// - Pixel ratio for sharp rendering on high-DPI screens
// - Full window size output
// =======================
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

// =======================
// Axis helper
// - Visual reference for X, Y, Z directions
// - Used for debugging orientation and scale
// =======================
const axis = new THREE.AxesHelper(10);
scene.add(axis);

// =======================
// Test sphere
// - Simple geometry to verify scene scale and animation
// - Uses basic material (no lighting interaction)
// =======================
const geometry = new THREE.SphereGeometry(10, 32, 32);
const material = new THREE.MeshBasicMaterial({ color: 0xffff00 });
const sphere = new THREE.Mesh(geometry, material);
scene.add(sphere);

// =======================
// Ocean system
// - Custom raymarched seascape
// - Manages its own shader, uniforms, and rendering
// - Added to the scene internally
// =======================
const ocean = new Ocean(scene);

// =======================
// Clock for time-based animation
// =======================
const clock = new THREE.Clock();

// =======================
// Main animation loop
// - Runs every frame
// - Updates ocean shader time
// - Animates sphere
// - Renders the scene
// =======================
function animate() {
  requestAnimationFrame(animate);

  const time = clock.getElapsedTime();

  // Update ocean animation (procedural waves, sky, lighting)
  ocean.update(time);

  // Simple vertical oscillation to give the sphere motion
  sphere.position.y = Math.sin(time) * 5;

  // Render the current frame
  renderer.render(scene, camera);
}

animate();

// =======================
// Handle browser resize
// - Update camera projection
// - Resize renderer output
// - Notify ocean shader of resolution change
// =======================
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  ocean.resize();
});
