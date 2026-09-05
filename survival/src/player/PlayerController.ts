import * as THREE from 'three';
import RAPIER from '@dimforge/rapier3d-compat';
import { config } from '../config/GameConfig';
import type { Engine, System } from '../core/Engine';

const FORWARD = new THREE.Vector3();
const RIGHT = new THREE.Vector3();
const WISH = new THREE.Vector3();

/**
 * Kinematic FPS controller. Every number it uses (speed, jump height, capsule
 * size, slope limits) is read from GameConfig on the tick it is needed.
 */
export class PlayerController implements System {
  yaw = 0;
  pitch = 0;
  grounded = false;
  readonly velocity = new THREE.Vector3();

  private readonly body: RAPIER.RigidBody;
  private collider: RAPIER.Collider;
  private readonly controller: RAPIER.KinematicCharacterController;
  private shapeKey = '';

  constructor(
    private readonly engine: Engine,
    spawn: THREE.Vector3,
  ) {
    const world = engine.physics;
    this.body = world.createRigidBody(
      RAPIER.RigidBodyDesc.kinematicPositionBased().setTranslation(spawn.x, spawn.y, spawn.z),
    );
    this.collider = world.createCollider(this.makeShape(), this.body);
    this.controller = world.createCharacterController(0.02);
    this.controller.setSlideEnabled(true);
    this.controller.setApplyImpulsesToDynamicBodies(true);
  }

  get position(): THREE.Vector3 {
    const t = this.body.translation();
    return new THREE.Vector3(t.x, t.y, t.z);
  }

  teleport(target: THREE.Vector3): void {
    this.body.setNextKinematicTranslation(target);
    this.body.setTranslation(target, true);
    this.velocity.set(0, 0, 0);
  }

  fixedUpdate(dt: number): void {
    this.syncShape();
    const player = config.player;
    const input = this.engine.input;

    FORWARD.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
    RIGHT.set(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
    WISH.set(0, 0, 0);
    if (input.down('KeyW')) WISH.add(FORWARD);
    if (input.down('KeyS')) WISH.sub(FORWARD);
    if (input.down('KeyD')) WISH.add(RIGHT);
    if (input.down('KeyA')) WISH.sub(RIGHT);
    if (WISH.lengthSq() > 0) WISH.normalize();

    const targetSpeed = player.moveSpeed;
    const accel = this.grounded ? player.groundAcceleration : player.airAcceleration;
    const control = this.grounded ? 1 : player.airControl;
    const blend = Math.min(1, accel * control * dt);
    this.velocity.x += (WISH.x * targetSpeed - this.velocity.x) * blend;
    this.velocity.z += (WISH.z * targetSpeed - this.velocity.z) * blend;

    const gravity = config.physics.gravity * player.gravityScale;
    if (this.grounded && this.velocity.y <= 0) this.velocity.y = -2;
    if (this.grounded && input.down('Space')) {
      this.velocity.y = Math.sqrt(Math.max(0, 2 * Math.abs(gravity) * player.jumpHeight));
    }
    this.velocity.y = Math.max(
      this.velocity.y + gravity * dt,
      -Math.abs(config.physics.maxFallSpeed),
    );

    this.controller.setMaxSlopeClimbAngle(THREE.MathUtils.degToRad(player.maxSlopeDegrees));
    this.controller.enableAutostep(player.stepHeight, player.radius * 0.5, true);
    this.controller.computeColliderMovement(this.collider, {
      x: this.velocity.x * dt,
      y: this.velocity.y * dt,
      z: this.velocity.z * dt,
    });
    const moved = this.controller.computedMovement();
    this.grounded = this.controller.computedGrounded();
    if (this.grounded && this.velocity.y < 0) this.velocity.y = 0;

    const t = this.body.translation();
    this.body.setNextKinematicTranslation({
      x: t.x + moved.x,
      y: t.y + moved.y,
      z: t.z + moved.z,
    });
  }

  update(): void {
    const input = this.engine.input;
    if (input.pointerLocked) {
      this.yaw -= input.mouseDX * config.player.mouseSensitivity;
      this.pitch -= input.mouseDY * config.player.mouseSensitivity;
      const limit = Math.PI / 2 - 0.001;
      this.pitch = THREE.MathUtils.clamp(this.pitch, -limit, limit);
    }
    const t = this.body.translation();
    const feet = t.y - config.player.height / 2;
    this.engine.camera.position.set(t.x, feet + config.player.eyeHeight, t.z);
    this.engine.camera.rotation.set(this.pitch, this.yaw, 0);
  }

  /** Rebuilds the capsule when the config's body dimensions change. */
  private syncShape(): void {
    const key = `${config.player.height}:${config.player.radius}`;
    if (key === this.shapeKey) return;
    this.shapeKey = key;
    const world = this.engine.physics;
    world.removeCollider(this.collider, false);
    this.collider = world.createCollider(this.makeShape(), this.body);
  }

  private makeShape(): RAPIER.ColliderDesc {
    const radius = Math.max(0.05, config.player.radius);
    const half = Math.max(0.05, config.player.height / 2 - radius);
    this.shapeKey = `${config.player.height}:${config.player.radius}`;
    return RAPIER.ColliderDesc.capsule(half, radius);
  }
}
