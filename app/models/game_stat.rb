class GameStat < ApplicationRecord
  belongs_to :fixture
  belongs_to :player

  validates :player_id, uniqueness: { scope: :fixture_id }
  validates :tries, :assists, numericality: { greater_than_or_equal_to: 0 }

  def points
    (tries * 2) + assists
  end
end
