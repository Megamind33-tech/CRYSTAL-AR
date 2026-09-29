// UNIVERSE MAP — luminous fantasy (Figma › Luminous v2 › "Universe Map v2" + "Level popup v2").
// The night sky of the Shattered Realms: a constellation thread of light (with motes travelling along
// it) links gold-ringed crystal medallions; the Keeper's sigil stands in a beam over the current island;
// realm plaques mark each gate. Tap a medallion for its glass popup.
import { useEffect, useMemo, useRef, useState } from "react";
import { Dimensions, Modal, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { BlurMask, Canvas, Circle, Group, LinearGradient, Path, Rect, Skia, vec, type SkPath } from "@shopify/react-native-skia";
import Animated, { useAnimatedScrollHandler, useDerivedValue, useSharedValue } from "react-native-reanimated";
import { CAMPAIGN_REALMS } from "@/src/game/campaign";
import { LEVELS, type LevelDef } from "@/src/game/level";
import { ISLANDS, REALMS } from "@/src/meta/config/world";
import { label, levelOf } from "@/src/meta/core";
import { islandStatus, unlockDiscovery } from "@/src/meta/progression";
import { keeperRank } from "@/src/meta/rank";
import type { Island, PlayerState } from "@/src/meta/types";
import { act, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { PressSpring, Wallet } from "@/src/ui/kit";
import { GlassFrame, LuxButton, MedallionShape, NightSky, Plaque, Rise, useLoop } from "@/src/ui/lux/Lux";
import { F, L, REALM_LIGHT, titleGlow } from "@/src/ui/lux/tokens";

const W = Dimensions.get("window").width;
const STEP = 104;
const BANNER = 170;
const CAMPAIGN_REALM_IDS = new Set(CAMPAIGN_REALMS.map((r) => r.id));

const COVER = { ice: "Ice", vine: "Vines", chain: "Chains", ember: "Embers" } as const;
const THREAT: Record<string, string> = { power: "Dormant portal", score: "Restless crystals", collect: "Scattered crystals", stone: "Cracked stone", rune: "Buried runes", relic: "Lost relics" };
function goal(o: LevelDef["objective"]): string {
  switch (o.kind) {
    case "power": return "Wake portal";
    case "score": return o.target.toLocaleString();
    case "collect": return `${o.target} crystals`;
    case "cover": return `${o.target} ${COVER[o.cover]}`;
    case "stone": return `${o.target} stones`;
    case "rune": return `${o.target} runes`;
    case "relic": return `${o.target} relics`;
  }
}
const threat = (l: LevelDef) => (l.objective.kind === "cover" ? COVER[l.objective.cover] : THREAT[l.objective.kind]) ?? "Unknown";

type Node = { island: Island; x: number; y: number };
type Seg = { realm: (typeof REALMS)[number]; top: number; height: number; visible: boolean; gateOpen: boolean; nodes: Node[] };

const xAt = (i: number) => W / 2 + Math.sin(i * 0.92) * (W * 0.26) + Math.sin(i * 2.1) * 10;

export default function UniverseMap() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const p = useStore(metaStore, (m) => m.player);
  const [picked, setPicked] = useState<Island | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const scroll = useRef<Animated.ScrollView>(null);
  const scrollY = useSharedValue(0);
  const onScroll = useAnimatedScrollHandler((e) => {
    scrollY.value = e.contentOffset.y;
  });
  const now = Date.now();

  const { segs, total, all } = useMemo(() => {
    if (!p) return { segs: [] as Seg[], total: 0, all: [] as Node[] };
    const realms = REALMS.filter((r) => CAMPAIGN_REALM_IDS.has(r.id));
    const pre = realms.map((realm) => {
      const islands = realm.islands.map((id) => ISLANDS.find((i) => i.id === id)!).filter((i) => i.portal === "story" && CAMPAIGN_REALM_IDS.has(i.realm));
      const visible = levelOf(p) >= realm.minKeeperLevel - 2 || realm.order === 1;
      const gateOpen = levelOf(p) >= realm.minKeeperLevel && p.heartShards.length >= realm.requiresShards;
      return { realm, islands, visible, gateOpen, height: BANNER + (visible ? islands.length * STEP : 40) };
    });
    const total = pre.reduce((a, s) => a + s.height, 0) + 200;
    let bottom = total - 130;
    let idx = 0;
    const segs: Seg[] = [];
    const all: Node[] = [];
    for (const s of pre) {
      const top = bottom - s.height;
      const nodes: Node[] = [];
      if (s.visible) s.islands.forEach((island, k) => { const n = { island, x: xAt(idx + k), y: bottom - 50 - k * STEP }; nodes.push(n); all.push(n); });
      idx += s.islands.length;
      segs.push({ realm: s.realm, top, height: s.height, visible: s.visible, gateOpen: s.gateOpen, nodes });
      bottom = top;
    }
    return { segs, total, all };
  }, [p?.profile.keeperId, p ? levelOf(p) : 0, p?.heartShards.length]); // eslint-disable-line react-hooks/exhaustive-deps

  const current = p ? all.find((n) => islandStatus(p, n.island, now).status === "available") : undefined;
  useEffect(() => {
    if (!current) return;
    const t = setTimeout(() => scroll.current?.scrollTo({ y: Math.max(0, current.y - Dimensions.get("window").height * 0.55), animated: false }), 60);
    return () => clearTimeout(t);
  }, [current?.island.id]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!p) return null;
  const rank = keeperRank(p);
  const enter = (id: string) => {
    setPicked(null);
    router.push({ pathname: "/play", params: { island: id } });
  };
  const restored = ISLANDS.filter((i) => p.islands[i.id]).length;

  return (
    <View style={s.root}>
      <NightSky />
      <MapCanvas nodes={all} player={p} now={now} currentId={current?.island.id} scrollY={scrollY} />
      <Animated.ScrollView ref={scroll} onScroll={onScroll} scrollEventThrottle={16} contentContainerStyle={{ height: total }} showsVerticalScrollIndicator={false}>
        {segs.map((seg) => (
          <View key={seg.realm.id} pointerEvents="none" style={[s.plaqueWrap, { top: seg.top + 50 }]}>
            <Plaque
              title={seg.visible ? seg.realm.name.replace(/^The /, "").toUpperCase() : "· · ·"}
              sub={!seg.visible ? "A faint signal beyond the clouds" : !seg.gateOpen ? `Sealed · Keeper ${seg.realm.minKeeperLevel} · ${seg.realm.requiresShards} Heart Shard${seg.realm.requiresShards === 1 ? "" : "s"}` : undefined}
              color={seg.gateOpen ? (REALM_LIGHT[seg.realm.id]?.[0] ?? L.goldPale) : L.mist}
              width={Math.min(320, W - 40)}
            />
          </View>
        ))}
        {all.map((n) => (
          <MapNode key={n.island.id} node={n} player={p} now={now} current={current?.island.id === n.island.id} onPress={() => setPicked(n.island)} />
        ))}
        <SpecialPortals player={p} now={now} onEnter={enter} onUnlock={(id) => setErr(act((st, t) => unlockDiscovery(st, id, t)))} />
      </Animated.ScrollView>

      {/* top bar */}
      <View style={[s.topBar, { paddingTop: insets.top + 8 }]} pointerEvents="box-none">
        <PressSpring accessibilityLabel="Back" onPress={() => router.back()} style={s.back}>
          <Text style={s.backTxt}>‹</Text>
        </PressSpring>
        <PressSpring onPress={() => router.push("/profile")} style={s.rankChip}>
          <View style={s.crest} />
          <Text style={s.rankTxt} numberOfLines={1}>{rank.name}</Text>
        </PressSpring>
        <View style={{ flex: 1 }} />
        <Wallet />
      </View>
      <Text style={[s.progress, { top: insets.top + 56 }]} pointerEvents="none">{Math.round((restored / ISLANDS.length) * 100)}% of the Shattered Realms restored</Text>
      {err ? <Text style={[s.err, { top: insets.top + 80 }]}>{err}</Text> : null}

      {/* bottom dock */}
      <View style={[s.dock, { paddingBottom: insets.bottom + 14 }]} pointerEvents="box-none">
        <DockOrb glyph="⌂" label="Sanctuary" color="#8cf5a0" onPress={() => router.push("/sanctuary")} />
        <LuxButton hero testID="map-play" label={current ? `PLAY ${LEVELS[current.island.levelIndex].id}` : "REPLAY"} onPress={() => (current ? setPicked(current.island) : all[0] && setPicked(all[0].island))} />
        <DockOrb glyph="✓" label="Duties" color={L.goldPale} onPress={() => router.push("/duties")} />
      </View>

      {picked && <LevelPopup island={picked} player={p} now={now} onClose={() => setPicked(null)} onPlay={enter} />}
    </View>
  );
}

/**
 * ONE screen-sized canvas draws the whole map – constellation thread, travelling motes, the beam over
 * the current island and every medallion – translated by the scroll position. (Browsers cap live GPU
 * contexts at ~16 and many canvases are costly on phones, so nodes are not separate canvases.)
 */
function MapCanvas({ nodes, player, now, currentId, scrollY }: { nodes: Node[]; player: PlayerState; now: number; currentId?: string; scrollY: { value: number } }) {
  const H = Dimensions.get("window").height;
  const path = useMemo<SkPath | null>(() => {
    if (nodes.length < 2) return null;
    const p = Skia.Path.Make();
    p.moveTo(nodes[0].x, nodes[0].y + 120);
    p.lineTo(nodes[0].x, nodes[0].y);
    for (let i = 0; i < nodes.length - 1; i++) {
      const p0 = nodes[Math.max(0, i - 1)], p1 = nodes[i], p2 = nodes[i + 1], p3 = nodes[Math.min(nodes.length - 1, i + 2)];
      p.cubicTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y);
    }
    return p;
  }, [nodes]);
  const flow = useLoop(9000);
  const pulse = useLoop(2600);
  const beamT = useLoop(3000);
  const shift = useDerivedValue(() => [{ translateY: -scrollY.value }]);
  const motes = useDerivedValue(() => {
    if (!path) return Skia.Path.Make();
    const m = path.copy();
    m.dash(2, 26, -flow.value * 200);
    return m;
  }, [path]);
  const beamOp = useDerivedValue(() => 0.6 + Math.sin(beamT.value * Math.PI * 2) * 0.25);
  const current = nodes.find((n) => n.island.id === currentId);
  return (
    <Canvas style={{ position: "absolute", left: 0, top: 0, width: W, height: H }} pointerEvents="none">
      <Group transform={shift}>
        {path && (
          <>
            <Path path={path} style="stroke" strokeWidth={12} color={L.crystal} opacity={0.14}>
              <BlurMask blur={8} style="normal" />
            </Path>
            <Path path={path} style="stroke" strokeWidth={2.4} color={L.crystalSoft} opacity={0.9}>
              <BlurMask blur={2} style="solid" />
            </Path>
            <Path path={motes} style="stroke" strokeWidth={3.5} strokeCap="round" color="#ffffff">
              <BlurMask blur={1.5} style="solid" />
            </Path>
          </>
        )}
        {current && (
          <Group opacity={beamOp}>
            <Rect x={current.x - 30} y={current.y - 300} width={60} height={300}>
              <LinearGradient start={vec(0, current.y - 300)} end={vec(0, current.y)} colors={["rgba(255,231,168,0)", "rgba(255,231,168,0.4)"]} />
              <BlurMask blur={14} style="normal" />
            </Rect>
          </Group>
        )}
        {nodes.map((n) => {
          const st = islandStatus(player, n.island, now).status;
          const isCur = n.island.id === currentId;
          const finale = !!n.island.firstRestore.heartShards?.length;
          const size = isCur ? 72 : finale ? 66 : 54;
          const colors = isCur ? ([L.crystalSoft, "#1f5ac0"] as [string, string]) : (REALM_LIGHT[n.island.realm] ?? REALM_LIGHT.verdant);
          return <MedallionShape key={n.island.id} cx={n.x} cy={n.y} size={size} colors={colors} state={isCur ? "current" : st === "locked" ? "locked" : "done"} pulse={pulse} />;
        })}
      </Group>
    </Canvas>
  );
}

function MapNode({ node, player, now, current, onPress }: { node: Node; player: PlayerState; now: number; current: boolean; onPress: () => void }) {
  const { island, x, y } = node;
  const st = islandStatus(player, island, now).status;
  const level = LEVELS[island.levelIndex];
  const finale = !!island.firstRestore.heartShards?.length;
  const size = current ? 72 : finale ? 66 : 54;
  const stars = player.islands[island.id]?.stars ?? 0;
  const secret = (player.secrets ?? []).includes(island.id);
  return (
    <Pressable
      testID={`island-${island.id}`}
      accessibilityRole="button"
      accessibilityLabel={`Level ${level.id} ${island.name}${st === "locked" ? ", locked" : ""}`}
      onPress={onPress}
      style={{ position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size }}
    >
      <View style={StyleSheet.absoluteFill} pointerEvents="none">
        <Text style={[s.num, { fontSize: current ? 26 : 19, lineHeight: size, color: st === "locked" ? L.mist : "#ffffff" }]}>{level.id}</Text>
      </View>
      {st === "restored" && (
        <View style={s.stars} pointerEvents="none">
          {[0, 1, 2].map((k) => (
            <Text key={k} style={[s.star, { fontSize: k === 1 ? 17 : 13, marginTop: k === 1 ? -4 : 0, color: k < stars ? "#ffd05a" : "rgba(255,255,255,0.22)" }, k < stars && titleGlow("#ffcf6a", 6)]}>★</Text>
          ))}
        </View>
      )}
      {finale && <Text style={[s.finale, titleGlow("#b07aff", 10)]} pointerEvents="none">◆</Text>}
      {secret && <Text style={[s.secret, titleGlow("#ffe070", 10)]} pointerEvents="none">✦</Text>}
      {current && (
        <View style={s.sigilWrap} pointerEvents="none">
          <Text style={s.here}>YOU ARE HERE</Text>
          <View style={s.sigil}>
            <Text style={s.sigilTxt}>{(player.profile.keeperName || "K")[0].toUpperCase()}</Text>
          </View>
        </View>
      )}
    </Pressable>
  );
}

function DockOrb({ glyph, label: text, color, onPress }: { glyph: string; label: string; color: string; onPress: () => void }) {
  return (
    <PressSpring accessibilityLabel={text} onPress={onPress} style={s.dockOrbWrap}>
      <View style={[s.dockOrb, { shadowColor: color }]}>
        <View style={[s.dockOrbCore, { backgroundColor: color }]} />
        <Text style={[s.dockGlyph, { color }, titleGlow(color, 8)]}>{glyph}</Text>
      </View>
      <Text style={s.dockLabel}>{text.toUpperCase()}</Text>
    </PressSpring>
  );
}

function SpecialPortals({ player, now, onEnter, onUnlock }: { player: PlayerState; now: number; onEnter: (id: string) => void; onUnlock: (id: string) => void }) {
  const router = useRouter();
  const specials = ISLANDS.filter((i) => i.portal !== "story" || !CAMPAIGN_REALM_IDS.has(i.realm)).filter((i) => islandStatus(player, i, now).status !== "locked");
  if (!specials.length) return null;
  return (
    <View style={s.specials}>
      {specials.map((island) => {
        const st = islandStatus(player, island, now).status;
        const action = st === "available" || st === "restored" ? () => onEnter(island.id) : island.portal === "discovery" ? () => onUnlock(island.id) : () => router.push("/exchange");
        const cost = island.unlockCost && st === "needsUnlock" ? ` · ${Object.entries(island.unlockCost).map(([k, v]) => `${v} ${label(k)}`).join(", ")}` : "";
        return (
          <PressSpring key={island.id} onPress={action} style={s.special}>
            <Text style={[s.specialGlyph, titleGlow(L.rose, 8)]}>✦</Text>
            <Text style={s.specialTxt} numberOfLines={1}>{island.name}{cost}</Text>
          </PressSpring>
        );
      })}
    </View>
  );
}

/** A small live vista of the island's realm for the popup header. */
function Vista({ realm }: { realm: string }) {
  const [bright, deep] = REALM_LIGHT[realm] ?? REALM_LIGHT.verdant;
  const w = 280, h = 120;
  const t = useLoop(5000);
  const bob = useDerivedValue(() => [{ translateY: Math.sin(t.value * Math.PI * 2) * 4 }]);
  const island = useMemo(() => {
    const p = Skia.Path.Make();
    p.moveTo(w / 2 - 80, 70);
    p.cubicTo(w / 2 - 55, 95, w / 2 - 25, 112, w / 2, 118);
    p.cubicTo(w / 2 + 25, 110, w / 2 + 55, 95, w / 2 + 80, 70);
    p.close();
    return p;
  }, []);
  return (
    <Canvas style={{ width: w, height: h, borderRadius: 16 }}>
      <Rect x={0} y={0} width={w} height={h}>
        <LinearGradient start={vec(0, 0)} end={vec(0, h)} colors={[L.night900, L.night700, deep]} />
      </Rect>
      <Circle cx={w / 2} cy={46} r={70} color={bright} opacity={0.25}>
        <BlurMask blur={30} style="normal" />
      </Circle>
      <Group transform={bob}>
        <Path path={island}>
          <LinearGradient start={vec(0, 70)} end={vec(0, 118)} colors={["#3a3a72", "rgba(11,14,36,0.3)"]} />
        </Path>
        <Path path={(() => { const p = Skia.Path.Make(); p.addOval(Skia.XYWHRect(w / 2 - 82, 58, 164, 26)); return p; })()}>
          <LinearGradient start={vec(0, 58)} end={vec(0, 84)} colors={[bright, deep]} />
        </Path>
        <Circle cx={w / 2} cy={40} r={20} style="stroke" strokeWidth={5} color="#dcd0b8" />
        <Circle cx={w / 2} cy={40} r={13} color={L.crystal}>
          <BlurMask blur={8} style="solid" />
        </Circle>
      </Group>
      {Array.from({ length: 16 }, (_, i) => (
        <Circle key={i} cx={(i * 67) % w} cy={(i * 29) % 60} r={0.8 + (i % 3) * 0.4} color="#ffffff" opacity={0.6} />
      ))}
    </Canvas>
  );
}

function LevelPopup({ island, player, now, onClose, onPlay }: { island: Island; player: PlayerState; now: number; onClose: () => void; onPlay: (id: string) => void }) {
  const st = islandStatus(player, island, now);
  const level = LEVELS[island.levelIndex];
  const record = player.islands[island.id];
  const stars = record?.stars ?? 0;
  const secret = (player.secrets ?? []).includes(island.id);
  const playable = st.status === "available" || st.status === "restored";
  return (
    <Modal transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={s.dim} onPress={onClose}>
        <Rise>
          <Pressable onPress={() => {}}>
            <GlassFrame style={s.card}>
              <View style={s.vista}>
                <Vista realm={island.realm} />
                <View style={s.popStars}>
                  {[0, 1, 2].map((k) => (
                    <Text key={k} style={[{ fontSize: k === 1 ? 34 : 26, marginTop: k === 1 ? -8 : 0, color: k < stars ? "#ffd05a" : "rgba(255,255,255,0.2)" }, k < stars && titleGlow("#ffcf6a", 12)]}>★</Text>
                  ))}
                </View>
              </View>
              <Text style={s.popLevel}>{level.label ?? `LEVEL ${level.id}`}</Text>
              <Text style={s.popName}>{island.name}</Text>
              {level.story ? <Text style={s.popStory}>{level.story}</Text> : null}
              <View style={s.intel}>
                <Intel k="GOAL" v={goal(level.objective)} c={L.crystal} />
                <Intel k="MOVES" v={String(level.moves)} c={L.goldPale} />
                <Intel k="DANGERS" v={record ? threat(level) : "Unknown"} c={L.rose} />
              </View>
              <Text style={s.popSecret}>{secret ? "✦  Secret uncovered" : "✦  Something may be buried here…"}</Text>
              {playable ? (
                <LuxButton hero label={st.status === "restored" ? "PLAY AGAIN" : "PLAY"} onPress={() => onPlay(island.id)} testID={`enter-${island.id}`} />
              ) : (
                <Text style={s.popLocked}>🔒  {st.reason}</Text>
              )}
            </GlassFrame>
            <PressSpring onPress={onClose} accessibilityLabel="Close" style={s.close}>
              <Text style={s.closeTxt}>✕</Text>
            </PressSpring>
          </Pressable>
        </Rise>
      </Pressable>
    </Modal>
  );
}

function Intel({ k, v, c }: { k: string; v: string; c: string }) {
  return (
    <View style={[s.intelCell, { borderColor: c + "88" }]}>
      <Text style={s.intelVal} numberOfLines={1}>{v}</Text>
      <Text style={[s.intelKey, { color: c }]}>{k}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: L.night900 },
  plaqueWrap: { position: "absolute", left: 0, right: 0, alignItems: "center" },
  topBar: { position: "absolute", left: 0, right: 0, top: 0, flexDirection: "row", alignItems: "center", gap: 8, paddingHorizontal: 10 },
  back: { width: 38, height: 38, borderRadius: 19, backgroundColor: "rgba(20,26,61,0.9)", borderWidth: 1.5, borderColor: "rgba(246,211,138,0.75)", alignItems: "center", justifyContent: "center" },
  backTxt: { color: L.goldPale, fontSize: 24, marginTop: -3, fontFamily: F.bold },
  rankChip: { flexDirection: "row", alignItems: "center", gap: 6, paddingLeft: 6, paddingRight: 12, height: 34, borderRadius: 17, backgroundColor: "rgba(11,14,36,0.85)", borderWidth: 1, borderColor: "rgba(246,211,138,0.7)" },
  crest: { width: 18, height: 18, backgroundColor: L.crystal, transform: [{ rotate: "45deg" }], borderRadius: 3, shadowColor: L.crystal, shadowOpacity: 1, shadowRadius: 6, elevation: 5 },
  rankTxt: { color: L.goldPale, fontFamily: F.title, fontSize: 13, maxWidth: 110 },
  progress: { position: "absolute", alignSelf: "center", color: L.mist, fontSize: 11, fontFamily: F.body, letterSpacing: 0.5 },
  err: { position: "absolute", alignSelf: "center", color: "#fff", backgroundColor: "rgba(200,40,60,0.9)", paddingHorizontal: 12, paddingVertical: 6, borderRadius: 12, overflow: "hidden", fontFamily: F.bodyStrong },
  dock: { position: "absolute", left: 0, right: 0, bottom: 0, flexDirection: "row", justifyContent: "space-between", alignItems: "flex-end", paddingHorizontal: 12, paddingTop: 30, backgroundColor: "rgba(7,9,32,0.72)" },
  dockOrbWrap: { alignItems: "center", width: 74 },
  dockOrb: { width: 50, height: 50, borderRadius: 25, backgroundColor: "rgba(11,14,36,0.95)", borderWidth: 1.5, borderColor: L.goldPale, alignItems: "center", justifyContent: "center", overflow: "hidden", shadowOpacity: 0.9, shadowRadius: 10, elevation: 8 },
  dockOrbCore: { position: "absolute", width: 50, height: 50, borderRadius: 25, opacity: 0.2 },
  dockGlyph: { fontSize: 21, fontFamily: F.bold },
  dockLabel: { color: "#e8e2f4", fontSize: 8.5, letterSpacing: 1, marginTop: 4, fontFamily: F.bodyStrong },
  num: { textAlign: "center", fontFamily: F.display, ...titleGlow("#000000", 4) },
  stars: { position: "absolute", top: -18, left: -12, right: -12, flexDirection: "row", justifyContent: "center", gap: 1 },
  star: { fontFamily: F.bold },
  finale: { position: "absolute", top: -28, alignSelf: "center", fontSize: 20, color: "#d8b0ff" },
  secret: { position: "absolute", right: -8, bottom: -6, fontSize: 18, color: "#fff6c8" },
  sigilWrap: { position: "absolute", top: -96, alignSelf: "center", alignItems: "center", width: 120, left: "50%", marginLeft: -60 },
  here: { color: L.goldPale, fontFamily: F.title, fontSize: 8.5, letterSpacing: 2.5, marginBottom: 4, ...titleGlow("#ffcf6a", 6) },
  sigil: { width: 46, height: 46, borderRadius: 23, backgroundColor: "#2a2070", borderWidth: 2.5, borderColor: L.gold, alignItems: "center", justifyContent: "center", shadowColor: "#ffcf6a", shadowOpacity: 0.9, shadowRadius: 12, elevation: 9 },
  sigilTxt: { color: L.goldPale, fontFamily: F.display, fontSize: 20 },
  specials: { position: "absolute", right: 10, top: 130, gap: 8, alignItems: "flex-end" },
  special: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 12, height: 34, borderRadius: 17, backgroundColor: "rgba(58,26,90,0.9)", borderWidth: 1, borderColor: L.rose },
  specialGlyph: { color: L.rose, fontSize: 14 },
  specialTxt: { color: "#ffe8f8", fontFamily: F.bodyStrong, fontSize: 12, maxWidth: 200 },
  dim: { flex: 1, backgroundColor: "rgba(5,6,26,0.72)", alignItems: "center", justifyContent: "center", padding: 24 },
  card: { width: Math.min(340, W - 40), paddingHorizontal: 20, paddingTop: 20, paddingBottom: 22, alignItems: "center", gap: 10 },
  vista: { borderRadius: 16, overflow: "hidden", borderWidth: 1, borderColor: "rgba(246,211,138,0.5)" },
  popStars: { position: "absolute", bottom: 4, left: 0, right: 0, flexDirection: "row", justifyContent: "center", alignItems: "flex-end", gap: 4 },
  popLevel: { color: L.goldPale, fontFamily: F.title, fontSize: 12, letterSpacing: 4, marginTop: 4 },
  popName: { color: L.ivory, fontFamily: F.display, fontSize: 28, letterSpacing: 1.5, textAlign: "center", ...titleGlow("#ffcf6a", 12) },
  popStory: { color: L.mist, fontFamily: F.body, fontSize: 13, lineHeight: 19, textAlign: "center" },
  intel: { flexDirection: "row", gap: 8, marginTop: 4, alignSelf: "stretch" },
  intelCell: { flex: 1, borderRadius: 12, borderWidth: 1, backgroundColor: "rgba(7,9,32,0.75)", paddingVertical: 8, paddingHorizontal: 4, alignItems: "center" },
  intelVal: { color: "#ffffff", fontFamily: F.number, fontSize: 14 },
  intelKey: { fontFamily: F.bodyStrong, fontSize: 9, letterSpacing: 1.2, marginTop: 1 },
  popSecret: { color: L.goldPale, fontFamily: F.bodyStrong, fontSize: 12, marginVertical: 2 },
  popLocked: { color: L.mist, fontFamily: F.bodyStrong, fontSize: 13, marginTop: 6 },
  close: { position: "absolute", right: -10, top: -12, width: 40, height: 40, borderRadius: 20, backgroundColor: "rgba(26,20,72,0.98)", borderWidth: 1.5, borderColor: L.goldPale, alignItems: "center", justifyContent: "center", elevation: 10 },
  closeTxt: { color: L.goldPale, fontSize: 15, fontFamily: F.bold },
});
