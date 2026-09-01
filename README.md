# Touchline

A free Rails app for TRL (Touch Rugby League) teams to track player tries and assists across a season, with fixtures and results synced automatically from TRL Australia's Spawtz platform.

## What it does

- Teams register in the app and link to their Spawtz venue/league/season
- Fixtures and results are scraped automatically from Spawtz — no manual entry
- Members record post-game stats for each player: who played, plus tries and assists
- Stats are checked against TRL's own scoreline — a team can never be credited with more tries, or more assists, than TRL published for that game
- Stats can still be entered on the night, before TRL posts the result; they count on your team's leaderboard straight away and are marked *awaiting TRL* until the result lands
- Verification is tracked for a planned cross-team social league (same venue, same night), where unchecked stats would distort everyone else's standing
- A leaderboard ranks players by points (tries × 2 + assists × 1), filterable by season or all time
- Every player has a stats page — career totals, seasons played, and averages per game and per season
- Players can optionally link their account to their roster entry and see their own profile

## Tech stack

- **Ruby** 3.2.3
- **Rails** 8.0
- **PostgreSQL**
- **Hotwire** (Turbo + Stimulus)
- **Resend** for transactional email
- Deployed with **Kamal** to [touchline.levibuilds.au](https://touchline.levibuilds.au)

## Local setup

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Requires a local PostgreSQL instance. Set `TOUCHLINE_DATABASE_PASSWORD` in your environment if needed.

## Running tests

```bash
bin/rails test
bin/rails test:system
```

## Deployment

Deployed via Kamal:

```bash
kamal deploy
```

The production image is built from the `Dockerfile` in the project root. Set `RAILS_MASTER_KEY` from `config/master.key` as a deploy secret.
