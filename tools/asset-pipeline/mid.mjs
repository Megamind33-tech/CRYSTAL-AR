// Stage 1 for the islands: 2-8M triangle source -> ~60k triangle intermediate (position-welded simplify), so
// the texture-preserving reprojection in stage 2 searches a small mesh instead of millions of triangles.
import { NodeIO } from "@gltf-transform/core";
import { ALL_EXTENSIONS } from "@gltf-transform/extensions";
import { flatten } from "@gltf-transform/functions";
import { simplifyTo } from "./lib.mjs";
const RAW = process.env.MESHY_GLB ?? "/tmp/claude-0/-home-user-CRYSTAL-AR/0531187c-a8ed-5fa3-8210-3b3afe0b21ee/scratchpad/meshy/glb/";
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
for (const realm of process.argv.slice(2)) {
  const doc = await io.read(`${RAW}${realm}_realm_island.glb`);
  await doc.transform(flatten());
  const r = await simplifyTo(doc, io, 60000);
  await io.write(`.cache/mid/${realm}.glb`, r.doc);
  console.log(realm, r.tris);
}
