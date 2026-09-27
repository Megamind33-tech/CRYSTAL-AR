#!/usr/bin/env bash
# Builds the standalone test APK. Always writes builds/CrystalsAR.apk (overwritten);
# each run bumps the patch version and Android versionCode in app.json.
# Usage: bash scripts/build-apk.sh [--no-bump] [--prebuild]
#   --prebuild  regenerate android/ from app.json + plugins (needed after native/config changes)
set -euo pipefail
cd "$(dirname "$0")/.."
BUMP=1; PREBUILD=0
for a in "$@"; do case "$a" in --no-bump) BUMP=0;; --prebuild) PREBUILD=1;; esac; done
[ -d android ] || PREBUILD=1
if [ "$BUMP" = 1 ]; then
  node -e "
    const fs=require('fs');const a=JSON.parse(fs.readFileSync('app.json','utf8'));
    const [M,m,p]=a.expo.version.split('.').map(Number);a.expo.version=[M,m,p+1].join('.');
    a.expo.android.versionCode=(a.expo.android.versionCode||1)+1;
    fs.writeFileSync('app.json',JSON.stringify(a,null,2)+'\n');
    console.log('version',a.expo.version,'code',a.expo.android.versionCode);"
fi
export CRYSTALS_ABIS="${CRYSTALS_ABIS:-arm64-v8a}" CRYSTALS_MAVEN_LOCAL="${CRYSTALS_MAVEN_LOCAL:-1}" CI=1
if [ "$PREBUILD" = 1 ]; then
  npx expo prebuild -p android --no-install > /dev/null
else
  node scripts/stamp-version.mjs  # keep android/ as is; just stamp the version
fi
export ANDROID_HOME="${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}"
[ -f android/local.properties ] || echo "sdk.dir=$(cygpath -m "$ANDROID_HOME" 2>/dev/null || echo "$ANDROID_HOME")" > android/local.properties
export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStoreType=Windows-ROOT"
(cd android && ./gradlew assembleRelease -q)
mkdir -p builds
cp android/app/build/outputs/apk/release/app-release.apk builds/CrystalsAR.apk
echo "builds/CrystalsAR.apk  v$(node -p "require('./app.json').expo.version")"
