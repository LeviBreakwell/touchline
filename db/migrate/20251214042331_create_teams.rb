class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :location
      t.integer :subscription_status

      t.timestamps
    end
  end
end
