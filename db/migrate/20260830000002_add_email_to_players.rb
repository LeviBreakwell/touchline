class AddEmailToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :email, :string
    add_index :players, :email
  end
end
