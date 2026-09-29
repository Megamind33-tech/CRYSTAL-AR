import { StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { arSession, requestResetPlacement } from "@/src/state/arSession";
import { useStore } from "@/src/state/store";
import { LuxButton } from "@/src/ui/lux/Lux";
import { SettingsList } from "@/src/ui/SettingsList";
import { AccountSettings } from "@/src/ui/AccountSettings";
import { Card, Screen, Section } from "@/src/ui/kit";
import { F, L } from "@/src/ui/lux/tokens";

/** Required attribution for CC-BY assets (and thanks for the CC0 ones). */
const CREDITS = [
  "“Red Dragon” by Tomek Zamojski, “Dragon Rigged” by na3ee1 and “Flamethrower Turret” by Zsky (Poly Pizza), licensed under CC-BY 3.0.",
  "Surface textures from ambientCG and the studio HDRI from Poly Haven (CC0).",
  "Everything else is original to Crystals AR.",
].join("\n");

export default function Settings() {
  const router = useRouter();
  const placed = useStore(arSession, (s) => s.phase === "placed");
  return (
    <Screen title="Settings" subtitle="Sound, view and the Keeper's account">
      <Card>
        <SettingsList />
      </Card>
      <Card>
        <AccountSettings />
      </Card>
      <View style={{ gap: 10, marginTop: 6 }}>
        {placed && (
          <LuxButton
            variant="glass"
            label="RESET AR POSITION"
            onPress={() => {
              requestResetPlacement();
              router.back();
            }}
          />
        )}
        <LuxButton testID="settings-back" label="BACK" hero onPress={() => router.back()} />
      </View>
      <Section title="Credits">
        <Card>
          <Text style={s.credits}>{CREDITS}</Text>
        </Card>
      </Section>
    </Screen>
  );
}

const s = StyleSheet.create({
  credits: { color: L.mist, fontSize: 12, lineHeight: 19, fontFamily: F.body },
});
