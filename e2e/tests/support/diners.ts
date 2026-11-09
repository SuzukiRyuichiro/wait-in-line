import { expect, type Browser, type Page } from "@playwright/test";

export async function joinWaitlist(page: Page, diner: { name: string; email: string; size?: number }) {
  await page.goto("/");
  await page.getByLabel("Name").fill(diner.name);
  await page.getByLabel("Email").fill(diner.email);
  if (diner.size) await page.getByLabel("Party size").fill(String(diner.size));
  await page.getByRole("button", { name: "Join waitlist" }).click();
}

// A party joins from its own browser and becomes ready right away, holding
// its seats. A party of 10 (the default) takes every seat, so the next diners
// have to wait. A ready party keeps its seats until it checks in, so the
// restaurant stays full for the rest of the test.
export async function seatAheadOfUs(browser: Browser, size = 10) {
  const context = await browser.newContext();
  const page = await context.newPage();
  await joinWaitlist(page, { name: "Big Group", email: `group-of-${size}@example.com`, size });
  await expect(page.getByRole("heading", { name: /Your table is ready/ })).toBeVisible();
  return { context, page };
}
