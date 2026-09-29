// Copies the Viro WASM renderer into public/viro so Expo web (DEV_AR_MOCK) can serve it.
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
const src = new URL("../node_modules/@reactvision/viro-web-renderer/wasm/", import.meta.url);
const dst = new URL("../public/viro/", import.meta.url);
if (!existsSync(src)) process.exit(0); // renderer not installed (native-only checkout)
mkdirSync(dst, { recursive: true });
for (const f of ["viro-web.js", "viro-web.wasm", "viro-web.data"]) copyFileSync(new URL(f, src), new URL(f, dst));
console.log("viro web renderer copied to public/viro");

// Skia (CanvasKit) for the web build of the UI: served at /canvaskit.wasm
const ck = new URL("../node_modules/canvaskit-wasm/bin/full/canvaskit.wasm", import.meta.url);
if (existsSync(ck)) {
  copyFileSync(ck, new URL("../public/canvaskit.wasm", import.meta.url));
  console.log("canvaskit.wasm copied to public/");
}
