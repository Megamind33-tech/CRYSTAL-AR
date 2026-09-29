import { useState } from "react";
import { View } from "react-native";
import { NOTIFICATIONS } from "../meta/config/live";
import type { NotificationClass } from "../meta/types";
import { metaStore, setPlayer } from "../state/meta";
import { useStore } from "../state/store";
import { Field, OptionRow, Section, Toggle } from "./kit";

/** Per-class notification switches (all independently disableable) and the account country. */
export function AccountSettings() {
  const p = useStore(metaStore, (m) => m.player);
  const [country, setCountry] = useState(p?.profile.country ?? "");
  if (!p) return null;
  return (
    <View style={{ gap: 18 }}>
      <Section title="Notifications">
        <View>
          {(Object.keys(NOTIFICATIONS) as NotificationClass[]).map((k) => (
            <OptionRow key={k} label={NOTIFICATIONS[k].title} hint={NOTIFICATIONS[k].body}>
              <Toggle
                accessibilityLabel={`${NOTIFICATIONS[k].title} notifications`}
                value={p.notifications[k]}
                onChange={(v) => setPlayer((s) => ({ ...s, notifications: { ...s.notifications, [k]: v } }))}
              />
            </OptionRow>
          ))}
        </View>
      </Section>
      <Section title="Region">
        <OptionRow label="Country for regional rankings" hint="Two-letter code, e.g. NG, GB, US. Optional – your location is never read.">
          <Field
            value={country}
            onChangeText={(v) => {
              const code = v.toUpperCase().replace(/[^A-Z]/g, "").slice(0, 2);
              setCountry(code);
              setPlayer((s) => ({ ...s, profile: { ...s.profile, country: code.length === 2 ? code : undefined } }));
            }}
            autoCapitalize="characters"
            maxLength={2}
            placeholder="—"
            style={{ width: 60, textAlign: "center" }}
          />
        </OptionRow>
      </Section>
    </View>
  );
}
