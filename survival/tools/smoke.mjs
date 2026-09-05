// Headless smoke test: boots the built game, checks for console/page errors,
// exercises the mod menu, and screenshots the result.
import { chromium } from 'playwright';
import { createServer } from 'vite';

const server = await createServer({ root: process.cwd(), server: { port: 5199 } });
await server.listen();

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
page.on('requestfailed', (r) => errors.push('requestfailed ' + r.url()));
page.on('response', (r) => { if (r.status() >= 400) errors.push(`HTTP ${r.status()} ${r.url()}`); });
page.on('pageerror', (e) => errors.push(String(e)));

await page.goto('http://localhost:5199/', { waitUntil: 'load' });
await page.waitForSelector('.stats', { timeout: 20000 });
await page.waitForTimeout(1500);

const steps = process.argv.slice(2);
for (const step of steps) {
  if (step.startsWith('key:')) await page.keyboard.press(step.slice(4));
  if (step.startsWith('wait:')) await page.waitForTimeout(Number(step.slice(5)));
  if (step.startsWith('click:')) await page.click(step.slice(6));
  if (step.startsWith('shot:')) await page.screenshot({ path: step.slice(5) });
}

const stats = await page.textContent('.stats');
console.log('--- stats ---\n' + stats);
console.log('--- errors ---\n' + (errors.length ? errors.join('\n') : '(none)'));
await page.screenshot({ path: 'tools/smoke.png' });
await browser.close();
await server.close();
process.exit(errors.length ? 1 : 0);
