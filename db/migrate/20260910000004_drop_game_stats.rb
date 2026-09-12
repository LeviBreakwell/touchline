# The counters are rows now, and the table they came from has to go with them:
# its foreign key outlives the association, so a Fixture carrying old
# game_stats can no longer be destroyed at all — which is how the scraper
# prunes a withdrawn fixture, and how a Season is rebuilt.
#
# This is the point the migration in #18 called one way. Everything recoverable
# was recovered by MigrateGameStatsToCountedRows; what is left behind is the
# played flag on rows that never scored, which a 2026 backfill had guessed at
# and which the spec deliberately does not carry forward.
class DropGameStats < ActiveRecord::Migration[8.0]
  def up
    drop_table :game_stats
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "game_stats was replaced by touchdowns, plays and appearances — restore from a backup."
  end
end
