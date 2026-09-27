# Build & run

Expo Go **cannot** run this app (ViroReact is native). Use a development build.

## Prerequisites

- Node 22+ (tests use Node's built-in TypeScript stripping), Yarn 1
- JDK 17, Android SDK (platform 36, build-tools 36), `ANDROID_HOME` set
- A physical **ARCore-supported arm64 Android phone** for AR. The Viro native renderer ships only
  `arm64-v8a`/`armeabi-v7a` libraries, so x86_64 emulators cannot run it.

## Android (AR, production path)

```bash
yarn install
npx expo prebuild -p android --clean
cd android
./gradlew assembleDebug            # → app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/debug/app-debug.apk
npx expo start --dev-client        # from the repo root, then open the app on the phone
```

`android/` is generated; don't hand-edit it. For faster local builds you can set
`reactNativeArchitectures=arm64-v8a` in `android/gradle.properties` after prebuild.

### Network troubleshooting (seen on this machine)

- `PKIX path building failed` while Gradle downloads: the JVM doesn't trust the network's TLS chain.
  Run Gradle with the OS trust store: `JAVA_TOOL_OPTIONS=-Djavax.net.ssl.trustStoreType=Windows-ROOT`.
- `Read timed out` on slow links: raise `networkTimeout` in `android/gradle/wrapper/gradle-wrapper.properties`
  and add `systemProp.org.gradle.internal.http.socketTimeout=300000` to `android/gradle.properties`.

## DEV_AR_MOCK (no AR hardware)

A fixed virtual table stands in for the AR plane; the world, board, engine, animations and effects are
the same code as AR. Web always runs in mock mode. On a device, set `EXPO_PUBLIC_DEV_AR_MOCK=true`.

```bash
npx expo export -p web             # static build → dist/ (copies the Viro WASM renderer from public/viro)
node scripts/serve-dist.mjs 8090   # http://localhost:8090  (add ?autoplace=1 on /play to skip placement)
node scripts/mock-e2e.mjs http://localhost:8090 e2e-out   # headless Edge/Chrome e2e + screenshots
```

Use the static export for automation: the Metro dev server (`expo start --web`) was unreliable for the
WASM page in this environment.

## Assets

```bash
yarn gen:assets    # regenerates every model, texture and sound (original, code-generated)
```
