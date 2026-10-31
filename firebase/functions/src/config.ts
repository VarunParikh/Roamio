import { getRemoteConfig } from "firebase-admin/remote-config";
import { logger } from "firebase-functions";

// Server-side Remote Config keys (spec §11), each with a default so the
// functions behave the same when Remote Config can't be reached. Listed
// with the app's keys in docs/REMOTE_CONFIG.md.

export const SERVER_CONFIG_DEFAULTS = {
  budget_alert_thresholds: "[80, 100]",
  /** How long a shared invite link works (spec UC-9). */
  invite_validity_days: "14",
  consent_link_validity_days: "7",
};

export type ServerConfig = {
  /** Percentages of a budget that trigger an alert, ascending. */
  budgetThresholds: number[];
  inviteDays: number;
  consentDays: number;
};

type Values = Partial<Record<keyof typeof SERVER_CONFIG_DEFAULTS, string>>;

function days(raw: string | undefined, fallback: string, max: number): number {
  const n = Number(raw);
  return Number.isInteger(n) && n >= 1 && n <= max ? n : Number(fallback);
}

function thresholds(raw: string | undefined): number[] {
  try {
    const list: unknown = JSON.parse(raw ?? "");
    if (
      Array.isArray(list) &&
      list.length > 0 &&
      list.every((t) => Number.isInteger(t) && t >= 1 && t <= 200)
    ) {
      return [...(list as number[])].sort((a, b) => a - b);
    }
  } catch {
    // Not JSON: use the default below.
  }
  return JSON.parse(SERVER_CONFIG_DEFAULTS.budget_alert_thresholds) as number[];
}

/** The configured values, each replaced by its default when missing or garbled. */
export function parseServerConfig(values: Values): ServerConfig {
  const d = SERVER_CONFIG_DEFAULTS;
  return {
    budgetThresholds: thresholds(values.budget_alert_thresholds),
    inviteDays: days(values.invite_validity_days, d.invite_validity_days, 90),
    consentDays: days(values.consent_link_validity_days, d.consent_link_validity_days, 30),
  };
}

const KEEP_MS = 10 * 60 * 1000;

type ReadValues = () => Promise<Partial<Record<keyof typeof SERVER_CONFIG_DEFAULTS, string>>>;
type Warn = (message: string, details: { error: string }) => void;

/**
 * Keeps the answer of [read] for 10 minutes per instance. A failure, such as
 * no server template having been published, keeps the defaults just as long,
 * so it isn't asked for and warned about on every call.
 */
export function cachedConfig(read: ReadValues, warn: Warn) {
  let cached: { at: number; config: ServerConfig } | undefined;
  return async (now = Date.now()): Promise<ServerConfig> => {
    if (cached && now - cached.at < KEEP_MS) return cached.config;
    let config: ServerConfig;
    try {
      config = parseServerConfig(await read());
    } catch (e) {
      warn("Remote Config unavailable; using defaults", { error: String(e) });
      config = parseServerConfig({});
    }
    cached = { at: now, config };
    return config;
  };
}

const liveConfig = cachedConfig(
  async () => {
    const template = await getRemoteConfig().getServerTemplate({
      defaultConfig: SERVER_CONFIG_DEFAULTS,
    });
    const live = template.evaluate();
    const keys = Object.keys(SERVER_CONFIG_DEFAULTS) as (keyof typeof SERVER_CONFIG_DEFAULTS)[];
    return Object.fromEntries(keys.map((k) => [k, live.getString(k)]));
  },
  (message, details) => logger.warn(message, details),
);

/**
 * The live values, read at most every 10 minutes per instance. The
 * emulator has no Remote Config, so it (and any failure) gets the defaults.
 */
export async function serverConfig(): Promise<ServerConfig> {
  if (process.env.FUNCTIONS_EMULATOR === "true") return parseServerConfig({});
  return liveConfig();
}
