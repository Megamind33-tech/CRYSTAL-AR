import { ScrollView, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { arSession, requestResetPlacement } from "@/src/state/arSession";
import { useStore } from "@/src/state/store";
import { Button } from "@/src/ui/Button";
import { SettingsList } from "@/src/ui/SettingsList";
import { C, font } from "@/src/ui/theme";

export default function Settings() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const placed = useStore(arSession, (s) => s.phase === "placed");
  return (
    <ScrollView style={{ backgroundColor: C.bg }} contentContainerStyle={[s.root, { paddingTop: insets.top + 24, paddingBottom: insets.bottom + 24 }]}>
      <Text style={s.title}>Settings</Text>
      <SettingsList />
      <View style={{ gap: 10, marginTop: 24 }}>
        {placed && (
          <Button
            label="RESET AR POSITION"
            onPress={() => {
              requestResetPlacement();
              router.back();
            }}
          />
        )}
        <Button testID="settings-back" label="BACK" variant="primary" onPress={() => router.back()} />
      </View>
    </ScrollView>
  );
}

const s = StyleSheet.create({
  root: { paddingHorizontal: 22 },
  title: { color: C.ink, fontSize: 32, fontFamily: font.display, fontWeight: "700", marginBottom: 12 },
});
