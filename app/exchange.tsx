import { useEffect, useState } from "react";
import { Text, View } from "react-native";
import { devPaymentProvider } from "@/src/backend/mockBackend";
import { applyVerifiedPurchase, buyWithCurrency, storeCatalog } from "@/src/meta/live";
import type { StoreOffer } from "@/src/meta/types";
import { act, analytics, backend, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Card, ErrorLine, Pill, RewardLine, Row, Screen, Section, T, Wallet } from "@/src/ui/kit";
import { F, L } from "@/src/ui/lux/tokens";

const SECTIONS: { id: StoreOffer["section"]; name: string }[] = [
  { id: "pass", name: "Crystal Pass" },
  { id: "expeditions", name: "Expeditions" },
  { id: "aether", name: "Aether" },
  { id: "sanctuary", name: "Sanctuary" },
  { id: "lumins", name: "Lumins" },
  { id: "portalEffects", name: "Portal Effects" },
  { id: "relics", name: "Relics" },
];

export default function Exchange() {
  const p = useStore(metaStore, (m) => m.player);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => analytics.track("store_opened"), []);
  if (!p) return null;
  const now = Date.now();
  const items = storeCatalog(p, now);

  const buy = async (o: StoreOffer) => {
    setErr(null);
    if (o.price.kind !== "iap") {
      setErr(act((s, t) => buyWithCurrency(s, o.id, t), ["purchase_completed", { offer: o.id, currency: o.price.kind }]));
      return;
    }
    setBusy(true);
    analytics.track("purchase_started", { offer: o.id });
    // DEV: no money moves. Replace devPaymentProvider with Google Play Billing before release.
    const res = await devPaymentProvider.purchase(o.price.sku);
    if (res.status !== "purchased") {
      setBusy(false);
      return;
    }
    const v = await backend.verifyPurchase(o.price.sku, res.receipt);
    setBusy(false);
    if (!v.valid) return setErr("The purchase could not be verified.");
    setErr(act((s, t) => applyVerifiedPurchase(s, o.id, res.receipt, t), ["purchase_completed", { offer: o.id }]));
  };

  const price = (o: StoreOffer) =>
    o.price.kind === "iap" ? `$${o.price.displayUsd.toFixed(2)}` : o.price.kind === "aether" ? `◆ ${o.price.amount}` : `✦ ${o.price.amount}`;

  return (
    <Screen title="Realm Exchange" subtitle="Traders who drift between the realms" right={<Wallet />}>
      <ErrorLine msg={err} />
      <Card style={{ borderColor: "rgba(127,231,255,0.6)" }}>{T.p("Development build: real-money offers use a test provider – nothing is charged.", true)}</Card>
      {SECTIONS.map((sec) => {
        const list = items.filter((i) => i.offer.section === sec.id);
        if (!list.length) return null;
        return (
          <Section key={sec.id} title={sec.name}>
            {list.map(({ offer, soldOut }) => (
              <Card key={offer.id} testID={`offer-${offer.id}`}>
                <Row style={{ justifyContent: "space-between" }}>
                  <View style={{ flex: 1 }}>
                    {T.h(offer.name)}
                    {T.p(offer.description, true)}
                  </View>
                  <Pill label={soldOut ? "OWNED" : price(offer)} disabled={soldOut || busy} tone={offer.price.kind === "aether" ? "portal" : "gold"} onPress={() => buy(offer)} />
                </Row>
                {(offer.grants.aether || offer.grants.items) && <RewardLine reward={offer.grants} />}
              </Card>
            ))}
          </Section>
        );
      })}
      <Text style={{ color: L.mist, fontSize: 11.5, textAlign: "center", fontFamily: F.body }}>Heart Shards and story islands are never sold.</Text>
    </Screen>
  );
}
