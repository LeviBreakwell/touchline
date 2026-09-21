class Fixture < ApplicationRecord
  belongs_to :season
  has_many :touchdowns,  dependent: :destroy
  has_many :plays,       dependent: :destroy
  has_many :appearances, dependent: :destroy
  has_one :team, through: :season

  validates :opponent_name, :date, presence: true

  # Only a verified fixture feeds the leaderboard and the stat lines built on
  # top of it. See #refresh_stats_verification!.
  scope :verified, -> { where(stats_verified: true) }

  # Nothing entered against it at all — not a stat, not even who took the field.
  scope :without_stats, -> { where.missing(:appearances, :touchdowns, :plays) }

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

  # Spawtz labels a finals row with the round it belongs to — "Semi Final 1",
  # "Grand Final" — and labels nothing else.
  def final? = finals_label.present?

  # The two rounds where a loss ends the season: whatever "Preliminary Final"
  # is called that week, and the Grand Final itself. Worth more XP than a
  # semi, which is why this is its own check rather than reusing #final?.
  MAJOR_FINAL_LABEL = /preliminary final|grand final/i
  scope :major_final, -> { where("finals_label ~* ?", MAJOR_FINAL_LABEL.source) }
  def major_final? = finals_label.to_s.match?(MAJOR_FINAL_LABEL)

  # Everyone defaults to played, and that default becomes rows the moment
  # somebody first writes to this Fixture — entering anything at all is when
  # the squad gets asserted. Idempotent: once a single Appearance exists those
  # rows are the record, and the sideline toggle is what changes them.
  def open_sideline!
    return if appearances.exists?

    now = Time.current
    rows = team.players.pluck(:id).map do |player_id|
      { fixture_id: id, player_id: player_id, created_at: now, updated_at: now }
    end
    Appearance.insert_all(rows) if rows.any?
  end

  # Whether anybody has recorded anything here yet. Read off the association so
  # a preloaded fixture answers without a query.
  def stats_entered? = appearances.any? || touchdowns.any? || plays.any?

  # TRL scores a touchdown as one point, so the scoreline Spawtz publishes is
  # exactly how many tries the team is credited with. That number is the
  # ceiling on what Members can enter: they cannot claim a try TRL has no
  # record of, and cannot be assisted for a try that was never scored.
  # Nil until the result is published, which is what lets stats be entered
  # early — see #stats_status.
  def official_tries = our_score

  # Only rows with a scorer are the Team's tries: an imported assist carries a
  # null scorer precisely so that it matches nobody's try count, here included.
  def entered_tries   = touchdowns.scored.count
  def entered_assists = touchdowns.assisted.count

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
  # Touchdown is written, or the scraper lands a score. This is the one place
  # the record is actually measured against TRL — and since #17 the only one:
  # going over is a flag on the Fixture, never a refusal to write.
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
