class AddSpawtzIdsToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :spawtz_venue_id, :string
    add_column :teams, :spawtz_league_id, :string
    add_column :teams, :spawtz_season_id, :string
  end
end
