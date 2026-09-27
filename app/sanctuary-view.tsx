import { useEffect } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useViewMode, ViewControls, WorldNavigator } from "@/src/ar/WorldNavigator";
import { DEV_AR_MOCK } from "@/src/config";
import { sanctuaryRating } from "@/src/meta/progression";
import { arSession } from "@/src/state/arSession";
import { gameEvents } from "@/src/state/game";
import { metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { PlacementGuide } from "@/src/ui/Overlays";
import { RisingOverlay } from "@/src/ui/RisingOverlay";
import { C, font, ui } from "@/src/ui/theme";

/** The Keeper's Sanctuary placed on a real table – same placement flow as the puzzle islands. */
export default function SanctuaryView() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const params = useLocalSearchParams<{ autoplace?: string }>();
  const phase = useStore(arSession, (s) => s.phase);
  const viewMode = useViewMode();
  const p = useStore(metaStore, (m) => m.player);

  useEffect(() => {
    arSession.set({ world: "sanctuary", phase: DEV_AR_MOCK ? "surfaceFound" : "scanning", anchorId: null, yaw: 0 });
    if (DEV_AR_MOCK && params.autoplace) setTimeout(() => arSession.set({ phase: "placed", anchorId: "mock-table" }), 300);
    return () => arSession.set({ world: "game", phase: "scanning", anchorId: null });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const rating = p ? sanctuaryRating(p) : null;
  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <WorldNavigator />
      <ViewControls />
      <View pointerEvents="box-none" style={[StyleSheet.absoluteFill, { paddingTop: insets.top + 8, paddingHorizontal: 12 }]}>
        <View style={{ flexDirection: "row", gap: 8 }}>
          <Pressable accessibilityRole="button" accessibilityLabel="Back" onPress={() => (router.canGoBack() ? router.back() : router.replace("/sanctuary"))} style={[ui.glass, s.back]}>
            <Text style={{ color: C.ink, fontSize: 26, marginTop: -3 }}>‹</Text>
          </Pressable>
          {phase === "placed" && p && rating && (
            <View style={[ui.glass, { flex: 1, paddingHorizontal: 14, justifyContent: "center" }]}>
              <Text style={s.title}>{p.profile.keeperName}'s Sanctuary</Text>
              <Text style={ui.label}>Rating {rating.rating} · {p.heartShards.length} Heart Shard{p.heartShards.length === 1 ? "" : "s"} · {p.sanctuary.housed.length} Lumins</Text>
            </View>
          )}
        </View>
      </View>
      <RisingOverlay label="Your Sanctuary is gathering…" />
      <PlacementGuide mock={viewMode !== "ar"} cameraView={viewMode === "camera"} onPlaceMock={() => { arSession.set({ phase: "placed", anchorId: "mock-table" }); gameEvents.emit({ type: "sfx", name: "place" }); }} />
    </View>
  );
}

const s = StyleSheet.create({
  back: { width: 52, height: 52, alignItems: "center", justifyContent: "center" },
  title: { color: C.ink, fontFamily: font.display, fontSize: 17, fontWeight: "700" },
});
