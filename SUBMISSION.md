# Wait in Line: Remote Waitlist Manager

A virtual waitlist for a restaurant (10 seats, 3 seconds of service per person). Diners join from their browser, watch their place in the queue, and check in when their table is ready.

## Quick start

**Prerequisites:** Docker with Compose v2 (Docker Desktop, or Docker Engine plus the compose plugin). Nothing else is needed: no Ruby, Node or MongoDB on your machine.

```bash
git clone https://github.com/SuzukiRyuichiro/wait-in-line.git
cd wait-in-line
docker compose up
```

The first run builds the image and runs `bundle install`, so it takes a few minutes. It is ready when the `web` container logs `Listening on http://0.0.0.0:3000`.

| What | URL |
|---|---|
| The app (diner view) | http://localhost:3000 |
| Mailpit inbox (emails the app "sends") | http://localhost:8025 |

Make sure ports **3000**, **8025**, **1025** and **27017** are free on your machine.

To stop, press `Ctrl+C`, then `docker compose down`. To also wipe the database, run `docker compose down -v`.

## What `docker compose up` starts

| Service | Role |
|---|---|
| `web` | Rails 8 app (Puma), server-rendered HTML |
| `scheduler` | Same image, runs `bin/rails waitlist:tick_forever`, a loop that advances the queue |
| `mongo` | MongoDB 9 as a single-node replica set. The healthcheck initiates the replica set, so there is no manual step |
| `mailpit` | Local SMTP server with a web inbox, so you can read the emails without a real mail provider |
| `e2e`, `web-e2e`, `scheduler-e2e` | Playwright tests and their own copy of the app, on a separate database with faster timings. Only start with `--profile e2e` (see below) |

## Running the tests

End-to-end tests (Playwright) run in a container against their own copy of the app (`web-e2e` + `scheduler-e2e`, database `wait_in_line_e2e`), so they never touch the data you click around with. Service time there is 1 second per person to keep the tests fast, and every test starts from an empty queue:

```bash
docker compose --profile e2e run --rm e2e
```

The HTML report is written to `e2e/playwright-report/`.

Unit and request specs (RSpec):

```bash
docker compose --profile test run --rm test
```

## Configuration

All settings are environment variables in `docker-compose.yml`. The defaults match the spec, so you don't need to change anything.

| Variable | Default | Meaning |
|---|---|---|
| `SERVICE_SECONDS_PER_PERSON` | `3` | Service time per diner in the party |
| `TICK_INTERVAL_SECONDS` | `1` | How often the scheduler advances the queue |
| `APP_HOST` | `localhost:3000` | Host used for links in emails |

## How it works

### A party's life

```
waiting ──(seats free, first in line)──▶ ready ──(diner taps Check in)──▶ seated ──(size × 3s later)──▶ completed
          scheduler                               web request                       scheduler
```

Two kinds of actors move a party along, and MongoDB is the only shared state:

- **Web requests do what a diner does:** join, check in.
- **The scheduler does what the clock does:** finish service, then call the next party. It's a separate container running a loop that calls `Waitlist::Settle` and `Waitlist::NotifyReady` every second.

The `restaurants` document holds two seat counters:

- **`seats_reserved`** (ready + seated) decides whether the next party fits, so seats held for a party that hasn't checked in yet are never handed out twice.
- **`seats_occupied`** (seated only) is the spec's "seats available, decreased by the party size at check-in".

### Joining (`Waitlist::Join`)

1. In one transaction: take the next ticket number (an atomic `$inc` on the restaurant), then insert the party as `waiting`.
2. **No duplicates:** a unique index on `email`, limited to *active* parties (waiting, ready or seated), rejects a second entry even when two requests race. The diner is sent to their existing party ("You're already on the list"). After their meal they can join again with the same email.
3. Right after a join, the request runs `Settle` once, so a diner who walks into an empty restaurant is ready immediately instead of on the next tick.

### Settling the queue (`Waitlist::Settle`)

Each run does two steps, each as small transactions:

1. **Finish service:** every seated party whose `service_ends_at` has passed becomes `completed`, and its seats are released.
2. **Call the next party:** take the first waiting party by ticket number. If it fits, reserve its seats and mark it `ready`; repeat. If it doesn't fit, stop: nobody behind it skips ahead (strict first-in, first-out).

**Why it can't overbook:** reserving uses a conditional update, "add N seats *only if* `seats_reserved <= 10 - N`", so the counter can never pass capacity. Every step also writes the restaurant document, so two runs at the same time (the scheduler and a join request) conflict, and MongoDB retries one of them. A test runs 8 settles in parallel threads and checks this. It fails when the transaction is removed.

**Why a loop instead of scheduled jobs:** the loop keeps no plan in memory. Each tick reads the facts from the database ("whose service has ended?") and acts. If the scheduler crashes or restarts, nothing is lost: the next tick catches up. A per-party job ("finish party X at 12:00:30") would live in memory and vanish on restart, leaving those seats taken forever, unless we added Redis or a SQL-backed queue.

### The other pieces

- **Check in (`Waitlist::CheckIn`):** a conditional update `ready → seated` (only if still ready), which also sets `service_ends_at`, and `seats_occupied += size`. A double tap or two browsers seat the party once.
- **Email (`Waitlist::NotifyReady`):** only the scheduler sends it. It emails every ready party that hasn't been emailed yet, then records `notified_at`. If sending fails, the party is still ready and the next tick retries.
- **Live page:** waiting and seated pages poll `GET /parties/:token/status.json` every 2 seconds and reload when the status or place in line changes, so the server-rendered HTML is the only markup. The seated page counts down locally. If the network drops it says "Reconnecting…" and backs off. Without JavaScript, a Refresh link does the same job.
- **Seeing your party anywhere:** a signed cookie remembers your party in this browser. The party link (also in the email) opens it in any other browser.

### Stack

- **Rails 8 + Mongoid** on MongoDB. Mongo is required by the spec; Mongoid is its official ODM.
- **Server-rendered HTML with two tiny vanilla-JS islands** (`live_status`, `countdown`), loaded through an importmap with no build step. Not an SPA.
- **MongoDB as a single-node replica set**, because multi-document transactions (party + restaurant counters) need one. The healthcheck initiates it, so there's no manual step.
- **Mailpit** catches the emails locally, so no real mail provider is needed.
- **Dev-mode Docker image** with the source bind-mounted, since the requirement is a local `docker compose up`.

## Scope decisions & known limitations

The spec leaves gaps. These are the calls I made, weighed against the time available.

| Decision | Why | Cost / what I'd do next |
|---|---|---|
| **No check-in deadline, no "no-show"** | The spec says only that the next party gets a Check in button when seats are free, and otherwise the queue waits | A ready party that never checks in holds its seats, and everyone behind it waits. Next: a check-in window that releases the seats, or a staff "skip". The reserved/occupied split makes it one more scheduler step. Locally, `docker compose down -v` unsticks a demo |
| **Strict first-in, first-out** | The spec says the system checks "the next party" and otherwise waits | Seats can sit idle while a big party at the head waits. Next: let smaller parties fill gaps |
| **No wait-time estimate** | Not asked for, and an honest one is hard without a check-in deadline. A wrong estimate hurts trust more than none | Diners see their place in line instead |
| **No "find my spot by email"** | Cross-browser access is already covered by the cookie, the party link and the email link. A lookup by email would show anyone's party to whoever knows the address | A diner on a new device before their email arrives can't get back. Next: an "email me my link" button |
| **One restaurant, capacity in code** | The spec hardcodes 10 seats | Parties already reference a restaurant, so more venues is mostly routing |
| **Polling, not push** | No extra infrastructure (WebSockets would need Redis) | Fine for one venue. Next: server-sent events |
| **Tailwind, daisyUI and Lucide from a CDN** | No build step. The app's own JavaScript has no dependencies; these are styling and icons | Extra download (Tailwind compiles in the browser; Lucide ships every icon), and the page relies on the CDN. Next: compile CSS and icons at build time |
| **No staff screen** | The spec's flow is entirely diner-driven | — |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `port is already allocated` | Another process uses 3000, 8025, 1025 or 27017. Stop it, or change the left-hand side of the port mapping in `docker-compose.yml` |
| `web` waits for a long time on first start | `mongo` has to become healthy first (up to about a minute on first boot). Check with `docker compose ps` |
| `mongo` exits right away (`docker compose ps -a` shows `Exited (1)`) | Check `docker compose logs mongo`. MongoDB refuses to start on Linux kernel 6.19+ (SERVER-121912). Update Docker Desktop (or your VM), then check the kernel with `docker info \| grep Kernel` |
| Stale state while testing | `docker compose down -v` resets the database |
| Code changes don't show up | The source is bind-mounted, so refresh the page. If you changed the `Gemfile`, run `docker compose build` |
