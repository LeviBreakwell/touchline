class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_address, :string, null: false, default: ""
    add_column :users, :password_digest, :string, null: false, default: ""
    remove_column :users, :email, :string
    add_index :users, :email_address, unique: true
  end
end
