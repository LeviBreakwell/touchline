class Season < ApplicationRecord
  belongs_to :team
  has_many :fixtures, dependent: :destroy

  validates :name, presence: true

  # Newest first by when the season was actually played, which is the last
  # fixture in it. Ordering on created_at answers a different question — when
  # the app first synced the season — and gets it wrong the moment Spawtz
  # backfills an old one, which sorts straight to the top of every dropdown.
  # A season with no fixtures yet has nothing to be played, so it sorts last.
  #
  # A subquery rather than a join and a GROUP BY: grouping would make `count`
  # and `many?` answer with a hash of per-season counts, and this scope is read
  # by dropdowns that ask exactly those questions.
  LAST_FIXTURE = "(SELECT MAX(fixtures.date) FROM fixtures WHERE fixtures.season_id = seasons.id)".freeze

  scope :by_recency, -> { order(Arel.sql("#{LAST_FIXTURE} DESC NULLS LAST"), created_at: :desc) }

  # Where the Team finished in its division, once TRL stops moving it.
  def won_the_ladder? = ladder_position == 1
end
