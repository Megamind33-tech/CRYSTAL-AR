// Native: Skia ships inside the app, nothing to load. The web version lives in loadSkia.web.ts.
export function loadSkia(): Promise<void> {
  return Promise.resolve();
}
