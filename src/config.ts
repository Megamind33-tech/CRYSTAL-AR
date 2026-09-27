import { Platform } from "react-native";

/** DEV_AR_MOCK: web always uses the mock table; native only when EXPO_PUBLIC_DEV_AR_MOCK=true. Never a production path. */
/** Web mock picks cells in JS (see src/dev/mockPicking.ts); native uses Viro hit-testing. */
export const JS_PICKING = Platform.OS === "web";

export const DEV_AR_MOCK = Platform.OS === "web" || process.env.EXPO_PUBLIC_DEV_AR_MOCK === "true";
