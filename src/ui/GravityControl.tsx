import { Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { MAX_GRAVITY_CHARGES } from "../game/level";
import { rotatedGravity } from "../game/resolve";
import { gameStore, turnTabletop } from "../state/game";
import { useStore } from "../state/store";
import { C, font } from "./theme";

const ARROW = { left: "←", down: "↓", right: "→" } as const;

/**
 * GRAVITY SHIFT: turn the tabletop. Shows the current fall direction and remaining charges;
 * only present on levels that grant charges (introduced in Emerald Canyon).
 */
export function GravityControl() {
  const insets = useSafeAreaInsets();
  const uses = useStore(gameStore, (s) => (s.session?.level.gravityCharges ?? 0) > 0);
  const gravity = useStore(gameStore, (s) => s.gravity);
  const charges = useStore(gameStore, (s) => s.gravityCharges);
  const busy = useStore(gameStore, (s) => s.busy || !!s.result);
  if (!uses) return null;
  const can = (turn: -1 | 1) => !busy && charges > 0 && !!rotatedGravity(gravity, turn);
  const Btn = ({ turn, label }: { turn: -1 | 1; label: string }) => (
    <Pressable
      testID={turn === -1 ? "turn-left" : "turn-right"}
      accessibilityRole="button"
      accessibilityLabel={turn === -1 ? "Turn tabletop left" : "Turn tabletop right"}
      disabled={!can(turn)}
      onPress={() => turnTabletop(turn)}
      style={({ pressed }) => [s.btn, !can(turn) && { opacity: 0.35 }, pressed && { transform: [{ scale: 0.92 }] }]}
    >
      <Text style={s.btnTxt}>{label}</Text>
    </Pressable>
  );
  return (
    <View pointerEvents="box-none" style={[s.wrap, { bottom: insets.bottom + 16 }]}>
      <Btn turn={-1} label="⟲" />
      <View style={s.center}>
        <Text style={s.arrow}>{ARROW[gravity]}</Text>
        <View style={s.pips}>
          {Array.from({ length: MAX_GRAVITY_CHARGES }, (_, i) => (
            <View key={i} style={[s.pip, i < charges && s.pipOn]} />
          ))}
        </View>
        <Text style={s.label}>GRAVITY</Text>
      </View>
      <Btn turn={1} label="⟳" />
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", left: 14, flexDirection: "row", alignItems: "center", gap: 8, backgroundColor: "rgba(12,15,19,0.55)", borderRadius: 30, padding: 6, borderWidth: StyleSheet.hairlineWidth, borderColor: C.line },
  btn: { width: 50, height: 50, borderRadius: 25, backgroundColor: "rgba(143,233,255,0.12)", borderWidth: 1, borderColor: "rgba(143,233,255,0.45)", alignItems: "center", justifyContent: "center" },
  btnTxt: { color: C.portal, fontSize: 24, fontWeight: "700" },
  center: { alignItems: "center", minWidth: 52 },
  arrow: { color: C.ink, fontSize: 20, fontWeight: "800" },
  pips: { flexDirection: "row", gap: 4, marginTop: 2 },
  pip: { width: 8, height: 8, borderRadius: 4, borderWidth: 1, borderColor: C.portal },
  pipOn: { backgroundColor: C.portal },
  label: { color: C.inkFaint, fontSize: 8.5, letterSpacing: 1.4, marginTop: 2, fontFamily: font.body },
});
