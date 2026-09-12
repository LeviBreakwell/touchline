# One TRL league holds more than one division — "Bardon Mondays" runs a Mixed
# and a Men's — and the app threw that away, passing DivisionId: 0 on every
# scrape. It is the Social league's grouping key (#27): ranking a Mixed player
# against a Men's player is the exact distortion that board exists to prevent.
#
# The ladder comes along with it, off the same page: where a Team finished is
# what "finish top of the ladder" reads, and there is nowhere else to get it.
class CaptureTheDivisionAndTheLadder < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :spawtz_division_id, :string
    add_column :teams, :division_name, :string
    add_index  :teams, :spawtz_division_id

    add_column :seasons, :ladder_position, :integer
    add_column :seasons, :ladder_size, :integer
  end
end
