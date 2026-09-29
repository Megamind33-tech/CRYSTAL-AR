// Web only: CanvasKit (Skia's engine) must load before any Skia view mounts. Kept in a .web file so
// Metro never pulls canvaskit-wasm into the Android bundle.
export function loadSkia(): Promise<void> {
  return import("@shopify/react-native-skia/lib/module/web").then(({ LoadSkiaWeb }) => LoadSkiaWeb({ locateFile: () => "/canvaskit.wasm" }));
}
