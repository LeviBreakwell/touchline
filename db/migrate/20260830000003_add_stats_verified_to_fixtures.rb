class AddStatsVerifiedToFixtures < ActiveRecord::Migration[8.0]
  def up
    add_column :fixtures, :stats_verified, :boolean, default: false, null: false
    add_index  :fixtures, :stats_verified

    # A fixture starts out verified when TRL has already published a score and
    # the stats sitting against it fit inside that score. Anything entered
    # ahead of the result — or over it — stays unverified until someone fixes
    # the sheet.
    execute <<~SQL
      UPDATE fixtures SET stats_verified = TRUE
      WHERE our_score IS NOT NULL
        AND COALESCE((SELECT SUM(tries)   FROM game_stats WHERE fixture_id = fixtures.id), 0) <= our_score
        AND COALESCE((SELECT SUM(assists) FROM game_stats WHERE fixture_id = fixtures.id), 0) <= our_score
    SQL
  end

  def down
    remove_column :fixtures, :stats_verified
  end
end
