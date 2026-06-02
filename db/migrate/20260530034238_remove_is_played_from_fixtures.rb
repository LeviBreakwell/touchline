class RemoveIsPlayedFromFixtures < ActiveRecord::Migration[8.0]
  def change
    remove_column :fixtures, :is_played, :boolean
  end
end
