import { test, expect } from "./support/fixtures";
import { joinWaitlist } from "./support/diners";

// Story H3: the party page keeps itself up to date, so the diner never has to
// refresh. Also the seated countdown (H6) and losing the connection (E11).
// The e2e stack runs with SERVICE_SECONDS_PER_PERSON=1.

test("a waiting diner moves up the line without refreshing", async ({ page, browser }) => {
  // Aiko (5) is seated. Ben (6) and Cara (5) wait: together they need 11 seats.
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 5 });
  await page.getByRole("button", { name: "Check in" }).click();

  const benBrowser = await browser.newContext();
  await joinWaitlist(await benBrowser.newPage(), { name: "Ben Carter", email: "ben@example.com", size: 6 });

  const caraBrowser = await browser.newContext();
  const cara = await caraBrowser.newPage();
  await joinWaitlist(cara, { name: "Cara Diaz", email: "cara@example.com", size: 5 });
  await expect(cara.getByText("1 party ahead of you")).toBeVisible();

  // Aiko's service ends, Ben gets the table, and Cara is now first in line.
  await expect(cara.getByText("You're next")).toBeVisible({ timeout: 15_000 });
  await benBrowser.close();
  await caraBrowser.close();
});

test("a seated diner sees their service time count down", async ({ page }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 8 });
  await page.getByRole("button", { name: "Check in" }).click();

  const countdown = page.locator("time");
  await expect(countdown).toHaveText(/in [78] seconds/);
  await expect(countdown).toHaveText(/in [3-5] seconds/, { timeout: 5_000 });
});

test("the page says it's reconnecting while the connection is down, then recovers", async ({ page, browser }) => {
  // Fill the restaurant so Aiko waits (and her page polls).
  const otherBrowser = await browser.newContext();
  await joinWaitlist(await otherBrowser.newPage(), { name: "Big Group", email: "big@example.com", size: 10 });
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com" });
  await expect(page.getByRole("heading", { name: "Hi Aiko, you're in line" })).toBeVisible();

  await page.route("**/status.json", (route) => route.abort());
  await expect(page.getByText("Reconnecting…")).toBeVisible({ timeout: 10_000 });
  await expect(page.getByText("You're next")).toBeVisible(); // last known state stays

  await page.unroute("**/status.json");
  await expect(page.getByText("Reconnecting…")).toBeHidden({ timeout: 10_000 });
  await otherBrowser.close();
});
