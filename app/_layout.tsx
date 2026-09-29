import { useEffect, useState } from "react";
import { Platform } from "react-native";
import { Stack } from "expo-router";
import { useFonts } from "expo-font";
import { StatusBar } from "expo-status-bar";
import "react-native-reanimated";
import { Cinzel_700Bold, Cinzel_900Black } from "@expo-google-fonts/cinzel";
import { Poppins_500Medium, Poppins_600SemiBold, Poppins_700Bold, Poppins_800ExtraBold } from "@expo-google-fonts/poppins";
import { initAudio } from "@/src/audio/AudioManager";
import { loadPersisted } from "@/src/state/settings";
import { loadKeeper } from "@/src/state/meta";
import { C } from "@/src/ui/theme";
import { bootMaterials } from "@/src/render/materialsBoot";

// Web mock mode: the Viro WASM renderer assets are served from public/viro (see scripts/copy-viro-web.mjs).
if (typeof window !== "undefined") {
  (globalThis as Record<string, unknown>).VIRO_WEB_ASSET_BASE = "/viro/";
}

export default function RootLayout() {
  // Luminous-fantasy type: Cinzel (titles) + Poppins (UI) — SIL Open Font License, via @expo-google-fonts
  useFonts({
    LilitaOne: require("../assets/fonts/LilitaOne-Regular.ttf"),
    CinzelBold: Cinzel_700Bold,
    CinzelBlack: Cinzel_900Black,
    PoppinsMedium: Poppins_500Medium,
    PoppinsSemiBold: Poppins_600SemiBold,
    PoppinsBold: Poppins_700Bold,
    PoppinsExtraBold: Poppins_800ExtraBold,
  });
  // Skia draws the UI; on web its CanvasKit engine must load before any Skia view mounts.
  const [skiaReady, setSkiaReady] = useState(Platform.OS !== "web");
  useEffect(() => {
    if (Platform.OS !== "web") return;
    import("@shopify/react-native-skia/lib/module/web")
      .then(({ LoadSkiaWeb }) => LoadSkiaWeb({ locateFile: () => "/canvaskit.wasm" }))
      .then(() => setSkiaReady(true))
      .catch(() => setSkiaReady(true)); // never block the app on the preview renderer
  }, []);
  useEffect(() => {
    loadPersisted();
    loadKeeper(); // before any route: deep links into /play or /realms need the Keeper too
    initAudio();
    // register Viro materials on the home screen, before any 3D scene starts (see materialsBoot)
    bootMaterials();
  }, []);

  if (!skiaReady) return null;
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
