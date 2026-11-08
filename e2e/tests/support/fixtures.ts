import { test as base, expect } from "@playwright/test";

export const MAILPIT_URL = process.env.MAILPIT_URL ?? "http://localhost:8025";

// Every test starts from an empty waitlist and an empty inbox.
// The waitlist is one shared FIFO queue, so a party left over from an earlier
// test would sit at the head of the line and block the next test.
export const test = base.extend<{ resetState: void }>({
  resetState: [
    async ({ request }, use) => {
      const reset = await request.post("/__e2e__/reset");
      expect(reset.status(), "POST /__e2e__/reset (is the app running with RAILS_ENV=e2e?)").toBe(204);

      const inbox = await request.delete(`${MAILPIT_URL}/api/v1/messages`);
      expect(inbox.ok()).toBeTruthy();

      await use();
    },
    { auto: true },
  ],
});

export { expect };
