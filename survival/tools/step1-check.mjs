// Verifies the config-drives-everything claim: editing player.moveSpeed in the
// mod menu changes how far the player actually walks in one second.
import { chromium } from 'playwright';
import { createServer } from 'vite';

const server = await createServer({ root: process.cwd(), server: { port: 5198 } });
await server.listen();
const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
await page.goto('http://localhost:5198/', { waitUntil: 'load' });
await page.waitForSelector('.stats');
await page.waitForTimeout(1200);

const pos = async () => {
  const line = (await page.textContent('.stats')).split('\n')[1];
  return line.split(/\s+/).slice(1).map(Number);
};

async function walk(seconds) {
  const before = await pos();
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(seconds * 1000);
  await page.keyboard.up('KeyW');
  const after = await pos();
  return Math.hypot(after[0] - before[0], after[2] - before[2]) / seconds;
}

const slow = await walk(1.5);
// Drive the change through the mod menu UI, not through code.
await page.keyboard.press('Backquote');
await page.fill('.mod-body .ctl:has-text("Move Speed") input[type="number"]', '16');
await page.dispatchEvent('.mod-body .ctl:has-text("Move Speed") input[type="number"]', 'input');
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
const fast = await walk(1.5);

console.log(`walk speed @5.2 = ${slow.toFixed(2)} m/s, @16 = ${fast.toFixed(2)} m/s`);
await browser.close();
await server.close();
const ok = slow > 3 && slow < 6.5 && fast > 11;
console.log(ok ? 'PASS' : 'FAIL');
process.exit(ok ? 0 : 1);
