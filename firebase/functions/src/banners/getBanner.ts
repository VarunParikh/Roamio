import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret, defineString } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/https";
import countries from "../data/countries.json";

const unsplashKey = defineSecret("UNSPLASH_ACCESS_KEY");
const unsplashBase = defineString("UNSPLASH_API_BASE", { default: "https://api.unsplash.com" });

/** Unsplash asks apps to tag links back to it (API guidelines). */
const REFERRAL = "utm_source=roamio&utm_medium=referral";

type Banner = { url: string; photographer: string; photographerUrl: string; unsplashUrl: string };
type UnsplashPhoto = {
  urls: { raw: string };
  user: { name: string; links: { html: string } };
  links: { html: string; download_location: string };
};

/** "Grand Palace & Wat Arun (Bangkok)" → "Grand Palace". */
export function landmarkQuery(landmark: string): string {
  return landmark.split(/[&(/]/)[0].trim();
}

/** Unsplash's own image link, resized and compressed (spec §9.2, §10). */
export function bannerUrl(raw: string): string {
  const url = new URL(raw);
  url.searchParams.set("w", "1600");
  url.searchParams.set("fm", "webp");
  url.searchParams.set("q", "80");
  url.searchParams.set("fit", "crop");
  return url.toString();
}

async function unsplash<T>(url: string): Promise<T> {
  const res = await fetch(url, {
    headers: { Authorization: `Client-ID ${unsplashKey.value()}`, "Accept-Version": "v1" },
  });
  if (!res.ok) throw new Error(`Unsplash ${res.status}`);
  return (await res.json()) as T;
}

async function searchPhoto(query: string): Promise<UnsplashPhoto | undefined> {
  const params = new URLSearchParams({
    query,
    orientation: "landscape",
    per_page: "1",
    content_filter: "high",
  });
  const found = await unsplash<{ results: UnsplashPhoto[] }>(
    `${unsplashBase.value()}/search/photos?${params}`,
  );
  return found.results[0];
}

/**
 * The default banner for a country (spec §9.2): a landmark photo found once
 * on Unsplash and cached in `banners/{country}` for everyone. Photos stay on
 * Unsplash's CDN, as its API terms require, with the photographer credited.
 * Returns `{url: null}` when there's nothing usable, so the app shows its
 * gradient-and-flag fallback and asks again next time.
 */
export const getBanner = onCall({ secrets: [unsplashKey] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const code = String((request.data as { countryCode?: unknown })?.countryCode ?? "");
  const country = (countries as Record<string, { name: string; landmark: string }>)[code];
  if (!country) throw new HttpsError("invalid-argument", "Unknown country.");

  const cache = getFirestore().doc(`banners/${code}`);
  const cached = await cache.get();
  if (cached.exists) return cached.data() as Banner;

  try {
    const photo =
      (await searchPhoto(`${landmarkQuery(country.landmark)} ${country.name}`)) ??
      (await searchPhoto(country.name));
    if (!photo) return { url: null };

    // Unsplash counts a "download" whenever an app uses a photo.
    await unsplash(photo.links.download_location);
    const banner: Banner = {
      url: bannerUrl(photo.urls.raw),
      photographer: photo.user.name,
      photographerUrl: `${photo.user.links.html}?${REFERRAL}`,
      unsplashUrl: `${photo.links.html}?${REFERRAL}`,
    };
    await cache.set({ ...banner, fetchedAt: FieldValue.serverTimestamp() });
    return banner;
  } catch (e) {
    logger.warn("Banner lookup failed", { code, error: String(e) });
    return { url: null };
  }
});
