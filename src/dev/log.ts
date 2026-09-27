/** Tagged diagnostics for device sessions: `adb logcat -s ReactNativeJS | grep CrystalsAR`. */
export function arLog(event: string, data?: Record<string, unknown>) {
  console.log(`[CrystalsAR] ${event}${data ? " " + JSON.stringify(data) : ""}`);
}
