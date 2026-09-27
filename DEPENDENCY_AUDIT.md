# Dependency audit

Baseline: ReactVision Expo TypeScript starter (Expo 57, React Native 0.86, `@reactvision/react-viro` 3.0.0).
Only dependencies added on top of the starter are listed.

| Name | Version | Purpose | License | Why the existing stack can't do it | Bundle / native impact | Decision |
|---|---|---|---|---|---|---|
| `expo-audio` | ~57.0.5 | SFX pool + ambient loop | MIT | `ViroSound` needs a mounted Viro scene (no menu audio) and re-mount tricks for one-shots; expo-audio gives preloaded players with `seekTo(0)+play()` | Native module (Expo SDK, small) | Keep |
| `expo-haptics` | ~57.0.3 | Swap/match/win feedback, Settings › Haptics | MIT | No haptics API in RN core | Tiny native module | Keep |
| `@react-native-async-storage/async-storage` | 2.2.0 | Settings + level progress persistence | MIT | No persistent KV store in RN core / starter | Small native module; localStorage on web | Keep |
| `@reactvision/viro-web-renderer` | 1.0.0 | DEV_AR_MOCK: renders the same Viro scene in a browser (WASM virocore) | MIT | Required peer for Viro's `.web` components | Web only (~3.8 MB wasm/data copied to `public/viro`); not in the Android APK | Keep (dev/CI) |
| `puppeteer-core` (dev) | 25.12.0 | Headless mock e2e + screenshots (`scripts/mock-e2e.mjs`) | Apache-2.0 | No browser automation in the stack | devDependency only; uses the installed Edge/Chrome, downloads nothing | Keep (dev) |

No other dependencies were added. Unused starter deps (`expo-location`, `@expo/ui`, `@expo/material-symbols`)
remain because removing them is a separate cleanup; they are not imported by game code.
