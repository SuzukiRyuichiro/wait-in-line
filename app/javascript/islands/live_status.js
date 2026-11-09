// Keeps the party page up to date without the diner refreshing (H3).
//
// Polls the status endpoint and reloads the page when the party's state no
// longer matches what the page was rendered with. The server-rendered ERB
// stays the only place the markup lives; this script never builds HTML.
//
// <p data-island="live-status" data-status-url="…" data-status="waiting" data-position="2">
//   … <span data-reconnecting hidden>Reconnecting…</span>
// </p>
const POLL_MS = 2000
const MAX_BACKOFF_MS = 30000

export function liveStatus(el) {
  // data-position is absent when there's no position (nil attributes aren't rendered).
  const rendered = `${el.dataset.status}:${el.dataset.position ?? ""}`
  const reconnecting = el.querySelector("[data-reconnecting]")
  let delay = POLL_MS

  async function poll() {
    try {
      const response = await fetch(el.dataset.statusUrl, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`status ${response.status}`)
      const { status, position } = await response.json()

      reconnecting.hidden = true
      delay = POLL_MS
      if (`${status}:${position ?? ""}` !== rendered) return location.reload()
    } catch {
      // Network drop or server error (E11): keep showing the last known state,
      // say so, and back off so a down server isn't hammered.
      reconnecting.hidden = false
      delay = Math.min(delay * 2, MAX_BACKOFF_MS)
    }
    setTimeout(poll, delay)
  }

  setTimeout(poll, delay)
}
