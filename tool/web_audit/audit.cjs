// Loads the release web build in a real browser and fails if anything is
// requested from another origin.
//
//   node tool/web_audit/audit.cjs [--screenshots=DIR]
//
// Build first with ./tool/build_web.sh. Needs Node and Playwright with
// Chromium (`npm install playwright && npx playwright install chromium`).
//
// What it checks, on several routes and after typing text that the bundled
// typeface cannot draw (which is what makes the engine look for a fallback
// font):
//
//   * every request made by the page is to the page's own origin;
//   * the content security policy is present and blocked nothing the app
//     needs (a blocked request to another origin is reported, and is the
//     policy doing its job, but it still fails the audit: the app should not
//     have tried);
//   * the page actually rendered (the Flutter view exists).
//
// This is the evidence behind the statement that the default web build makes
// no third-party requests. It does not cover a build made with --api-url,
// which talks to the account service by design.

const { createServer } = require('node:http');
const { readFile, mkdir } = require('node:fs/promises');
const { existsSync } = require('node:fs');
const { extname, join, normalize, resolve } = require('node:path');
const { chromium } = require('playwright');

const root = resolve(__dirname, '../..');
const webRoot = join(root, 'apps/launchpad_app/build/web');
const screenshotArg = process.argv.find((arg) => arg.startsWith('--screenshots='));
const screenshotDir = screenshotArg ? resolve(screenshotArg.split('=')[1]) : null;

if (!existsSync(join(webRoot, 'index.html'))) {
  console.error('No build found. Run ./tool/build_web.sh first.');
  process.exit(2);
}

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.symbols': 'text/plain',
  '.bin': 'application/octet-stream',
};

async function main() {
  const server = createServer(async (request, response) => {
    const path = decodeURIComponent(new URL(request.url, 'http://x').pathname);
    const file = normalize(join(webRoot, path === '/' ? 'index.html' : path));
    if (!file.startsWith(webRoot)) {
      response.writeHead(403).end();
      return;
    }
    try {
      const body = await readFile(file);
      response.writeHead(200, {
        'content-type': types[extname(file)] ?? 'application/octet-stream',
      });
      response.end(body);
    } catch {
      response.writeHead(404).end();
    }
  });
  await new Promise((done) => server.listen(0, '127.0.0.1', done));
  const origin = `http://127.0.0.1:${server.address().port}`;

  const routes = [
    ['home', '/#/'],
    ['onboarding', '/#/onboarding/interests'],
    ['browse', '/#/explore'],
    ['occupation', '/#/occupation?id=registered-nurse'],
    ['compare', '/#/compare?ids=electrician,registered-nurse'],
    ['interview', '/#/tools/interview?q=teamwork'],
    ['your-data', '/#/your-data'],
    ['account', '/#/account'],
  ];

  const views = [
    ['phone', { width: 390, height: 844 }, 'light'],
    ['tablet', { width: 834, height: 1112 }, 'light'],
    ['desktop', { width: 1440, height: 900 }, 'light'],
    ['desktop-dark', { width: 1440, height: 900 }, 'dark'],
  ];

  const offOrigin = new Set();
  const blocked = [];
  const pageErrors = [];
  let requestCount = 0;

  const browser = await chromium.launch();
  try {
    for (const [viewName, viewport, colorScheme] of views) {
      const context = await browser.newContext({
        viewport,
        colorScheme,
        deviceScaleFactor: screenshotDir ? 2 : 1,
        // The audit is about what the app asks for, so the service worker is
        // kept out of the way: every request reaches the handlers below.
        serviceWorkers: 'block',
      });
      const page = await context.newPage();
      page.on('request', (request) => {
        const url = request.url();
        if (url.startsWith('data:') || url.startsWith('blob:')) return;
        requestCount++;
        if (new URL(url).origin !== origin) offOrigin.add(url);
      });
      page.on('console', (message) => {
        const text = message.text();
        if (/Content Security Policy|Refused to/i.test(text)) blocked.push(text);
      });
      page.on('pageerror', (error) => pageErrors.push(String(error)));

      for (const [name, route] of routes) {
        await page.goto(origin + route, { waitUntil: 'networkidle' });
        await page.waitForSelector('flutter-view, flt-glass-pane', {
          state: 'attached',
          timeout: 30000,
        });
        await page.waitForTimeout(1200);
        if (screenshotDir && (viewName !== 'tablet' || name === 'home')) {
          await mkdir(screenshotDir, { recursive: true });
          await page.screenshot({ path: join(screenshotDir, `${name}-${viewName}.png`) });
        }
      }

      // Text outside the bundled typeface is what sends the engine looking for
      // a fallback font. Type some into the first text field and wait.
      await page.goto(origin + '/#/something-else', { waitUntil: 'networkidle' });
      await page.waitForTimeout(1200);
      await page.mouse.click(viewport.width / 2, Math.min(330, viewport.height / 2));
      await page.keyboard.type('日本語 한국어 العربية 😀 ελληνικά', { delay: 20 });
      await page.waitForTimeout(2500);

      const policy = await page
        .locator('meta[http-equiv="Content-Security-Policy"]')
        .getAttribute('content');
      if (!policy || !policy.includes("default-src 'self'")) {
        pageErrors.push('The page has no content security policy.');
      }
      await context.close();
    }
  } finally {
    await browser.close();
    server.close();
  }

  console.log(`Requests observed: ${requestCount}, all routes, ${views.length} viewports.`);
  let failed = false;
  if (requestCount < 10) {
    console.error('Too few requests were observed for the audit to mean anything.');
    failed = true;
  }
  if (offOrigin.size > 0) {
    console.error('Requests to another origin:');
    for (const url of offOrigin) console.error(`  ${url}`);
    failed = true;
  }
  if (blocked.length > 0) {
    console.error('The content security policy blocked:');
    for (const text of new Set(blocked)) console.error(`  ${text}`);
    failed = true;
  }
  if (pageErrors.length > 0) {
    console.error('Page errors:');
    for (const text of new Set(pageErrors)) console.error(`  ${text}`);
    failed = true;
  }
  if (failed) process.exit(1);
  console.log('No request left the page\'s own origin, and the policy blocked nothing.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
