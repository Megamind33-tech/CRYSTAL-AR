import { useState } from "react";
import { StyleSheet, Switch, Text, TextInput, View } from "react-native";
import { NOTIFICATIONS } from "../meta/config/live";
import type { NotificationClass } from "../meta/types";
import { metaStore, setPlayer } from "../state/meta";
import { useStore } from "../state/store";
import { C, font } from "./theme";

/** Per-class notification switches (all independently disableable) and the account country. */
export function AccountSettings() {
  const p = useStore(metaStore, (m) => m.player);
  const [country, setCountry] = useState(p?.profile.country ?? "");
  if (!p) return null;
  return (
    <View style={{ gap: 4, marginTop: 18 }}>
      <Text style={st.head}>Notifications</Text>
      {(Object.keys(NOTIFICATIONS) as NotificationClass[]).map((k) => (
        <View key={k} style={st.row}>
          <View style={{ flex: 1 }}>
            <Text style={st.label}>{NOTIFICATIONS[k].title}</Text>
            <Text style={st.hint}>{NOTIFICATIONS[k].body}</Text>
          </View>
          <Switch
            accessibilityLabel={`${NOTIFICATIONS[k].title} notifications`}
            value={p.notifications[k]}
            onValueChange={(v) => setPlayer((s) => ({ ...s, notifications: { ...s.notifications, [k]: v } }))}
            trackColor={{ true: C.goldDeep, false: "rgba(255,255,255,0.18)" }}
            thumbColor={p.notifications[k] ? C.gold : "#ddd"}
          />
        </View>
      ))}
      <Text style={[st.head, { marginTop: 18 }]}>Region</Text>
      <View style={st.row}>
        <View style={{ flex: 1 }}>
          <Text style={st.label}>Country for regional rankings</Text>
          <Text style={st.hint}>Two-letter code, e.g. NG, GB, US. Optional – your location is never read.</Text>
        </View>
        <TextInput
          value={country}
          onChangeText={(v) => {
            const code = v.toUpperCase().replace(/[^A-Z]/g, "").slice(0, 2);
            setCountry(code);
            setPlayer((s) => ({ ...s, profile: { ...s.profile, country: code.length === 2 ? code : undefined } }));
          }}
          autoCapitalize="characters"
          maxLength={2}
          placeholder="—"
          placeholderTextColor={C.inkFaint}
          style={st.input}
        />
      </View>
    </View>
  );
}

const st = StyleSheet.create({
  head: { color: C.inkDim, fontSize: 12, letterSpacing: 1.6, textTransform: "uppercase", fontWeight: "700" },
  row: { flexDirection: "row", alignItems: "center", paddingVertical: 10, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: C.line, gap: 10 },
  label: { color: C.ink, fontSize: 15, fontWeight: "600", fontFamily: font.body },
  hint: { color: C.inkFaint, fontSize: 12, marginTop: 2 },
  input: { color: C.ink, width: 56, textAlign: "center", borderBottomWidth: 1, borderBottomColor: C.gold, fontSize: 18, paddingVertical: 4 },
});
