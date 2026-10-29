import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/options";
import { onRequest } from "firebase-functions/https";

// Every function runs in Mumbai (DPDP, spec §8) and is capped to keep pilot costs near zero.
setGlobalOptions({ region: "asia-south1", maxInstances: 5 });
initializeApp();

export { setAgeStatus } from "./auth/setAgeStatus";

/** Liveness check used by CI and the emulator smoke test. */
export const health = onRequest((_req, res) => {
  res.json({ status: "ok", service: "roamio-functions" });
});
