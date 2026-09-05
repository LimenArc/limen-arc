/**
 * Tiny deep-reactive object helper.
 *
 * The whole game reads values straight off the live object every frame, so the
 * proxy exists only to (a) keep nested objects wrapped and (b) tell listeners
 * that something changed, for the few systems that need to react (seed change,
 * UI refresh, preset load).
 */

export type ChangeListener = (path: string, value: unknown, previous: unknown) => void;

export function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

export function reactive<T extends object>(target: T, notify: ChangeListener, path = ''): T {
  for (const key of Object.keys(target)) {
    const value = (target as Record<string, unknown>)[key];
    if (isPlainObject(value)) {
      (target as Record<string, unknown>)[key] = reactive(value, notify, join(path, key));
    }
  }
  return new Proxy(target, {
    set(obj, key, value) {
      if (typeof key === 'symbol') return Reflect.set(obj, key, value);
      const full = join(path, key);
      const previous = (obj as Record<string, unknown>)[key];
      if (previous === value) return true;
      (obj as Record<string, unknown>)[key] = isPlainObject(value)
        ? reactive(value, notify, full)
        : value;
      notify(full, value, previous);
      return true;
    },
  });
}

function join(path: string, key: string): string {
  return path ? `${path}.${key}` : key;
}

export function getPath(root: unknown, path: string): unknown {
  return path.split('.').reduce<unknown>((acc, key) => {
    if (acc === null || typeof acc !== 'object') return undefined;
    return (acc as Record<string, unknown>)[key];
  }, root);
}

export function setPath(root: object, path: string, value: unknown): void {
  const keys = path.split('.');
  const last = keys.pop()!;
  let node: Record<string, unknown> = root as Record<string, unknown>;
  for (const key of keys) {
    const next = node[key];
    if (!isPlainObject(next)) return;
    node = next;
  }
  node[last] = value;
}

export type Leaf = { path: string; value: number | boolean | string };

/** Flattens every scalar in the object to a dotted path, in declaration order. */
export function leaves(root: object, path = '', out: Leaf[] = []): Leaf[] {
  for (const [key, value] of Object.entries(root)) {
    const full = join(path, key);
    if (isPlainObject(value)) leaves(value, full, out);
    else if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'string') {
      out.push({ path: full, value });
    }
  }
  return out;
}

export function clone<T>(value: T): T {
  return structuredClone(value);
}
