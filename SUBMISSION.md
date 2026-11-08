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
| `e2e` | Playwright tests. Only runs with `--profile e2e` (see below) |

## Running the tests

End-to-end tests (Playwright) run in a container against the running stack:

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

## Architecture

- **Rails 8 + Mongoid** on MongoDB. The spec requires Mongo, so the app uses Mongoid, the official ODM, instead of ActiveRecord.
- **Server-side rendering with vanilla JS islands.** ERB renders every page. Small, dependency-free scripts, loaded through an importmap with no build step, update only the live parts, such as "is it my turn?". It is not an SPA.
- **Live updates by polling** a small JSON endpoint. It needs no extra infrastructure such as Redis.
- **No-duplicates and no-overbooking guarantees come from the database**, not from application checks. They use unique indexes and single-document conditional updates, which stay safe when requests arrive concurrently.
- **Replica set in Docker** so multi-document transactions are available if needed.
- **Dev-mode Docker image** with the source bind-mounted, since the requirement is a local `docker compose up`. A production image would precompile assets and run as a non-root user.

## Scope decisions & known limitations

### No check-in deadline

When a party's table is ready, it keeps its seats until it checks in. There is no time limit and no "no-show" state.

- **Why:** the spec doesn't define one. It says the next party's app shows a Check-in button when enough seats are free, and otherwise the queue waits. A deadline would add another timed transition, a race between "check in" and "expire", an extra screen and extra tests. I weighed that against the time available and the requirements actually given, and left it out.
- **Drawback:** the queue is strict first-in, first-out. A ready party that never checks in (for example, they left) holds its seats, and everyone behind it waits indefinitely. A real restaurant wouldn't accept that.
- **With more time:** a check-in window. A ready party that doesn't check in within N minutes becomes a no-show, its seats are released and the next party is called. Or a staff screen to skip a party. The seat accounting already separates *reserved* (ready + seated) from *occupied* (seated), so either would be one extra transition in the scheduler.
- **Locally:** if a demo gets stuck behind an abandoned party, `docker compose down -v` resets the database.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `port is already allocated` | Another process uses 3000, 8025, 1025 or 27017. Stop it, or change the left-hand side of the port mapping in `docker-compose.yml` |
| `web` waits for a long time on first start | `mongo` has to become healthy first (up to about a minute on first boot). Check with `docker compose ps` |
| Stale state while testing | `docker compose down -v` resets the database |
| Code changes don't show up | The source is bind-mounted, so refresh the page. If you changed the `Gemfile`, run `docker compose build` |
