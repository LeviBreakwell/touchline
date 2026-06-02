class MergePlayerNameColumns < ActiveRecord::Migration[8.0]
  def up
    add_column :players, :name, :string
    execute "UPDATE players SET name = TRIM(first_name || ' ' || last_name)"
    change_column_null :players, :name, false
    remove_column :players, :first_name
    remove_column :players, :last_name
  end

  def down
    add_column :players, :first_name, :string
    add_column :players, :last_name, :string
    # SQLite: split on first space
    execute "UPDATE players SET first_name = SUBSTR(name, 1, INSTR(name, ' ') - 1), last_name = TRIM(SUBSTR(name, INSTR(name, ' ')))"
    remove_column :players, :name
  end
end
