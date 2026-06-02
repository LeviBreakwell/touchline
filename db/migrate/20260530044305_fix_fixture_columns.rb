class FixFixtureColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :fixtures, :opponent_score, :integer unless column_exists?(:fixtures, :opponent_score)
    remove_column :fixtures, :is_played, :boolean if column_exists?(:fixtures, :is_played)
  end
end
