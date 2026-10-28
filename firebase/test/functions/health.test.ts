import { describe, expect, it } from "vitest";

describe("health function", () => {
  it("responds ok from the Mumbai region", async () => {
    const res = await fetch("http://127.0.0.1:5001/demo-roamio/asia-south1/health");

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok", service: "roamio-functions" });
  });
});
