// Renders the Armory item icons: real textured Meshy crystals, lit with a studio HDRI, PBR gloss and bloom, in headless Chromium.
//   cd tools/asset-pipeline && npm install && node render-icons.mjs [id ...]   -> assets/ui/armory/<id>.webp
import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";
import sharp from "sharp";
import { ICONS } from "./icons/icons.config.mjs";

const here = fileURLToPath(new URL("./", import.meta.url));
const repo = join(here, "../../");
const out = join(repo, "assets/ui/armory");
mkdirSync(out, { recursive: true });
const types = { ".html": "text/html", ".js": "text/javascript", ".glb": "model/gltf-binary", ".hdr": "application/octet-stream", ".jpg": "image/jpeg", ".png": "image/png" };
const roots = { "/three/": join(here, "node_modules/three/"), "/repo/": repo, "/": join(here, "icons/") };
const server = createServer((req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  const [prefix, root] = Object.entries(roots).find(([p]) => url.startsWith(p) && p !== "/") ?? ["/", roots["/"]];
  const file = normalize(join(root, url.slice(prefix.length) || "studio.html"));
  if (!file.startsWith(root) || !existsSync(file) || !statSync(file).isFile()) { res.writeHead(404).end(); return; }
  res.writeHead(200, { "content-type": types[extname(file)] ?? "application/octet-stream" });
  createReadStream(file).pipe(res);
}).listen(0);
const port = server.address().port;

const exe = process.env.BROWSER ?? ["/opt/pw-browsers/chromium-1194/chrome-linux/chrome", "/usr/bin/chromium", "/usr/bin/google-chrome"].find(existsSync);
const browser = await puppeteer.launch({ executablePath: exe, headless: true, args: ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"], defaultViewport: { width: 768, height: 768 } });
const page = await browser.newPage();
page.on("pageerror", (e) => console.error("[page]", e.message));
page.on("console", (m) => m.type() === "error" && console.error("[console]", m.text()));
await page.goto(`http://localhost:${port}/studio.html`);
await page.waitForFunction(() => window.__ready, { timeout: 120000 });
const want = process.argv.slice(2);
// Transparent output by difference matting: render on black and on white, then alpha = 1 - (white - black) / (W - B),
// colour = black / alpha. Additive glow survives as soft translucent light instead of a solid backdrop.
const raw = async (b64) => sharp(Buffer.from(b64.split(",")[1], "base64")).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
for (const spec of ICONS.filter((i) => !want.length || want.includes(i.id))) {
  const [bk, wh] = [await raw(await page.evaluate((s) => window.renderIcon(s, false), spec)), await raw(await page.evaluate((s) => window.renderIcon(s, true), spec))];
  const { width, height } = bk.info, n = width * height, outBuf = Buffer.alloc(n * 4);
  const B = [bk.data[0], bk.data[1], bk.data[2]], W = [wh.data[0], wh.data[1], wh.data[2]];
  for (let i = 0; i < n; i++) {
    let a = 0;
    for (let c = 0; c < 3; c++) a += 1 - (wh.data[i * 4 + c] - bk.data[i * 4 + c]) / Math.max(1, W[c] - B[c]);
    a = Math.min(1, Math.max(0, a / 3));
    for (let c = 0; c < 3; c++) outBuf[i * 4 + c] = a > 0.003 ? Math.min(255, Math.max(0, Math.round((bk.data[i * 4 + c] - B[c]) / a))) : 0;
    outBuf[i * 4 + 3] = Math.round(a * 255);
  }
  await sharp(outBuf, { raw: { width, height, channels: 4 } }).webp({ quality: 92, alphaQuality: 95, effort: 5 }).toFile(join(out, `${spec.id}.webp`));
  console.log("rendered", spec.id);
}
await browser.close();
server.close();
