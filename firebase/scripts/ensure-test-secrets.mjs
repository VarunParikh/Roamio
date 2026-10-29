// The functions emulator asks Secret Manager for any secret it has no local
// value for. CI isn't signed in to Google, so those lookups fail and break
// the first calls. Give the emulator a harmless placeholder instead, unless
// a developer already has a real functions/.secret.local.
import { existsSync, writeFileSync } from "node:fs";

const file = new URL("../functions/.secret.local", import.meta.url);
if (!existsSync(file)) {
  writeFileSync(file, "UNSPLASH_ACCESS_KEY=test-placeholder\n");
  console.log("Created functions/.secret.local with test placeholders.");
}
