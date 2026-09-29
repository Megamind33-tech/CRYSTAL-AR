// Renders the Armory item icons: real textured Meshy crystals, lit with a studio HDRI, PBR gloss and bloom, in headless Chromium.
//   cd tools/asset-pipeline && npm install && node render-icons.mjs [id ...]   -> assets/ui/armory/<id>.jpg
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
for (const spec of ICONS.filter((i) => !want.length || want.includes(i.id))) {
  const url = await page.evaluate((s) => window.renderIcon(s), spec);
  await sharp(Buffer.from(url.split(",")[1], "base64")).jpeg({ quality: 88, mozjpeg: true }).toFile(join(out, `${spec.id}.jpg`));
  console.log("rendered", spec.id);
}
await browser.close();
server.close();
