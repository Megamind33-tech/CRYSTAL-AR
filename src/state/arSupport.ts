// Decides how the diorama is shown on this phone:
//   "ar"     – ARCore world tracking (certified devices)
//   "camera" – Camera View: live camera feed behind the world, no ARCore needed (e.g. Tecno Camon 19)
// Uncertified phones cannot use ARCore at all – sideloading Google Play Services for AR does not make
// tracking work – so they must get Camera View instead of a crashing AR session.
import { Platform } from "react-native";
import { isARSupportedOnDevice } from "@reactvision/react-viro";
import { arLog } from "../dev/log";
import { settingsStore } from "./settings";
import { createStore } from "./store";

export type ViewMode = "checking" | "ar" | "camera";

export const arSupport = createStore<{ detected: ViewMode; reason: string }>({ detected: "checking", reason: "" });

let started = false;
export function detectArSupport() {
  if (started) return;
  started = true;
  if (Platform.OS === "web") {
    arSupport.set({ detected: "camera", reason: "web" });
    return;
  }
  const attempt = async (n: number) => {
    try {
      const r = await isARSupportedOnDevice();
      arSupport.set({ detected: r.isARSupported ? "ar" : "camera", reason: r.isARSupported ? "" : "unsupported" });
      arLog("arSupport", { supported: r.isARSupported });
    } catch (e) {
      const reason = String((e as Error)?.message ?? e);
      // ARCore reports TRANSIENT while it is still checking – ask again shortly
      if (/TRANSIENT/i.test(reason) && n < 6) {
        setTimeout(() => attempt(n + 1), 600);
        return;
      }
      arSupport.set({ detected: "camera", reason });
      arLog("arSupport", { supported: false, reason });
    }
  };
  void attempt(0);
}

/** Effective mode: the player can force Camera View (e.g. ARCore installed but unstable). */
export function effectiveViewMode(detected: ViewMode, forceCamera: boolean): ViewMode {
  if (detected === "checking") return "checking";
  return forceCamera ? "camera" : detected;
}

export const useCameraViewForced = () => settingsStore.get().cameraView;
