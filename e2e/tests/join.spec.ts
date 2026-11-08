import { test, expect, type Page } from "./support/fixtures";
import { joinWaitlist, seatAheadOfUs } from "./support/diners";

// Story H2: join the waitlist. Each test starts from an empty queue
// (resetState in support/fixtures.ts). Server-side validation errors (422) are
// covered by spec/requests/parties_spec.rb: the form's required/min/max
// attributes stop that input in the browser before it reaches the server.
//
// A diner who joins while seats are free is ready at once (H10, see
// table_ready.spec.ts), so to see anyone "in line" a party of 10 takes every
// seat first.

function placeInLine(page: Page) {
  return page.locator("section").filter({ hasText: "Your place in line" });
}

test("a diner who joins a full restaurant is next in line", async ({ page, browser }) => {
  const bigGroup = await seatAheadOfUs(browser);
  await page.goto("/");
  await expect(page.getByText("0 parties")).toBeVisible();

  await page.getByLabel("Name").fill("Aiko Tanaka");
  await page.getByLabel("Email").fill("aiko@example.com");
  await page.getByRole("button", { name: "More guests" }).click(); // default 2 → 3
  await page.getByRole("button", { name: "Join waitlist" }).click();

  await expect(page).toHaveURL(/\/parties\/[\w-]+$/);
  await expect(page.getByRole("heading", { name: "Hi Aiko, you're in line" })).toBeVisible();
  await expect(page.getByText("Party of 3")).toBeVisible();
  await expect(placeInLine(page)).toContainText("1st");
  await expect(placeInLine(page)).toContainText("You're next");
  await bigGroup.context.close();
});

test("the next diner sees the line and how many parties are ahead", async ({ page, browser }) => {
  const bigGroup = await seatAheadOfUs(browser);
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com" });

  const otherBrowser = await browser.newContext();
  const ben = await otherBrowser.newPage();
  await ben.goto("/");
  await expect(ben.getByText("1 party", { exact: true })).toBeVisible();

  await joinWaitlist(ben, { name: "Ben Carter", email: "ben@example.com" });

  await expect(ben.getByRole("heading", { name: "Hi Ben, you're in line" })).toBeVisible();
  await expect(placeInLine(ben)).toContainText("2nd");
  await expect(placeInLine(ben)).toContainText("1 party ahead of you");
  await otherBrowser.close();
  await bigGroup.context.close();
});

test("coming back to the join page takes the diner to their party", async ({ page, browser }) => {
  const bigGroup = await seatAheadOfUs(browser);
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com" });
  const partyUrl = page.url();

  await page.goto("/");

  await expect(page).toHaveURL(partyUrl);
  await expect(page.getByRole("heading", { name: "Hi Aiko, you're in line" })).toBeVisible();
  await bigGroup.context.close();
});

test("the party link works in another browser, which then remembers the party", async ({ page, browser }) => {
  const bigGroup = await seatAheadOfUs(browser);
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com" });
  const partyUrl = page.url();

  const phone = await browser.newContext();
  const phonePage = await phone.newPage();
  await phonePage.goto(partyUrl);
  await expect(phonePage.getByRole("heading", { name: "Hi Aiko, you're in line" })).toBeVisible();

  await phonePage.goto("/");
  await expect(phonePage).toHaveURL(partyUrl);
  await phone.close();
  await bigGroup.context.close();
});

test("joining again with the same email goes to the existing party", async ({ page, browser }) => {
  const bigGroup = await seatAheadOfUs(browser);
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com" });
  const partyUrl = page.url();

  const otherBrowser = await browser.newContext();
  const again = await otherBrowser.newPage();
  await joinWaitlist(again, { name: "Aiko T", email: "AIKO@Example.com" });

  await expect(again).toHaveURL(partyUrl);
  await expect(again.getByText("You're already on the list.")).toBeVisible();
  await expect(placeInLine(again)).toContainText("1st");
  await otherBrowser.close();
  await bigGroup.context.close();
});
