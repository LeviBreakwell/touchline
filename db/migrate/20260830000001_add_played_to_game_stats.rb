class AddPlayedToGameStats < ActiveRecord::Migration[8.0]
  def up
    add_column :game_stats, :played, :boolean, default: true, null: false

    # Existing rows were created for every player on the roster whenever stats
    # were saved, so a 0/0 row carries no evidence the player took the field.
    # Treat only rows with a recorded try or assist as an appearance.
    execute "UPDATE game_stats SET played = (tries > 0 OR assists > 0)"
  end

  def down
    remove_column :game_stats, :played
  end
end
