// The functions' own firebase-admin copy, so tests and the code under test
// share one default app (the root package doesn't depend on firebase-admin).
export {
  getApps,
  initializeApp,
} from "../../functions/node_modules/firebase-admin/lib/esm/app/index.js";
export { getAuth } from "../../functions/node_modules/firebase-admin/lib/esm/auth/index.js";
export {
  getFirestore,
  Timestamp,
} from "../../functions/node_modules/firebase-admin/lib/esm/firestore/index.js";
