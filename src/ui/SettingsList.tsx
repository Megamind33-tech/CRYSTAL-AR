import { StyleSheet, Switch, Text, View } from "react-native";
import { settingsStore, updateSettings, type Settings } from "../state/settings";
import { useStore } from "../state/store";
import { C, font } from "./theme";

const ROWS: { key: keyof Settings; label: string; hint: string }[] = [
  { key: "music", label: "Music", hint: "Forest ambience while playing" },
  { key: "sfx", label: "Sound effects", hint: "Crystal chimes and world sounds" },
  { key: "haptics", label: "Haptics", hint: "Vibration on swaps and matches" },
  { key: "cameraView", label: "Camera View", hint: "Show the world over your camera without AR tracking. Use this if AR crashes or can’t find surfaces." },
  { key: "diagnostics", label: "Diagnostics", hint: "Developer overlay (FPS, tracking, board)" },
];

export function SettingsList() {
  const s = useStore(settingsStore, (x) => x);
  return (
    <View style={{ gap: 4 }}>
      {ROWS.map((r) => (
        <View key={r.key} style={st.row}>
          <View style={{ flex: 1 }}>
            <Text style={st.label}>{r.label}</Text>
            <Text style={st.hint}>{r.hint}</Text>
          </View>
          <Switch
            accessibilityLabel={r.label}
            value={!!s[r.key]}
            onValueChange={(v) => updateSettings({ [r.key]: v })}
            trackColor={{ true: C.goldDeep, false: "rgba(255,255,255,0.18)" }}
            thumbColor={s[r.key] ? C.gold : "#ddd"}
          />
        </View>
      ))}
    </View>
  );
}

const st = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", paddingVertical: 12, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: C.line },
  label: { color: C.ink, fontSize: 16, fontWeight: "600", fontFamily: font.body },
  hint: { color: C.inkFaint, fontSize: 12, marginTop: 2, fontFamily: font.body },
});
