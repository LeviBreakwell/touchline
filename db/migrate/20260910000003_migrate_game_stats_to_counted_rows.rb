# One way (#18). GameStat's counters become rows, and everything the counters
# could not say is left unsaid rather than guessed at.
#
#   tries: 3            3 Touchdowns, scorer set, assister null
#   assists: 2          2 Touchdowns, assister set, SCORER NULL — the try each
#                       assist belonged to was never recorded and cannot be
#                       recovered, so a null scorer marks imported history
#   played: true        an Appearance
#   played: false       nothing at all
#
# The last line is deliberate. Those rows came from a backfill that read
# played = (tries > 0 OR assists > 0), a 2026 migration guessing at 2025 games,
# so they assert absences nobody observed. Dropping them leaves the app with no
# record either way, which is the truth — and anyone who was there can open the
# fixture and tick the sideline.
class MigrateGameStatsToCountedRows < ActiveRecord::Migration[8.0]
  def up
    # A player who scored also appeared: the Appearance is a separate fact, and
    # games played is counted off it alone.
    execute <<~SQL
      INSERT INTO appearances (fixture_id, player_id, created_at, updated_at)
      SELECT fixture_id, player_id, created_at, updated_at
      FROM game_stats
      WHERE played = TRUE
      ON CONFLICT (fixture_id, player_id) DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO touchdowns (fixture_id, scorer_player_id, assister_player_id, created_at, updated_at)
      SELECT gs.fixture_id, gs.player_id, NULL, gs.created_at, gs.updated_at
      FROM game_stats gs, generate_series(1, gs.tries)
      WHERE gs.tries > 0
    SQL

    execute <<~SQL
      INSERT INTO touchdowns (fixture_id, scorer_player_id, assister_player_id, created_at, updated_at)
      SELECT gs.fixture_id, NULL, gs.player_id, gs.created_at, gs.updated_at
      FROM game_stats gs, generate_series(1, gs.assists)
      WHERE gs.assists > 0
    SQL
  end

  # Only safe while game_stats is still standing, which is the whole reason it
  # has not been dropped yet.
  def down
    execute "DELETE FROM touchdowns"
    execute "DELETE FROM plays"
    execute "DELETE FROM appearances"
  end
end
