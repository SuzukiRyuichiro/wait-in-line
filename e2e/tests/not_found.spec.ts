import { test, expect } from "./support/fixtures";

// E9: a mistyped or incomplete party link gets a helpful page, not a dead end.

test("a mistyped party link explains itself and leads back to the join form", async ({ page }) => {
  const response = await page.goto("/parties/not-a-real-token");

  expect(response?.status()).toBe(404);
  await expect(page.getByRole("heading", { name: "We couldn't find that party" })).toBeVisible();

  await page.getByRole("link", { name: "Join the waitlist" }).click();
  await expect(page.getByRole("button", { name: "Join waitlist" })).toBeVisible();
});
