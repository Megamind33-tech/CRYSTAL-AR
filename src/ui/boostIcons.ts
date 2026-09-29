// Rendered item art (tools/asset-pipeline/render-icons.mjs). One image per boost.
import type { ImageSourcePropType } from "react-native";
import type { BoostId } from "../game/boosts";

export const BOOST_ICONS: Record<BoostId, ImageSourcePropType> = {
  moves_plus_3: require("../../assets/ui/armory/moves_plus_3.webp"),
  moves_plus_5: require("../../assets/ui/armory/moves_plus_5.webp"),
  moves_plus_10: require("../../assets/ui/armory/moves_plus_10.webp"),
  gem_multiplier: require("../../assets/ui/armory/gem_multiplier.webp"),
  score_x15: require("../../assets/ui/armory/score_x15.webp"),
  charge_start: require("../../assets/ui/armory/charge_start.webp"),
  surge_rate_up: require("../../assets/ui/armory/surge_rate_up.webp"),
  surge_four: require("../../assets/ui/armory/surge_four.webp"),
  starting_clears: require("../../assets/ui/armory/starting_clears.webp"),
  prep_four: require("../../assets/ui/armory/prep_four.webp"),
};

export const FRAMES = {
  common: require("../../assets/ui/armory/frame_common.webp"),
  uncommon: require("../../assets/ui/armory/frame_uncommon.webp"),
  rare: require("../../assets/ui/armory/frame_rare.webp"),
} satisfies Record<"common" | "uncommon" | "rare", ImageSourcePropType>;
