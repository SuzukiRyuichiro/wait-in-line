import { test, expect } from "./support/fixtures";
import { joinWaitlist } from "./support/diners";

// Story H7: when a party's service ends, its seats are freed and the next
// party's app shows the Check in button. The e2e stack runs with
// SERVICE_SECONDS_PER_PERSON=1, so a party of 5 is served in 5 seconds.
// Nobody refreshes: the pages update by themselves (H3, live_status.spec.ts).

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
  await expect(ben.getByRole("heading", { name: "Your table is ready, Ben!" })).toBeVisible({ timeout: 15_000 });
  await expect(ben.getByRole("button", { name: "Check in" })).toBeVisible();

  await expect(page.getByRole("heading", { name: "Thanks for dining, Aiko!" })).toBeVisible({ timeout: 15_000 });
  await expect(page.getByRole("link", { name: "Refresh" })).toHaveCount(0);
  await otherBrowser.close();
});

test("a diner who has finished can join the waitlist again with the same email", async ({ page }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 2 });
  await page.getByRole("button", { name: "Check in" }).click();
  await expect(page.getByRole("heading", { name: "Thanks for dining, Aiko!" })).toBeVisible({ timeout: 15_000 });

  await page.getByRole("link", { name: "Back to home" }).click();
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 2 });

  await expect(page.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();
  await expect(page.getByText("You're already on the list.")).toHaveCount(0);
});
