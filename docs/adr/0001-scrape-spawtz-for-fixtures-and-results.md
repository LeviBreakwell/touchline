# Scrape Spawtz for fixtures and results

TRL Australia publishes all fixtures and results on a Spawtz-hosted platform but provides no official API. We scrape Spawtz using stored venue/league/season IDs on each Team: once when a Team first links to Spawtz (to load the fixture schedule), and again 1 hour after each Fixture's kick-off time (with nightly retries until a result appears). Members never manually enter the opponent score or game result — Spawtz is the single source of truth for those fields.

## Considered options

**Manual fixture entry by team admins** — rejected because the schedule already exists on Spawtz and duplicating it by hand is error-prone and tedious.

**Official TRL Australia API** — no API exists.

## Consequences

The scraper is coupled to Spawtz's HTML structure. If TRL Australia changes their platform or Spawtz changes its markup, the sync will break silently until someone notices missing results. The Spawtz IDs (`spawtz_venue_id`, `spawtz_league_id`, `spawtz_season_id`) must be captured accurately at Team setup time — there is no recovery path if they are wrong without re-linking the Team.
