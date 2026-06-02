class AddSeasonToFixtures < ActiveRecord::Migration[8.0]
  def up
    add_reference :fixtures, :season, null: true, foreign_key: true
    execute "DELETE FROM fixtures"
    change_column_null :fixtures, :season_id, false
    remove_reference :fixtures, :team, foreign_key: true
  end

  def down
    add_reference :fixtures, :team, null: true, foreign_key: true
    remove_reference :fixtures, :season, foreign_key: true
  end
end
