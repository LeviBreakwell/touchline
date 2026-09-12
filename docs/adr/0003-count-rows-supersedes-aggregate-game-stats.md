# Count Touchdowns and Plays as rows — superseding ADR 0002

Supersedes [ADR 0002](0002-aggregate-game-stats-not-individual-stat-records.md).

`GameStat` was two concepts welded together: an **appearance record** and a **tally**. Only the tally is replaced. A try is now one `Touchdown` row carrying its scorer and — as a nullable column, not a sibling row — the Player who assisted it. A stat that is not a try is one `Play` row per occurrence. What is left of `GameStat` becomes `Appearance`, whose existence is the whole of what it says.

ADR 0002's two objections still stand, and were **answered rather than defied**.

**`game_time` stays gone.** Rows are ordered by `created_at` and nothing else. Nobody knows the match clock on the drive home, which is when a sheet is entered, and the reason 0002 deleted a whole model to be rid of that field has not changed.

**The GROUP BY stays confined.** `StatLine` and `Leaderboard` already aggregated per appearance in Ruby, and they still do. No new query in the app groups over stat rows to answer a question that used to be a column read.

What changed is what the columns could not express. A pair of integers cannot say **who passed it**, so an assist sat beside a try as a second number that happened to add up — and "assists cannot outnumber tries" had to be defended by validation in three places. As a nullable column on the try it produced, that rule holds **by shape**, and there is nothing left to validate. The same move gives a Play somewhere to live: a row per occurrence, so undoing one is deleting it, and five bomb catches in a game need no counter anywhere.

## Considered options

**Keep the counters and add columns per stat** — one more integer for bomb catches, another for dropped bombs. Rejected: it re-buys the assist problem for every new stat, and still cannot record who passed to whom.

**A single stat-event table with a type enum** — the shape ADR 0002 deleted. Rejected again for the same reason: a try and an assist are not two events, they are one event and its passer.

## Consequences

`scorer_player_id` is nullable in exactly one case: an assist migrated from the old counters, whose try was never recorded and cannot be recovered. A null scorer is therefore its own marker for imported history. It costs one filter — `Fixture#entered_tries` counts only rows with a scorer — and it means **"assists ≤ tries" is structural only for rows entered since the change**. For imported history it holds in fact, because the old ceiling enforced it.

Rows where `played` was false are **not** migrated. That column was backfilled by a 2026 migration reading `played = (tries > 0 OR assists > 0)`, so it asserted absences nobody observed. The app now has no record either way, which is the truth, and anyone who was there can open the fixture and tick the sideline.

`game_stats` is dropped in the same series of migrations. Leaving it standing was the safer-looking option and is the wrong one: its foreign key outlives the association, so a Fixture carrying old rows could no longer be destroyed at all — which is how the scraper prunes a withdrawn fixture and how a Season is rebuilt.
