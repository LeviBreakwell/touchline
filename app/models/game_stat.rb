class GameStat < ApplicationRecord
  belongs_to :fixture
  belongs_to :player

  scope :played, -> { where(played: true) }
  scope :verified, -> { joins(:fixture).merge(Fixture.verified) }

  validates :player_id, uniqueness: { scope: :fixture_id }
  validates :tries, :assists, numericality: { greater_than_or_equal_to: 0 }
  validate :within_official_result

  before_validation :count_scorers_as_played
  after_commit :refresh_fixture_verification

  def points
    (tries * 2) + assists
  end

  private

  # Recording a try or an assist is itself proof of an appearance, so the
  # played flag can never contradict the stats alongside it.
  def count_scorers_as_played
    self.played = true if tries.to_i.positive? || assists.to_i.positive?
  end

  # Nobody can put the roster past the score TRL published for the game. Until
  # TRL publishes there is no ceiling, so early entry goes through untouched
  # and the fixture simply stays unverified.
  def within_official_result
    cap = fixture&.official_tries
    return if cap.nil?

    if siblings_sum(:tries) + tries.to_i > cap
      errors.add(:tries, "would put the team past TRL's #{cap} for this game")
    end

    if siblings_sum(:assists) + assists.to_i > cap
      errors.add(:assists, "would put the team past TRL's #{cap} tries for this game")
    end
  end

  def siblings_sum(field)
    scope = fixture.game_stats
    scope = scope.where.not(id: id) if persisted?
    scope.sum(field)
  end

  # A Fixture on its way out has nothing left to verify — this fires for
  # destroys too, including the cascade from a Season or Team going away.
  def refresh_fixture_verification
    return if fixture.nil? || fixture.destroyed?
    fixture.refresh_stats_verification!
  end
end
