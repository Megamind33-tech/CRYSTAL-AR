import { useEffect } from "react";
import { StyleSheet, Text, View } from "react-native";
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
import { GlassOrb } from "@/src/ui/lux/Orb";
import { F, L, titleGlow } from "@/src/ui/lux/tokens";

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
    <View style={{ flex: 1, backgroundColor: L.night900 }}>
      <WorldNavigator />
      <ViewControls />
      <View pointerEvents="box-none" style={[StyleSheet.absoluteFill, { paddingTop: insets.top + 8, paddingHorizontal: 12 }]}>
        <View style={{ flexDirection: "row", gap: 8 }}>
          <GlassOrb glyph="‹" size={46} tone={L.goldLight} accessibilityLabel="Back" onPress={() => (router.canGoBack() ? router.back() : router.replace("/sanctuary"))} breathe={false} />
          {phase === "placed" && p && rating && (
            <View style={s.plate}>
              <View style={s.sheen} pointerEvents="none" />
              <Text style={s.title} numberOfLines={1}>{p.profile.keeperName}&apos;s Sanctuary</Text>
              <Text style={s.label}>RATING {rating.rating} · {p.heartShards.length} HEART SHARD{p.heartShards.length === 1 ? "" : "S"} · {p.sanctuary.housed.length} LUMINS</Text>
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
  plate: {
    flex: 1, paddingHorizontal: 16, paddingVertical: 8, justifyContent: "center", borderRadius: 18, overflow: "hidden",
    backgroundColor: "rgba(20,26,61,0.9)", borderWidth: 1.2, borderColor: "rgba(246,211,138,0.7)",
  },
  sheen: { position: "absolute", left: 0, right: 0, top: 0, height: "45%", backgroundColor: "rgba(255,255,255,0.07)" },
  title: { color: L.goldLight, fontFamily: F.title, fontSize: 16, letterSpacing: 0.8, ...titleGlow("#ffcf6a", 8) },
  label: { color: L.crystal, fontFamily: F.title, fontSize: 9, letterSpacing: 1.4, marginTop: 2 },
});
