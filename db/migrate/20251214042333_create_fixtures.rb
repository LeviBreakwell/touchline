class CreateFixtures < ActiveRecord::Migration[8.0]
  def change
    create_table :fixtures do |t|
      t.string :opponent_name
      t.datetime :date
      t.boolean :is_played, default: false
      t.references :team, null: false, foreign_key: true

      t.timestamps
    end
  end
end
