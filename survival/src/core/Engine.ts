import * as THREE from 'three';
import RAPIER from '@dimforge/rapier3d-compat';
import { config } from '../config/GameConfig';
import { Input } from './Input';

export interface System {
  /** Runs at the fixed physics rate, before world.step(). */
  fixedUpdate?(dt: number): void;
  /** Runs once per rendered frame. */
  update?(dt: number): void;
}

export class Engine {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly camera: THREE.PerspectiveCamera;
  readonly canvas: HTMLCanvasElement;
  readonly input: Input;
  readonly physics: RAPIER.World;
  elapsed = 0;
  frameDelta = 0;

  private readonly systems: System[] = [];
  private accumulator = 0;
  private lastTime = 0;

  private constructor(mount: HTMLElement, physics: RAPIER.World) {
    this.canvas = document.createElement('canvas');
    this.canvas.className = 'game-canvas';
    mount.appendChild(this.canvas);

    this.renderer = new THREE.WebGLRenderer({ canvas: this.canvas, antialias: true });
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.camera = new THREE.PerspectiveCamera(
      config.render.fov,
      1,
      config.render.nearPlane,
      config.render.farPlane,
    );
    this.camera.rotation.order = 'YXZ';
    this.scene.fog = new THREE.FogExp2(0x93b7d6, config.render.fogDensity);
    this.physics = physics;
    this.input = new Input(this.canvas);
    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  static async create(mount: HTMLElement): Promise<Engine> {
    await RAPIER.init();
    const world = new RAPIER.World({ x: 0, y: config.physics.gravity, z: 0 });
    return new Engine(mount, world);
  }

  add(system: System): void {
    this.systems.push(system);
  }

  start(): void {
    this.lastTime = performance.now();
    const frame = (now: number) => {
      requestAnimationFrame(frame);
      const raw = Math.min((now - this.lastTime) / 1000, 0.25);
      this.lastTime = now;
      this.tick(raw * config.debug.timeScale);
    };
    requestAnimationFrame(frame);
  }

  private tick(dt: number): void {
    this.frameDelta = dt;
    this.elapsed += dt;

    // Physics values are re-read every tick — nothing here is cached at startup.
    this.physics.gravity.y = config.physics.gravity * config.player.gravityScale;
    const step = Math.max(config.physics.fixedStep, 1 / 480);
    this.accumulator = Math.min(this.accumulator + dt, step * config.physics.maxSubSteps);
    let steps = 0;
    while (this.accumulator >= step && steps < config.physics.maxSubSteps) {
      for (const system of this.systems) system.fixedUpdate?.(step);
      this.physics.timestep = step;
      this.physics.step();
      this.accumulator -= step;
      steps += 1;
    }

    for (const system of this.systems) system.update?.(dt);

    this.syncRenderConfig();
    this.renderer.render(this.scene, this.camera);
    this.input.endFrame();
  }

  private syncRenderConfig(): void {
    if (this.camera.fov !== config.render.fov || this.camera.far !== config.render.farPlane) {
      this.camera.fov = config.render.fov;
      this.camera.near = config.render.nearPlane;
      this.camera.far = config.render.farPlane;
      this.camera.updateProjectionMatrix();
    }
    const fog = this.scene.fog as THREE.FogExp2 | null;
    if (fog) fog.density = config.render.fogDensity;
    const ratio = Math.min(window.devicePixelRatio, config.render.pixelRatioCap);
    if (this.renderer.getPixelRatio() !== ratio) this.renderer.setPixelRatio(ratio);
  }

  private resize(): void {
    const width = window.innerWidth;
    const height = window.innerHeight;
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
  }
}
