// Rendered item art (tools/asset-pipeline/render-icons.mjs). One image per boost.
import type { ImageSourcePropType } from "react-native";
import type { BoostId } from "../game/boosts";

export const BOOST_ICONS: Record<BoostId, ImageSourcePropType> = {
  moves_plus_3: require("../../assets/ui/armory/moves_plus_3.jpg"),
  moves_plus_5: require("../../assets/ui/armory/moves_plus_5.jpg"),
  moves_plus_10: require("../../assets/ui/armory/moves_plus_10.jpg"),
  gem_multiplier: require("../../assets/ui/armory/gem_multiplier.jpg"),
  score_x15: require("../../assets/ui/armory/score_x15.jpg"),
  charge_start: require("../../assets/ui/armory/charge_start.jpg"),
  surge_rate_up: require("../../assets/ui/armory/surge_rate_up.jpg"),
  surge_four: require("../../assets/ui/armory/surge_four.jpg"),
  starting_clears: require("../../assets/ui/armory/starting_clears.jpg"),
  prep_four: require("../../assets/ui/armory/prep_four.jpg"),
};
