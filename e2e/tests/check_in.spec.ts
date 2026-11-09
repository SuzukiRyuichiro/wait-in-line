import { test, expect } from "./support/fixtures";
import { joinWaitlist } from "./support/diners";

// Story H5: check in and get seated. The spec: when the party is ready the app
// shows a "Check in" button; clicking it seats the party and starts the
// service countdown. Service end (H7) is a separate story.

test("a ready diner checks in and is seated", async ({ page }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com", size: 3 });
  await expect(page.getByRole("heading", { name: "Your table is ready, Aiko!" })).toBeVisible();

  await page.getByRole("button", { name: "Check in" }).click();

  await expect(page.getByRole("heading", { name: "Enjoy your meal, Aiko!" })).toBeVisible();
  await expect(page.getByText("Party of 3. Your service ends in")).toBeVisible();
  await expect(page.getByRole("button", { name: "Check in" })).toHaveCount(0);
  await expect(page).toHaveTitle(/Enjoy your meal/);
});

test("checking in again from another browser just shows the seated party", async ({ page, browser }) => {
  await joinWaitlist(page, { name: "Aiko Tanaka", email: "aiko@example.com" });
  const phone = await browser.newContext();
  const phonePage = await phone.newPage();
  await phonePage.goto(page.url());
  await expect(phonePage.getByRole("button", { name: "Check in" })).toBeVisible();

  await page.getByRole("button", { name: "Check in" }).click();
  await expect(page.getByRole("heading", { name: "Enjoy your meal, Aiko!" })).toBeVisible();

  // The phone still shows the old ready page. Tapping there is harmless.
  await phonePage.getByRole("button", { name: "Check in" }).click();
  await expect(phonePage.getByRole("heading", { name: "Enjoy your meal, Aiko!" })).toBeVisible();
  await expect(phonePage.getByRole("status")).toHaveCount(0); // no error notice
  await phone.close();
});
