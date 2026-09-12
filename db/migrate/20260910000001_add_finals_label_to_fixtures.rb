class AddFinalsLabelToFixtures < ActiveRecord::Migration[8.0]
  def change
    add_column :fixtures, :finals_label, :string
  end
end
