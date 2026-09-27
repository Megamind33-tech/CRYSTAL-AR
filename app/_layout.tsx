import { useEffect } from "react";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import "react-native-reanimated";
import { initAudio } from "@/src/audio/AudioManager";
import { loadPersisted } from "@/src/state/settings";
import { loadKeeper } from "@/src/state/meta";
import { C } from "@/src/ui/theme";

// Web mock mode: the Viro WASM renderer assets are served from public/viro (see scripts/copy-viro-web.mjs).
if (typeof window !== "undefined") {
  (globalThis as Record<string, unknown>).VIRO_WEB_ASSET_BASE = "/viro/";
}

export default function RootLayout() {
  useEffect(() => {
    loadPersisted();
    loadKeeper(); // before any route: deep links into /play or /realms need the Keeper too
    initAudio();
  }, []);

  return (
    <>
      <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: C.bg }, animation: "fade" }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="play" options={{ gestureEnabled: false }} />
        <Stack.Screen name="sanctuary-view" options={{ gestureEnabled: false }} />
        <Stack.Screen name="settings" />
      </Stack>
      <StatusBar style="light" />
    </>
  );
}
