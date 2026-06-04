class AddFixturesSyncedAtToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :fixtures_synced_at, :datetime
  end
end
