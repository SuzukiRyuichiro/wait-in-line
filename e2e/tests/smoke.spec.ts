import { test, expect, MAILPIT_URL } from "./support/fixtures";

test("app is up", async ({ page, request }) => {
  const health = await request.get("/up");
  expect(health.ok()).toBeTruthy();

  const res = await page.goto("/");
  expect(res?.status()).toBe(200);
});

test("mailpit is reachable", async ({ request }) => {
  const res = await request.get(`${MAILPIT_URL}/api/v1/messages`);
  expect(res.ok()).toBeTruthy();
});
