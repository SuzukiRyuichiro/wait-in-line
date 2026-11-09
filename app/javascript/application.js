// Islands: the server renders every page as plain HTML, and only elements that
// opt in with data-island="…" get a bit of JS. No framework, no dependencies.
import { liveStatus } from "islands/live_status"
import { countdown } from "islands/countdown"

const islands = { "live-status": liveStatus, countdown }

document.querySelectorAll("[data-island]").forEach((el) => islands[el.dataset.island]?.(el))
