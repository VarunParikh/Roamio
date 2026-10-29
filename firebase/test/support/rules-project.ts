// Security-rules tests use their own demo project. The Cloud Functions in
// the emulator run for "demo-roamio" only, so here no trigger (such as
// checkTab marking an adventure as having tabs) reacts to seeded data and
// races the test. Each rules file clears its own data per test.
export const RULES_PROJECT = "demo-roamio-rules";
