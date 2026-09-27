// DEV_AR_MOCK automation: drive the web mock in headless Edge/Chrome and capture screenshots + logs.
// Usage: node scripts/mock-shot.mjs <path-or-url> <out.png> [waitMs]
//   env BROWSER=<exe> to override the browser, HEADFUL=1 to watch.
import puppeteer from "puppeteer-core";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const candidates = [
  process.env.BROWSER,
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "/usr/bin/chromium",
  "/usr/bin/google-chrome",
].filter(Boolean);
export const executablePath = candidates.find((p) => existsSync(p));

export async function launch() {
  return puppeteer.launch({
    executablePath,
    headless: !process.env.HEADFUL,
    args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"],
    defaultViewport: { width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: false },
  });
}

export async function openPage(browser, url, logs) {
  const page = await browser.newPage();
  page.on("console", (m) => {
    const t = m.text();
    if (!/tangents|Loaded default scene/.test(t)) logs.push(`[${m.type()}] ${t}`);
  });
  page.on("pageerror", (e) => logs.push(`[pageerror] ${e.message}`));
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  return page;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [, , target = "/", out = "shot.png", wait = "8000"] = process.argv;
  const url = target.startsWith("http") ? target : `http://localhost:8081${target}`;
  const logs = [];
  const browser = await launch();
  try {
    const page = await openPage(browser, url, logs);
    await new Promise((r) => setTimeout(r, Number(wait)));
    await page.screenshot({ path: out });
    console.log(logs.slice(-40).join("\n"));
    console.log("saved", out);
  } finally {
    await browser.close();
  }
}
