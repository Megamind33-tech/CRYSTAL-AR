// Writes app.json's version / android.versionCode into android/app/build.gradle (no prebuild needed).
import { readFileSync, writeFileSync } from "node:fs";
const app = JSON.parse(readFileSync("app.json", "utf8")).expo;
const f = "android/app/build.gradle";
const g = readFileSync(f, "utf8")
  .replace(/versionCode \d+/, `versionCode ${app.android.versionCode}`)
  .replace(/versionName "[^"]*"/, `versionName "${app.version}"`);
writeFileSync(f, g);
console.log("stamped", app.version, app.android.versionCode);
