import {
  config,
  metaFor,
  onConfigChange,
  setConfigPath,
  type FieldMeta,
} from '../config/GameConfig';
import { getPath } from '../config/reactive';

/**
 * Every control here is a two-way binding to a GameConfig path. Nothing else in
 * the UI is allowed to hold state — the config is the state.
 */
const refreshers = new Map<string, Set<() => void>>();

onConfigChange((path) => {
  for (const fn of refreshers.get(path) ?? []) fn();
});

function bind(path: string, refresh: () => void): void {
  let set = refreshers.get(path);
  if (!set) refreshers.set(path, (set = new Set()));
  set.add(refresh);
}

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  text?: string,
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

export function labelText(path: string, meta: FieldMeta): string {
  if (meta.label) return meta.label;
  const leaf = path.split('.').pop() ?? path;
  return leaf.replace(/([A-Z])/g, ' $1').replace(/^./, (c) => c.toUpperCase());
}

export function numberControl(path: string, override: FieldMeta = {}): HTMLElement {
  const value = Number(getPath(config, path));
  const meta = { ...metaFor(path, value), ...override };
  const wrap = el('div', 'ctl');
  const head = el('div', 'ctl-label');
  head.append(el('span', undefined, labelText(path, meta)), el('span', 'path', path));
  const row = el('div', 'ctl-row');
  const slider = el('input');
  slider.type = 'range';
  const field = el('input');
  field.type = 'number';
  const min = meta.min ?? 0;
  const max = meta.max ?? Math.max(1, value * 4);
  const step = meta.step ?? 0.01;
  for (const input of [slider, field]) {
    input.min = String(min);
    input.max = String(max);
    input.step = String(step);
  }
  field.step = String(step);
  row.append(slider, field);
  wrap.append(head, row);
  if (meta.hint) wrap.append(el('small', undefined, meta.hint));

  const refresh = () => {
    const current = Number(getPath(config, path));
    slider.value = String(current);
    if (document.activeElement !== field) field.value = String(round(current, step));
  };
  const commit = (raw: string) => {
    const parsed = Number(raw);
    if (!Number.isFinite(parsed)) return;
    setConfigPath(path, meta.integer ? Math.round(parsed) : parsed);
    refresh();
  };
  slider.addEventListener('input', () => commit(slider.value));
  field.addEventListener('input', () => commit(field.value));
  field.addEventListener('blur', refresh);
  bind(path, refresh);
  refresh();
  return wrap;
}

export function toggleControl(path: string, override: FieldMeta = {}): HTMLElement {
  const meta = { ...metaFor(path, Boolean(getPath(config, path))), ...override };
  const wrap = el('div', 'ctl toggle');
  const label = el('label');
  const box = el('input');
  box.type = 'checkbox';
  const name = el('span', undefined, labelText(path, meta));
  const pathTag = el('span', 'path', path);
  pathTag.style.marginLeft = 'auto';
  label.append(box, name, pathTag);
  wrap.append(label);
  if (meta.hint) wrap.append(el('small', undefined, meta.hint));
  const refresh = () => {
    box.checked = Boolean(getPath(config, path));
  };
  box.addEventListener('change', () => setConfigPath(path, box.checked));
  bind(path, refresh);
  refresh();
  return wrap;
}

export function textControl(path: string, override: FieldMeta = {}): HTMLElement {
  const meta = { ...metaFor(path, String(getPath(config, path))), ...override };
  const wrap = el('div', 'ctl');
  const head = el('div', 'ctl-label');
  head.append(el('span', undefined, labelText(path, meta)), el('span', 'path', path));
  const field = el('input');
  field.type = 'text';
  field.className = 'grow';
  wrap.append(head, field);
  const refresh = () => {
    if (document.activeElement !== field) field.value = String(getPath(config, path));
  };
  field.addEventListener('change', () => setConfigPath(path, field.value));
  bind(path, refresh);
  refresh();
  return wrap;
}

/** Picks the right control for whatever the value happens to be. */
export function autoControl(path: string, override: FieldMeta = {}): HTMLElement {
  const value = getPath(config, path);
  if (typeof value === 'boolean') return toggleControl(path, override);
  if (typeof value === 'string') return textControl(path, override);
  return numberControl(path, override);
}

export function button(label: string, onClick: () => void, className = ''): HTMLButtonElement {
  const node = el('button', `mod-btn ${className}`.trim(), label);
  node.addEventListener('click', onClick);
  return node;
}

export function buttonRow(...buttons: HTMLElement[]): HTMLElement {
  const row = el('div', 'mod-btns');
  row.append(...buttons);
  return row;
}

export function section(title: string, open = true): HTMLDetailsElement {
  const details = el('details', 'mod-section');
  details.open = open;
  const summary = el('summary', undefined, title);
  const body = el('div');
  details.append(summary, body);
  (details as HTMLDetailsElement & { body: HTMLElement }).body = body;
  return details as HTMLDetailsElement;
}

export function sectionBody(details: HTMLDetailsElement): HTMLElement {
  return (details as HTMLDetailsElement & { body: HTMLElement }).body;
}

function round(value: number, step: number): number {
  const digits = Math.min(6, Math.max(0, Math.ceil(-Math.log10(step || 0.01))));
  return Number(value.toFixed(digits));
}
