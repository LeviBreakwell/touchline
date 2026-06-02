class CreateExternalLeagues < ActiveRecord::Migration[8.0]
  def change
    create_table :external_leagues do |t|
      t.string :name
      t.string :spawtz_venue_id
      t.string :spawtz_league_id
      t.string :spawtz_season_id
      t.references :team, null: false, foreign_key: true

      t.timestamps
    end
  end
end
