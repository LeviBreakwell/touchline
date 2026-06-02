class CreateStats < ActiveRecord::Migration[8.0]
  def change
    create_table :stats do |t|
      t.integer :stat_type
      t.integer :value, default: 1
      t.integer :game_time
      t.references :player, null: false, foreign_key: true
      t.references :fixture, null: false, foreign_key: true

      t.timestamps
    end
  end
end
