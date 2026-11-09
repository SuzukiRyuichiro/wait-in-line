import { expect, type APIRequestContext } from "@playwright/test";
import { MAILPIT_URL } from "./fixtures";

type Message = { Subject: string; Text: string };

// The newest email to this address, read from Mailpit's API. The ticker sends
// it (not the join request), so poll until it shows up.
export async function latestEmailTo(request: APIRequestContext, to: string): Promise<Message> {
  let id = "";
  await expect(async () => {
    const res = await request.get(`${MAILPIT_URL}/api/v1/search?query=${encodeURIComponent(`to:"${to}"`)}`);
    const { messages } = await res.json();
    expect(messages.length).toBeGreaterThan(0);
    id = messages[0].ID;
  }).toPass({ timeout: 5_000 });

  const res = await request.get(`${MAILPIT_URL}/api/v1/message/${id}`);
  return (await res.json()) as Message;
}
