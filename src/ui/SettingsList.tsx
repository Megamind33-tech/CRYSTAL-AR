import { View } from "react-native";
import { settingsStore, updateSettings, type Settings } from "../state/settings";
import { useStore } from "../state/store";
import { OptionRow, Toggle } from "./kit";

const ROWS: { key: keyof Settings; label: string; hint: string }[] = [
  { key: "music", label: "Music", hint: "Forest ambience while playing" },
  { key: "sfx", label: "Sound effects", hint: "Crystal chimes and world sounds" },
  { key: "haptics", label: "Haptics", hint: "Vibration on swaps and matches" },
  { key: "cameraView", label: "Tabletop View", hint: "Play on a virtual table without AR tracking. Use this if AR crashes or can’t find surfaces." },
  { key: "diagnostics", label: "Diagnostics", hint: "Developer overlay (FPS, tracking, board)" },
];

/** Game settings as luminous rows with gold crystal toggles. */
export function SettingsList() {
  const s = useStore(settingsStore, (x) => x);
  return (
    <View style={{ gap: 2 }}>
      {ROWS.filter((r) => __DEV__ || r.key !== "diagnostics").map((r) => (
        <OptionRow key={r.key} label={r.label} hint={r.hint}>
          <Toggle accessibilityLabel={r.label} value={!!s[r.key]} onChange={(v) => updateSettings({ [r.key]: v })} />
        </OptionRow>
      ))}
    </View>
  );
}
