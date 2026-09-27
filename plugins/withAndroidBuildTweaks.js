// Applies Android build settings that must survive `expo prebuild --clean`.
// - ABIs: Viro ships arm64-v8a/armeabi-v7a only. Override with CRYSTALS_ABIS=arm64-v8a for faster dev builds.
// - Slow-network tolerance for Gradle downloads.
// - CRYSTALS_MAVEN_LOCAL=1: resolve the very large React Native / Hermes AARs from ~/.m2 (pre-fetched
//   with curl) when the JVM keeps failing to download them. Scoped to those two groups only.
const fs = require("fs");
const path = require("path");
const { withAndroidManifest, withGradleProperties, withDangerousMod, withProjectBuildGradle } = require("expo/config-plugins");

// Permissions merged in from the Viro AAR that a tabletop AR game does not use.
const STRIP_PERMISSIONS = ["android.permission.RECORD_AUDIO", "android.permission.NFC", "com.oculus.permission.EYE_TRACKING"];

const set = (props, key, value) => {
  const i = props.findIndex((p) => p.type === "property" && p.key === key);
  const entry = { type: "property", key, value };
  if (i >= 0) props[i] = entry;
  else props.push(entry);
};

module.exports = function withAndroidBuildTweaks(config) {
  config = withAndroidManifest(config, (c) => {
    const m = c.modResults.manifest;
    m.$ = { ...m.$, "xmlns:tools": "http://schemas.android.com/tools" };
    m["uses-permission"] = (m["uses-permission"] ?? []).filter((x) => !STRIP_PERMISSIONS.includes(x.$["android:name"]));
    for (const name of STRIP_PERMISSIONS) m["uses-permission"].push({ $: { "android:name": name, "tools:node": "remove" } });
    return c;
  });
  if (process.env.CRYSTALS_MAVEN_LOCAL === "1") {
    config = withProjectBuildGradle(config, (c) => {
      const block = 'mavenLocal { content { includeGroup("com.facebook.react"); includeGroup("com.facebook.hermes") } }';
      if (!c.modResults.contents.includes("mavenLocal {")) {
        c.modResults.contents = c.modResults.contents.replace(/allprojects \{\s*repositories \{/, (m) => m + "\n    " + block);
      }
      return c;
    });
  }
  config = withGradleProperties(config, (c) => {
    set(c.modResults, "reactNativeArchitectures", process.env.CRYSTALS_ABIS || "arm64-v8a,armeabi-v7a");
    // incremental speed: reuse task outputs across builds (JS-only changes rebuild in minutes)
    set(c.modResults, "org.gradle.caching", "true");
    set(c.modResults, "org.gradle.parallel", "true");
    set(c.modResults, "systemProp.org.gradle.internal.http.socketTimeout", "300000");
    set(c.modResults, "systemProp.org.gradle.internal.http.connectionTimeout", "300000");
    return c;
  });
  return withDangerousMod(config, [
    "android",
    (c) => {
      const f = path.join(c.modRequest.platformProjectRoot, "gradle", "wrapper", "gradle-wrapper.properties");
      if (fs.existsSync(f)) {
        let s = fs.readFileSync(f, "utf8");
        s = /networkTimeout=/.test(s) ? s.replace(/networkTimeout=\d+/, "networkTimeout=600000") : s + "\nnetworkTimeout=600000\n";
        fs.writeFileSync(f, s);
      }
      return c;
    },
  ]);
};
