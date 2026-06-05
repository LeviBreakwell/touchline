# Touchline

A free Rails app for TRL (Touch Rugby League) teams to track player tries and assists across a season, with fixtures and results synced automatically from TRL Australia's Spawtz platform.

## What it does

- Teams register in the app and link to their Spawtz venue/league/season
- Fixtures and results are scraped automatically from Spawtz — no manual entry
- Members record post-game stats (tries and assists) for each player
- A leaderboard ranks players by points within a season (tries × 2 + assists × 1)
- Players can optionally link their account to their roster entry

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
