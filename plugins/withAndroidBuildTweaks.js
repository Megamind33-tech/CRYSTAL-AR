// Applies Android build settings that must survive `expo prebuild --clean`.
// - ABIs: Viro ships arm64-v8a/armeabi-v7a only. Override with CRYSTALS_ABIS=arm64-v8a for faster dev builds.
// - Slow-network tolerance for Gradle downloads.
const fs = require("fs");
const path = require("path");
const { withGradleProperties, withDangerousMod } = require("expo/config-plugins");

const set = (props, key, value) => {
  const i = props.findIndex((p) => p.type === "property" && p.key === key);
  const entry = { type: "property", key, value };
  if (i >= 0) props[i] = entry;
  else props.push(entry);
};

module.exports = function withAndroidBuildTweaks(config) {
  config = withGradleProperties(config, (c) => {
    set(c.modResults, "reactNativeArchitectures", process.env.CRYSTALS_ABIS || "arm64-v8a,armeabi-v7a");
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
