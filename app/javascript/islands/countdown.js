// Counts down to the end of a seated party's service (H6).
//
// <time data-island="countdown" datetime="<service ends>" data-server-now="<render time>">
//
// Both times come from the server. Comparing data-server-now with this device's
// clock at load gives the skew, so a phone whose clock is off still counts
// down to the right moment (decision 1.12 rule 5).
export function countdown(el) {
  const endsAt = Date.parse(el.dateTime)
  const skew = Date.parse(el.dataset.serverNow) - Date.now()

  function tick() {
    const seconds = Math.max(0, Math.ceil((endsAt - (Date.now() + skew)) / 1000))
    el.textContent = seconds > 0 ? `in ${seconds} second${seconds === 1 ? "" : "s"}` : "any moment now"
    if (seconds > 0) setTimeout(tick, 1000)
  }

  tick()
}
