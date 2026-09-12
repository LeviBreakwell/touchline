# This Player took the field in this Fixture.
#
# The row's existence is the fact — there is no played column, because the
# sideline toggle inserts and deletes the row. It cannot be derived from
# Touchdowns and Plays either: a Player who took the field and did nothing
# leaves no other row anywhere, and that game still counts against their
# averages like any other.
class Appearance < ApplicationRecord
  belongs_to :fixture
  belongs_to :player

  validates :player_id, uniqueness: { scope: :fixture_id }
end
