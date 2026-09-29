import { useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import Animated, { FadeInDown, useAnimatedStyle } from "react-native-reanimated";
import { markSeen } from "../meta/core";
import { metaStore, setPlayer } from "../state/meta";
import { useStore } from "../state/store";
import { Field, Pill } from "./kit";
import { useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

/** Onboarding beat: after the first portal opens, the Keeper takes a name. Shown once, inline. */
export function NameKeeper() {
  const due = useStore(metaStore, (m) => !!m.player && Object.keys(m.player.islands).length > 0 && !m.player.seenFeatures.includes("naming"));
  const [name, setName] = useState("");
  const t = useLoop(2600);
  const glow = useAnimatedStyle(() => ({ opacity: 0.25 + Math.sin(t.value * Math.PI * 2) * 0.15 }));
  if (!due) return null;
  const clean = name.trim().replace(/[^\p{L}\p{N} _-]/gu, "").slice(0, 16);
  const save = (keep: boolean) =>
    setPlayer((s) => markSeen({ ...s, profile: { ...s.profile, keeperName: keep && clean.length >= 2 ? clean : s.profile.keeperName } }, "naming"));
  return (
    <Animated.View entering={FadeInDown.springify().damping(14)} style={st.card}>
      <Animated.View pointerEvents="none" style={[st.glow, glow]} />
      <Text style={st.kicker}>A NAME FOR THE KEEPER</Text>
      <Text style={st.title}>The Lumin is watching you.</Text>
      <Text style={st.body}>Keepers are remembered by name. What should the realms call you?</Text>
      <View style={st.row}>
        <Field
          testID="keeper-name"
          value={name}
          onChangeText={setName}
          maxLength={16}
          placeholder="Keeper name"
          style={{ flex: 1, minWidth: 0, width: "100%" }}
          onSubmitEditing={() => save(true)}
        />
        <Pill label="BEGIN" disabled={clean.length < 2} onPress={() => save(true)} />
      </View>
      <Text style={st.skip} onPress={() => save(false)}>Later</Text>
    </Animated.View>
  );
}

const st = StyleSheet.create({
  card: {
    padding: 16, borderRadius: 18, borderWidth: 1.2, borderColor: "rgba(246,211,138,0.7)", backgroundColor: "rgba(30,35,82,0.88)", gap: 6, overflow: "hidden",
  },
  glow: { position: "absolute", left: -40, right: -40, top: -60, height: 120, borderRadius: 80, backgroundColor: L.gold },
  kicker: { color: L.crystal, fontFamily: F.title, fontSize: 9.5, letterSpacing: 2.4 },
  title: { color: L.goldLight, fontFamily: F.title, fontSize: 18, letterSpacing: 0.6, ...titleGlow("#ffcf6a", 10) },
  body: { color: L.mist, fontSize: 13.5, lineHeight: 20, fontFamily: F.body },
  row: { flexDirection: "row", gap: 10, alignItems: "center", marginTop: 4 },
  skip: { color: L.mist, fontSize: 12, alignSelf: "flex-end", fontFamily: F.bodyStrong, paddingTop: 2 },
});
