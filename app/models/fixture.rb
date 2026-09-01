class Fixture < ApplicationRecord
  belongs_to :season
  has_many :game_stats, dependent: :destroy
  has_one :team, through: :season

  validates :opponent_name, :date, presence: true

  # Only a verified fixture feeds the leaderboard and the stat lines built on
  # top of it. See #refresh_stats_verification!.
  scope :verified, -> { where(stats_verified: true) }

  def result
    return nil unless played?
    if our_score > opponent_score then "win"
    elsif our_score < opponent_score then "loss"
    else "draw"
    end
  end

  def played?
    opponent_score.present? && our_score.present?
  end

  # TRL scores a touchdown as one point, so the scoreline Spawtz publishes is
  # exactly how many tries the team is credited with. That number is the
  # ceiling on what Members can enter: they cannot claim a try TRL has no
  # record of, and cannot be assisted for a try that was never scored.
  # Nil until the result is published, which is what lets stats be entered
  # early — see #stats_status.
  def official_tries = our_score

  def entered_tries   = game_stats.sum(:tries)
  def entered_assists = game_stats.sum(:assists)

  # :verified        — TRL has published the result and the sheet fits inside it
  # :awaiting_result — entered early, TRL has not published yet
  # :over_official   — TRL published a lower score than the sheet already claims
  #
  # Read from the stored flag rather than re-summing, so the badge on a list of
  # fixtures costs nothing and can never disagree with the leaderboard.
  def stats_status
    return :awaiting_result if official_tries.nil?
    stats_verified? ? :verified : :over_official
  end

  # The stored flag is what the leaderboard and stats_status read, so it has to
  # be brought back in line whenever either side of the comparison moves: a
  # GameStat is written, or the scraper lands a score. This is the one place
  # the sheet is actually measured against TRL.
  def refresh_stats_verification!
    verified = official_tries.present? && fits_official?
    update_column(:stats_verified, verified) unless stats_verified == verified
    verified
  end

  private

  def fits_official?
    entered_tries <= official_tries && entered_assists <= official_tries
  end
end
