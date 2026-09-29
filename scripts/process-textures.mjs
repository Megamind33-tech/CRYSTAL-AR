// Turns the downloaded CC0 PBR material packs (ambientCG, 1K-JPG) into small mobile textures.
// Keeps colour, OpenGL normal and roughness maps; resizes to 512 px with ffmpeg.
// Source zips live outside the repo (see ASSET_LICENSES.md for the list and licence).
// Usage: node scripts/process-textures.mjs [cacheDir]
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const cache = process.argv[2] ?? join(process.env.LOCALAPPDATA ?? process.env.HOME ?? ".", "crystals-asset-cache", "acg");
const out = new URL("../assets/textures/pbr/", import.meta.url);
mkdirSync(out, { recursive: true });

/** game material id → ambientCG asset */
export const PBR_SOURCES = {
  grass: "Grass004",
  moss: "Ground037",
  rock: "Rock063",
  cliff: "Rock051",
  rockMoss: "Rock064",
  rockDark: "Rock058",
  sand: "Ground054",
  snow: "Snow014",
  ice: "Ice003",
  lava: "Lava004",
  bark: "Bark014",
  dirt: "Ground109",
  gravel: "Gravel023",
  paving: "PavingStones138",
};
const MAPS = { c: "Color", n: "NormalGL", r: "Roughness" };
const SIZE = 512;

const tmp = join(cache, "_extract");
let total = 0;
for (const [id, asset] of Object.entries(PBR_SOURCES)) {
  const zip = join(cache, `${asset}.zip`);
  if (!existsSync(zip)) {
    console.log("missing", zip);
    continue;
  }
  rmSync(tmp, { recursive: true, force: true });
  mkdirSync(tmp, { recursive: true });
  const names = Object.values(MAPS).map((m) => `${asset}_1K-JPG_${m}.jpg`);
  execFileSync("unzip", ["-o", "-q", zip, ...names, "-d", tmp]);
  for (const [suffix, map] of Object.entries(MAPS)) {
    const src = join(tmp, `${asset}_1K-JPG_${map}.jpg`);
    const dst = new URL(`${id}_${suffix}.jpg`, out);
    // colour gets slightly stronger compression; normals keep more quality (artifacts show as lighting noise)
    const q = suffix === "n" ? "3" : "5";
    execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", src, "-vf", `scale=${SIZE}:${SIZE}:flags=lanczos`, "-q:v", q, fileURLToPath(dst)]);
    total += statSync(dst).size;
  }
  console.log(id.padEnd(9), asset);
}
rmSync(tmp, { recursive: true, force: true });
console.log(`total ${(total / 1024 / 1024).toFixed(2)} MB`);
