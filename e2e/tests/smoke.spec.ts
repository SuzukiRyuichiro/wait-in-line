import { test, expect } from "@playwright/test";

test("app is up", async ({ page, request }) => {
  const health = await request.get("/up");
  expect(health.ok()).toBeTruthy();

  const res = await page.goto("/");
  expect(res?.status()).toBe(200);
});

test("mailpit is reachable", async ({ request }) => {
  const mailpit = process.env.MAILPIT_URL ?? "http://localhost:8025";
  const res = await request.get(`${mailpit}/api/v1/messages`);
  expect(res.ok()).toBeTruthy();
});
