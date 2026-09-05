import * as THREE from 'three';
import RAPIER from '@dimforge/rapier3d-compat';
import './ui/style.css';
import { config } from './config/GameConfig';
import { Engine } from './core/Engine';
import { PlayerController } from './player/PlayerController';
import { ModMenu } from './ui/ModMenu';
import { buildTuningTab } from './ui/tabs/tuning';
import { el } from './ui/controls';

const mount = document.getElementById('app')!;
const engine = await Engine.create(mount);

// --- placeholder scene: flat ground + a few blocks, replaced by terrain in step 2
engine.scene.background = new THREE.Color(0x93b7d6);
const sun = new THREE.DirectionalLight(0xfff2dd, config.render.sunIntensity);
sun.position.set(60, 120, 40);
sun.castShadow = true;
sun.shadow.mapSize.set(1024, 1024);
sun.shadow.camera.far = 400;
engine.scene.add(sun);
const ambient = new THREE.AmbientLight(0x9fb8d0, config.render.ambientIntensity);
engine.scene.add(ambient);

const GROUND_HALF = 100;
const ground = new THREE.Mesh(
  new THREE.BoxGeometry(GROUND_HALF * 2, 2, GROUND_HALF * 2),
  new THREE.MeshLambertMaterial({ color: 0x5c7a4a }),
);
ground.position.y = -1;
ground.receiveShadow = true;
engine.scene.add(ground);
engine.physics.createCollider(
  RAPIER.ColliderDesc.cuboid(GROUND_HALF, 1, GROUND_HALF).setTranslation(0, -1, 0),
);

const blockMaterial = new THREE.MeshLambertMaterial({ color: 0x8a7f6d });
for (let i = 0; i < 24; i += 1) {
  const size = 1 + (i % 5);
  const x = Math.cos(i * 1.7) * (12 + i * 2.2);
  const z = Math.sin(i * 1.7) * (12 + i * 2.2);
  const block = new THREE.Mesh(new THREE.BoxGeometry(size, size, size), blockMaterial);
  block.position.set(x, size / 2, z);
  block.castShadow = true;
  block.receiveShadow = true;
  engine.scene.add(block);
  engine.physics.createCollider(
    RAPIER.ColliderDesc.cuboid(size / 2, size / 2, size / 2).setTranslation(x, size / 2, z),
  );
}

const player = new PlayerController(engine, new THREE.Vector3(0, 3, 8));
engine.add(player);

// --- HUD
mount.append(el('div', 'crosshair'));
const stats = el('div', 'stats');
mount.append(stats);
const hint = el('div', 'hint', 'Click to capture mouse · WASD + Space · ~ for mod menu');
mount.append(hint);

const menu = new ModMenu(mount, engine.input);
menu.addTab('tuning', 'Tuning', buildTuningTab);

let fpsSmoothed = 60;
engine.add({
  update: (dt) => {
    hint.style.display = engine.input.pointerLocked || menu.isOpen ? 'none' : '';
    stats.style.display = config.debug.showStats ? '' : 'none';
    if (!config.debug.showStats) return;
    if (dt > 0) fpsSmoothed += (1 / dt - fpsSmoothed) * 0.08;
    const p = player.position;
    const speed = Math.hypot(player.velocity.x, player.velocity.z);
    stats.textContent = [
      `fps        ${fpsSmoothed.toFixed(0)}`,
      `pos        ${p.x.toFixed(1)} ${p.y.toFixed(1)} ${p.z.toFixed(1)}`,
      `speed      ${speed.toFixed(2)} m/s`,
      `moveSpeed  ${config.player.moveSpeed.toFixed(2)} (config)`,
      `grounded   ${player.grounded}`,
    ].join('\n');
  },
});

engine.start();
