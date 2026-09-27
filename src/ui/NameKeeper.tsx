import { useState } from "react";
import { StyleSheet, Text, TextInput, View } from "react-native";
import { markSeen } from "../meta/core";
import { metaStore, setPlayer } from "../state/meta";
import { useStore } from "../state/store";
import { Pill } from "./kit";
import { C, font } from "./theme";

/** Onboarding beat: after the first portal opens, the Keeper takes a name. Shown once, inline. */
export function NameKeeper() {
  const due = useStore(metaStore, (m) => !!m.player && Object.keys(m.player.islands).length > 0 && !m.player.seenFeatures.includes("naming"));
  const [name, setName] = useState("");
  if (!due) return null;
  const clean = name.trim().replace(/[^\p{L}\p{N} _-]/gu, "").slice(0, 16);
  const save = (keep: boolean) =>
    setPlayer((s) => markSeen({ ...s, profile: { ...s.profile, keeperName: keep && clean.length >= 2 ? clean : s.profile.keeperName } }, "naming"));
  return (
    <View style={st.card}>
      <Text style={st.title}>The Lumin is watching you.</Text>
      <Text style={st.body}>Keepers are remembered by name. What should the realms call you?</Text>
      <View style={st.row}>
        <TextInput
          testID="keeper-name"
          value={name}
          onChangeText={setName}
          maxLength={16}
          placeholder="Keeper name"
          placeholderTextColor={C.inkFaint}
          style={st.input}
          onSubmitEditing={() => save(true)}
        />
        <Pill label="BEGIN" disabled={clean.length < 2} onPress={() => save(true)} />
      </View>
      <Text style={st.skip} onPress={() => save(false)}>Later</Text>
    </View>
  );
}

const st = StyleSheet.create({
  card: { padding: 14, borderRadius: 14, borderWidth: 1, borderColor: C.gold, backgroundColor: "rgba(242,196,107,0.08)", gap: 6 },
  title: { color: C.ink, fontFamily: font.display, fontSize: 17, fontWeight: "700" },
  body: { color: C.inkDim, fontSize: 13.5 },
  row: { flexDirection: "row", gap: 10, alignItems: "center" },
  input: { flex: 1, color: C.ink, fontSize: 17, borderBottomWidth: 1, borderBottomColor: C.gold, paddingVertical: 4 },
  skip: { color: C.inkFaint, fontSize: 12, alignSelf: "flex-end" },
});
