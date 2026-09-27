// Copies the Viro WASM renderer into public/viro so Expo web (DEV_AR_MOCK) can serve it.
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
const src = new URL("../node_modules/@reactvision/viro-web-renderer/wasm/", import.meta.url);
const dst = new URL("../public/viro/", import.meta.url);
if (!existsSync(src)) process.exit(0); // renderer not installed (native-only checkout)
mkdirSync(dst, { recursive: true });
for (const f of ["viro-web.js", "viro-web.wasm", "viro-web.data"]) copyFileSync(new URL(f, src), new URL(f, dst));
console.log("viro web renderer copied to public/viro");
