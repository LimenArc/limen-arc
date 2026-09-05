/** Keyboard + pointer-lock mouse state. UI panels can suspend gameplay input. */
export class Input {
  readonly keys = new Set<string>();
  mouseDX = 0;
  mouseDY = 0;
  wheel = 0;
  private readonly pressed = new Set<string>();
  private readonly mouseDown = new Set<number>();
  private readonly mousePressed = new Set<number>();
  private suspended = false;

  constructor(private readonly target: HTMLCanvasElement) {
    window.addEventListener('keydown', (e) => {
      if (isTypingTarget(e.target)) return;
      const code = e.code;
      if (!this.keys.has(code)) this.pressed.add(code);
      this.keys.add(code);
      if (SWALLOWED_KEYS.has(code)) e.preventDefault();
    });
    window.addEventListener('keyup', (e) => {
      this.keys.delete(e.code);
    });
    window.addEventListener('blur', () => {
      this.keys.clear();
      this.mouseDown.clear();
    });
    target.addEventListener('mousedown', (e) => {
      if (this.suspended) return;
      if (!this.mouseDown.has(e.button)) this.mousePressed.add(e.button);
      this.mouseDown.add(e.button);
    });
    window.addEventListener('mouseup', (e) => this.mouseDown.delete(e.button));
    window.addEventListener('mousemove', (e) => {
      if (!this.pointerLocked || this.suspended) return;
      this.mouseDX += e.movementX;
      this.mouseDY += e.movementY;
    });
    window.addEventListener('wheel', (e) => {
      if (this.suspended) return;
      this.wheel += Math.sign(e.deltaY);
    });
    target.addEventListener('click', () => {
      if (!this.suspended && !this.pointerLocked) void target.requestPointerLock();
    });
  }

  get pointerLocked(): boolean {
    return document.pointerLockElement === this.target;
  }

  /** True while gameplay input should be ignored (a menu owns the cursor). */
  setSuspended(value: boolean): void {
    this.suspended = value;
    if (value) {
      this.keys.clear();
      this.pressed.clear();
      this.mouseDown.clear();
      if (this.pointerLocked) document.exitPointerLock();
    }
  }

  get isSuspended(): boolean {
    return this.suspended;
  }

  down(code: string): boolean {
    return !this.suspended && this.keys.has(code);
  }

  /** True once, on the frame the key went down. */
  justPressed(code: string): boolean {
    return this.pressed.has(code);
  }

  mouseHeld(button: number): boolean {
    return !this.suspended && this.mouseDown.has(button);
  }

  mouseClicked(button: number): boolean {
    return this.mousePressed.has(button);
  }

  /** Call once at the end of every frame. */
  endFrame(): void {
    this.pressed.clear();
    this.mousePressed.clear();
    this.mouseDX = 0;
    this.mouseDY = 0;
    this.wheel = 0;
  }
}

const SWALLOWED_KEYS = new Set([
  'Space',
  'Tab',
  'ArrowUp',
  'ArrowDown',
  'ArrowLeft',
  'ArrowRight',
  'Backquote',
]);

function isTypingTarget(target: EventTarget | null): boolean {
  const el = target as HTMLElement | null;
  if (!el) return false;
  return el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable;
}
