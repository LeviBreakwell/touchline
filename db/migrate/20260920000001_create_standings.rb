# The division ladder as TRL publishes it — every team in it, not just ours.
# ladder_position/ladder_size (see 20260912000001) already say where we
# finished; this is the table that number was read off, kept in full so the
# Season screen can show it rather than just our own row.
class CreateStandings < ActiveRecord::Migration[8.0]
  def change
    create_table :standings do |t|
      t.references :season, null: false, foreign_key: true
      t.string  :spawtz_team_id, null: false
      t.string  :team_name, null: false
      t.integer :position, null: false
      t.integer :played
      t.integer :won
      t.integer :lost
      t.integer :drawn
      t.integer :forfeits_for
      t.integer :forfeits_against
      t.integer :points_for
      t.integer :points_against
      t.integer :difference
      t.integer :bonus_points
      t.integer :points

      t.timestamps
    end

    add_index :standings, [ :season_id, :spawtz_team_id ], unique: true
  end
end
