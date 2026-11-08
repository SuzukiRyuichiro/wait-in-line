import { test, expect } from "./support/fixtures";
import { joinWaitlist, seatAheadOfUs } from "./support/diners";

// Story H4 (ready screen) and H10 (seated right away when seats are free),
// with strict first-in, first-out order (A7). The table-ready email is a
// separate story; the Check in button comes with H5.

test("a diner who joins an empty restaurant gets a table right away", async ({ page }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 3 });

  await expect(page.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();
  await expect(page.getByText("Party of 3")).toBeVisible();
  await expect(page).toHaveTitle(/Your table is ready/);
});

test("the table stays ready when the diner opens their link in another browser", async ({ page, browser }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com" });
  await expect(page.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();

  const phone = await browser.newContext();
  const phonePage = await phone.newPage();
  await phonePage.goto(page.url());
  await expect(phonePage.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();
  await phone.close();
});

test("a smaller party can't skip ahead of a bigger one that doesn't fit yet", async ({ page, browser }) => {
  // 8 of 10 seats are held, so 2 are free.
  const groupOfEight = await seatAheadOfUs(browser, 8);

  // A party of 4 doesn't fit and waits at the head of the line.
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 4 });
  await expect(page.getByRole("heading", { name: "Hi Aiko, you're in line" })).toBeVisible();

  // A party of 2 would fit in the free seats, but it's behind Aiko.
  const otherBrowser = await browser.newContext();
  const ben = await otherBrowser.newPage();
  await joinWaitlist(ben, { name: "Ben Carter", email: "ben@example.com", size: 2 });
  await expect(ben.getByRole("heading", { name: "Hi Ben, you're in line" })).toBeVisible();
  await expect(ben.getByText("1 party ahead of you")).toBeVisible();

  await otherBrowser.close();
  await groupOfEight.context.close();
});
