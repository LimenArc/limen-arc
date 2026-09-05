import { clone, leaves, reactive, setPath, type ChangeListener, type Leaf } from './reactive';

/**
 * THE config. Every tunable number in the game lives here and is read fresh by
 * the systems each frame — no system caches a value, no system owns a constant.
 * The mod menu is nothing but a UI bound to this object.
 */
export const DEFAULT_CONFIG = {
  player: {
    moveSpeed: 5.2,
    sprintMultiplier: 1.75,
    crouchMultiplier: 0.45,
    jumpHeight: 1.2,
    gravityScale: 1,
    airControl: 0.35,
    groundAcceleration: 14,
    airAcceleration: 4,
    eyeHeight: 1.62,
    crouchEyeHeight: 1.05,
    height: 1.8,
    radius: 0.34,
    stepHeight: 0.45,
    maxSlopeDegrees: 52,
    mouseSensitivity: 0.0022,
    godmode: false,
    infiniteStamina: false,
    flight: false,
    flySpeed: 16,
    flyBoostMultiplier: 3,
    noclip: false,
  },
  physics: {
    gravity: -20,
    fixedStep: 1 / 60,
    maxSubSteps: 5,
    maxFallSpeed: 60,
  },
  world: {
    seed: 1337,
  },
  render: {
    fov: 78,
    nearPlane: 0.1,
    farPlane: 1400,
    pixelRatioCap: 2,
    fogDensity: 0.0038,
    sunIntensity: 2.1,
    ambientIntensity: 0.55,
  },
  debug: {
    showStats: true,
    wireframe: false,
    timeScale: 1,
  },
};

export type GameConfig = typeof DEFAULT_CONFIG;

const listeners = new Set<ChangeListener>();
const notify: ChangeListener = (path, value, previous) => {
  for (const listener of listeners) listener(path, value, previous);
};

export const config: GameConfig = reactive(clone(DEFAULT_CONFIG), notify);

export function onConfigChange(listener: ChangeListener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/** Writes a dotted path through the proxy so listeners fire. */
export function setConfigPath(path: string, value: unknown): void {
  setPath(config, path, value);
}

export function configLeaves(): Leaf[] {
  return leaves(config);
}

export function snapshot(): Record<string, number | boolean | string> {
  const out: Record<string, number | boolean | string> = {};
  for (const leaf of leaves(config)) out[leaf.path] = leaf.value;
  return out;
}

/** Applies a flat snapshot; unknown paths are ignored so old presets still load. */
export function applySnapshot(flat: Record<string, number | boolean | string>): void {
  const known = new Set(leaves(config).map((leaf) => leaf.path));
  for (const [path, value] of Object.entries(flat)) {
    if (known.has(path)) setConfigPath(path, value);
  }
}

export function resetToVanilla(): void {
  applySnapshot(
    Object.fromEntries(leaves(clone(DEFAULT_CONFIG)).map((leaf) => [leaf.path, leaf.value])),
  );
}

export interface FieldMeta {
  label?: string;
  min?: number;
  max?: number;
  step?: number;
  /** Integer-only field (seed, level, counts). */
  integer?: boolean;
  hint?: string;
}

/**
 * Optional hints for the auto-generated tuning editor. Anything missing still
 * gets a control — the editor infers a sane range from the default value.
 */
export const META: Record<string, FieldMeta> = {
  'player.moveSpeed': { min: 0, max: 40, step: 0.1, hint: 'Base walk speed (m/s)' },
  'player.sprintMultiplier': { min: 1, max: 10, step: 0.05 },
  'player.crouchMultiplier': { min: 0.05, max: 1, step: 0.01 },
  'player.jumpHeight': { min: 0, max: 20, step: 0.05, hint: 'Metres of apex height' },
  'player.gravityScale': { min: -2, max: 5, step: 0.05 },
  'player.airControl': { min: 0, max: 1, step: 0.01 },
  'player.mouseSensitivity': { min: 0.0002, max: 0.01, step: 0.0001 },
  'player.eyeHeight': { min: 0.3, max: 3, step: 0.01 },
  'player.crouchEyeHeight': { min: 0.3, max: 3, step: 0.01 },
  'player.height': { min: 0.6, max: 4, step: 0.05 },
  'player.radius': { min: 0.1, max: 1.5, step: 0.01 },
  'player.stepHeight': { min: 0, max: 2, step: 0.05 },
  'player.maxSlopeDegrees': { min: 5, max: 89, step: 1 },
  'player.flySpeed': { min: 1, max: 120, step: 0.5 },
  'player.flyBoostMultiplier': { min: 1, max: 10, step: 0.1 },
  'physics.gravity': { min: -60, max: 10, step: 0.1 },
  'physics.fixedStep': { min: 1 / 240, max: 1 / 20, step: 0.001 },
  'physics.maxSubSteps': { min: 1, max: 10, step: 1, integer: true },
  'physics.maxFallSpeed': { min: 5, max: 200, step: 1 },
  'world.seed': { min: 0, max: 999999, step: 1, integer: true },
  'render.fov': { min: 40, max: 130, step: 1 },
  'render.farPlane': { min: 100, max: 4000, step: 10 },
  'render.pixelRatioCap': { min: 0.5, max: 3, step: 0.1 },
  'render.fogDensity': { min: 0, max: 0.02, step: 0.0001 },
  'render.sunIntensity': { min: 0, max: 8, step: 0.05 },
  'render.ambientIntensity': { min: 0, max: 4, step: 0.05 },
  'debug.timeScale': { min: 0, max: 4, step: 0.05 },
};

/** Meta for a path, filling in a plausible range when none was declared. */
export function metaFor(path: string, value: number | boolean | string): FieldMeta {
  const declared = META[path] ?? {};
  if (typeof value !== 'number') return declared;
  if (declared.min !== undefined && declared.max !== undefined) return declared;
  const magnitude = Math.max(Math.abs(value), 1);
  const integer = declared.integer ?? Number.isInteger(value);
  return {
    min: declared.min ?? (value < 0 ? -magnitude * 4 : 0),
    max: declared.max ?? magnitude * 4,
    step: declared.step ?? (integer ? 1 : magnitude / 200),
    integer,
    ...declared,
  };
}
