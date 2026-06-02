class AddTrlLocationSlugToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :trl_location_slug, :string
  end
end
