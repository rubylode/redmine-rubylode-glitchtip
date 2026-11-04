// Takes the README screenshots from the demo (ruby bin/demo up first) with Playwright.
//
//   npm install --no-save --no-package-lock playwright && npx playwright install chromium
//   node script/screenshots.mjs
//
// Writes docs/screenshots/*.png. The data is the fake GlitchTip's, so nothing in them is real.
import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import path from "node:path";

const redmine = "http://localhost:3014";
const fakeGlitchtip = "http://localhost:9114";
const outputFolder = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "docs", "screenshots");

async function useScenario(name) {
  const response = await fetch(`${fakeGlitchtip}/__scenario/${name}`, { method: "POST" });
  if (!response.ok) throw new Error(`scenario ${name}: ${response.status}`);
}

const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 1200, height: 800 }, deviceScaleFactor: 2 })).newPage();

await page.goto(`${redmine}/login`);
await page.fill("#username", "admin");
await page.fill("#password", "admin");
await page.click("#login-submit");

async function shoot(fileName, url, selector) {
  await page.goto(`${redmine}${url}`);
  await page.locator(selector).first().screenshot({ path: path.join(outputFolder, fileName) });
  console.log(`wrote ${fileName}`);
}

await useScenario("several");
await shoot("errors-page.png", "/status/glitchtip", "#content .rubylode-glitchtip-errors");
await shoot("wiki-macro.png", "/projects/storefront/wiki", "#content .rubylode-glitchtip-errors");
await shoot("compact-on-issues.png", "/issues", "#content .rubylode-glitchtip-errors");
await shoot("welcome-page.png", "/", "#content");
await useScenario("none");
await shoot("errors-none.png", "/status/glitchtip", "#content .rubylode-glitchtip-errors");
await useScenario("unavailable");
await shoot("errors-unavailable.png", "/status/glitchtip", "#content .rubylode-glitchtip-errors");
await useScenario("several");
await shoot("settings.png", "/settings/plugin/redmine_rubylode_glitchtip", ".rubylode-glitchtip-placements");
await shoot("settings-help.png", "/settings/plugin/redmine_rubylode_glitchtip", ".rubylode-glitchtip-help");

await browser.close();
