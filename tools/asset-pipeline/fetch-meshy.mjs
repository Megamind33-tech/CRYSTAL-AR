// Downloads the raw Meshy GLBs named in config.mjs into .cache/src/ (git-ignored; ~25-60 MB each).
// The API key comes from the environment only and is never written anywhere:
//   MESHY_API_KEY=msy_... node fetch-meshy.mjs [--all]
// Meshy's download links expire after ~3 days, so run this while the tasks are fresh.
import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { ASSETS, SRC_DIR, slug } from "./config.mjs";

const key = process.env.MESHY_API_KEY;
if (!key) { console.error("Set MESHY_API_KEY"); process.exit(1); }
const get = async (url) => { const r = await fetch(url, { headers: { Authorization: `Bearer ${key}` } }); if (!r.ok) throw new Error(`${r.status} ${url.split("?")[0]}`); return r; };

mkdirSync(SRC_DIR, { recursive: true });
const tasks = await (await get("https://api.meshy.ai/openapi/v1/image-to-3d?page_size=50&sort_by=-created_at")).json();
const want = new Set(ASSETS.map((a) => a.name));
for (const t of tasks) {
  if (t.status !== "SUCCEEDED" || !t.model_urls?.glb) continue;
  if (!process.argv.includes("--all") && !want.has(t.name)) continue;
  const file = `${SRC_DIR}${slug(t.name)}.glb`;
  if (existsSync(file)) { console.log("have", slug(t.name)); continue; } // newest task wins (list is newest first)
  const buf = Buffer.from(await (await get(t.model_urls.glb)).arrayBuffer());
  writeFileSync(file, buf);
  console.log("saved", slug(t.name), (buf.length / 1e6).toFixed(1) + " MB");
}
