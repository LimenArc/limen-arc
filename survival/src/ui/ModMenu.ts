import type { Input } from '../core/Input';
import { el } from './controls';

export type TabBuilder = (root: HTMLElement) => void;

/** Docked panel with tabs. Tilde toggles it; gameplay input pauses while open. */
export class ModMenu {
  readonly root = el('aside', 'mod-menu');
  private readonly tabBar = el('nav', 'mod-tabs');
  private readonly body = el('div', 'mod-body');
  private readonly tabs: { id: string; label: string; build: TabBuilder }[] = [];
  private activeId = '';

  constructor(mount: HTMLElement, private readonly input: Input) {
    const header = el('header');
    header.append(el('h1', undefined, 'Mod Menu'), el('span', undefined, '~ to toggle'));
    this.root.append(header, this.tabBar, this.body);
    mount.appendChild(this.root);
    window.addEventListener('keydown', (event) => {
      const target = event.target as HTMLElement | null;
      const typing = target?.tagName === 'INPUT' || target?.tagName === 'TEXTAREA';
      if (event.code === 'Escape' && this.isOpen) {
        (target as HTMLElement | null)?.blur();
        this.toggle(false);
        return;
      }
      if (event.code !== 'Backquote' || typing) return;
      event.preventDefault();
      this.toggle();
    });
  }

  get isOpen(): boolean {
    return this.root.classList.contains('open');
  }

  addTab(id: string, label: string, build: TabBuilder): void {
    this.tabs.push({ id, label, build });
    const btn = el('button', undefined, label);
    btn.dataset.tab = id;
    btn.addEventListener('click', () => this.setActive(id));
    this.tabBar.append(btn);
    if (!this.activeId) this.setActive(id);
  }

  setActive(id: string): void {
    this.activeId = id;
    for (const btn of Array.from(this.tabBar.children) as HTMLElement[]) {
      btn.classList.toggle('active', btn.dataset.tab === id);
    }
    this.rebuild();
  }

  /** Rebuilds the visible tab — cheap, and keeps controls in sync with config. */
  rebuild(): void {
    const tab = this.tabs.find((entry) => entry.id === this.activeId);
    this.body.replaceChildren();
    tab?.build(this.body);
  }

  toggle(force?: boolean): void {
    const open = force ?? !this.isOpen;
    this.root.classList.toggle('open', open);
    this.input.setSuspended(open);
    if (open) this.rebuild();
  }
}
