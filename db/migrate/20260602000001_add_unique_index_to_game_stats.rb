class AddUniqueIndexToGameStats < ActiveRecord::Migration[8.0]
  def change
    add_index :game_stats, [ :fixture_id, :player_id ], unique: true
  end
end
