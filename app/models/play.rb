# One stat by one Player in one Fixture that is not a try. A row per
# occurrence, so undoing one is deleting it.
#
# A Play is never measured against the official score: TRL publishes nothing to
# check one against, and a ceiling only ever bounds over-reporting. Nobody games
# a leaderboard by adding penalties to themselves — the real exposure is a Team
# quietly not recording its drops, which no ceiling can detect. See Fixture.
class Play < ApplicationRecord
  # A Play can be worth more than nothing or less than nothing, which is why
  # this is not called an infringement. Bomb catch exists so that the set does
  # not punish going up for the ball while paying nothing for catching it.
  POINTS = {
    bomb_catch:        1,
    dropped_bomb:      -1,
    opposition_assist: -2
  }.freeze

  belongs_to :fixture
  belongs_to :player

  enum :kind, POINTS.keys.index_with(&:to_s)

  scope :verified, -> { joins(:fixture).merge(Fixture.verified) }

  # Entering any stat is itself proof the Player took the field.
  after_create :record_appearance

  def points = POINTS.fetch(kind.to_sym)

  private

  def record_appearance
    Appearance.find_or_create_by!(fixture_id: fixture_id, player_id: player_id)
  end
end
