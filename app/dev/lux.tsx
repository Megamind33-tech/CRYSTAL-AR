// Dev-only showcase of the Lux UI kit (not linked from the UI): open /dev/lux in the web preview.
import { ScrollView, StyleSheet, View } from "react-native";
import { Capsule, Gem, GlassFrame, LuxButton, LuxText, Medallion, Meter, NightSky, Plaque, Rise } from "@/src/ui/lux/Lux";
import { L, REALM_LIGHT } from "@/src/ui/lux/tokens";

export default function LuxShowcase() {
  return (
    <View style={{ flex: 1 }}>
      <NightSky />
      <ScrollView contentContainerStyle={{ padding: 24, gap: 22, paddingTop: 60 }}>
        <View style={{ flexDirection: "row", gap: 8 }}>
          <Capsule value="1,566" gem={<Gem size={20} pulse />} />
          <Capsule value="55" gem={<Gem size={20} colors={[L.crystalSoft, L.aether]} glow={L.aether} />} />
        </View>
        <Plaque title="THE VERDANT REACH" sub="Moss-wrapped ruins" />
        <Rise>
          <GlassFrame style={{ padding: 20, gap: 12 }}>
            {LuxText.label("LEVEL 7")}
            {LuxText.display("Mossglen")}
            {LuxText.body("Roots have grown through the old Keeper stones here.")}
            <Meter value={0.68} />
          </GlassFrame>
        </Rise>
        <LuxButton label="PLAY" hero onPress={() => {}} />
        <View style={{ flexDirection: "row", gap: 12 }}>
          <LuxButton label="SANCTUARY" variant="glass" onPress={() => {}} />
          <LuxButton label="EVENT" variant="rose" onPress={() => {}} />
        </View>
        <View style={{ flexDirection: "row", gap: 40, paddingLeft: 20 }}>
          {(["done", "current", "locked"] as const).map((s) => (
            <View key={s} style={{ width: 64, height: 64 }}>
              <Medallion size={64} colors={REALM_LIGHT.verdant} state={s} />
            </View>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

StyleSheet.create({});
