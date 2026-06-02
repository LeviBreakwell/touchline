class AddSpawtzIdsToSeasonsAndFixtures < ActiveRecord::Migration[8.0]
  def change
    add_column :seasons, :spawtz_season_id, :string
    add_column :fixtures, :spawtz_fixture_id, :string
    add_column :fixtures, :our_score, :integer
    add_index :fixtures, :spawtz_fixture_id
  end
end
