# Aggregate GameStat columns instead of individual stat records

> **Superseded by [ADR 0003](0003-count-rows-supersedes-aggregate-game-stats.md).** Both objections below still stand and were answered rather than defied: `game_time` is still gone, and the GROUP BY is still confined to `StatLine` and `Leaderboard`, which already aggregate per appearance in Ruby.

Stats are entered post-game as totals, not recorded live during a game. We use a single `GameStat` row per Player per Fixture with integer `tries` and `assists` columns rather than one row per scoring event. This keeps leaderboard queries simple aggregations and avoids carrying a `game_time` field that has no meaning in a post-game entry workflow.

## Considered options

**Individual stat records (one row per try/assist)** — already existed in the codebase as a `Stat` model with `stat_type` enum and `game_time`. Rejected because post-game entry makes `game_time` meaningless, and leaderboard queries become unnecessary GROUP BY complexity. Live scoring can be added later if there is demand.
