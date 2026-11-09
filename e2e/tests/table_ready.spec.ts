import { test, expect } from "./support/fixtures";
import { joinWaitlist, seatAheadOfUs } from "./support/diners";
import { latestEmailTo } from "./support/mailpit";

// Story H4 (ready screen + "table ready" email) and H10 (ready right away when
// seats are free), with strict first-in, first-out order (A7). The Check in
// button comes with H5.

test("a diner who joins an empty restaurant gets a table right away", async ({ page }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 3 });

  await expect(page.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();
  await expect(page.getByText("Party of 3")).toBeVisible();
  await expect(page).toHaveTitle(/Your table is ready/);
});

test("the diner gets a table-ready email whose link opens their party anywhere", async ({ page, browser }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 3 });
  await expect(page.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();

  const email = await latestEmailTo(page.request, "aiko@example.com");
  expect(email.Subject).toBe("Your table is ready, Aiko");
  expect(email.Text).toContain("Your table for 3 is ready");

  // APP_HOST=web-e2e:3000 on the e2e stack, so the link points where Playwright browses.
  const link = email.Text.match(/https?:\/\/\S+\/parties\/[\w-]+/)?.[0];
  expect(link).toBe(page.url());

  const phone = await browser.newContext();
  const phonePage = await phone.newPage();
  await phonePage.goto(link!);
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
