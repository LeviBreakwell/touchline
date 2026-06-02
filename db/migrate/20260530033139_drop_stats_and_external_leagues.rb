class DropStatsAndExternalLeagues < ActiveRecord::Migration[8.0]
  def change
    drop_table :stats
    drop_table :external_leagues
  end
end
