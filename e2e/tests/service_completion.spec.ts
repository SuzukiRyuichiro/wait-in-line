import { test, expect, type Page } from "./support/fixtures";
import { joinWaitlist } from "./support/diners";

// Story H7: when a party's service ends, its seats are freed and the next
// party's app shows the Check in button. The e2e stack runs with
// SERVICE_SECONDS_PER_PERSON=1, so a party of 5 is served in 5 seconds.

// No live updates yet (H3), so the diner refreshes until the heading appears.
async function refreshUntil(page: Page, heading: string) {
  await expect(async () => {
    await page.reload();
    await expect(page.getByRole("heading", { name: heading })).toBeVisible({ timeout: 500 });
  }).toPass({ timeout: 15_000 });
}

test("when a party finishes, the next party in line gets the table", async ({ page, browser }) => {
  // Aiko's party of 5 is seated: 5 of 10 seats taken.
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 5 });
  await page.getByRole("button", { name: "Check in" }).click();
  await expect(page.getByRole("heading", { name: "Enjoy your meal, Aiko!" })).toBeVisible();

  // Ben's party of 6 doesn't fit in the 5 free seats, so Ben waits.
  const otherBrowser = await browser.newContext();
  const ben = await otherBrowser.newPage();
  await joinWaitlist(ben, { name: "Ben Carter", email: "ben@example.com", size: 6 });
  await expect(ben.getByRole("heading", { name: "Hi Ben, you're in line" })).toBeVisible();

  // Aiko's service ends: Ben gets the table, Aiko gets a goodbye.
  await refreshUntil(ben, "Your table is ready, Ben!");
  await expect(ben.getByRole("button", { name: "Check in" })).toBeVisible();

  await page.reload();
  await expect(page.getByRole("heading", { name: "Thanks for dining, Aiko!" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Refresh" })).toHaveCount(0);
  await otherBrowser.close();
});

test("a diner who has finished can join the waitlist again with the same email", async ({ page }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 2 });
  await page.getByRole("button", { name: "Check in" }).click();
  await refreshUntil(page, "Thanks for dining, Aiko!");

  await page.getByRole("link", { name: "Join the waitlist again" }).click();
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 2 });

  await expect(page.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();
  await expect(page.getByText("You're already on the list.")).toHaveCount(0);
});
