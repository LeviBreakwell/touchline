class CleanTeamAndPlayerColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :teams, :subscription_status, :integer
    remove_column :players, :jersey_number, :integer
  end
end
