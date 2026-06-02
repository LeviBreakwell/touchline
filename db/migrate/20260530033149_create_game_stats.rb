class CreateGameStats < ActiveRecord::Migration[8.0]
  def change
    create_table :game_stats do |t|
      t.references :fixture, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :tries, null: false, default: 0
      t.integer :assists, null: false, default: 0

      t.timestamps
    end
  end
end
