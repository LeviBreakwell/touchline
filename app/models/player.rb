class Player < ApplicationRecord
  belongs_to :team
  belongs_to :user, optional: true
  has_many :appearances, dependent: :destroy
  has_many :plays,       dependent: :destroy

  # A try goes with the Player who scored it. An assist is a column on somebody
  # else's try, so removing the assister leaves the try standing.
  has_many :touchdowns_scored,   class_name: "Touchdown", foreign_key: :scorer_player_id,   dependent: :destroy
  has_many :touchdowns_assisted, class_name: "Touchdown", foreign_key: :assister_player_id, dependent: :nullify

  normalizes :email, with: ->(e) { e.strip.downcase.presence }

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { scope: :team_id, case_sensitive: false },
                    allow_nil: true

  # An admin can put an email on a roster entry before that person has an
  # account. When they sign in, the entry is waiting for them.
  def self.claim_by_email(user)
    claimed = where(user_id: nil, email: user.email_address).includes(:team).filter_map do |player|
      player.update!(user: user)
      player.team.team_memberships.find_or_create_by!(user: user) do |membership|
        membership.role = :member
        membership.status = :accepted
      end
      player
    end

    # Whatever that name has already done is theirs the moment they sign in.
    AccoladeLedger.settle(user) if claimed.any?
    claimed
  end

  def career_stats = StatLine.for(self)

  # The part of career_stats TRL has not confirmed yet — already counted, but
  # not yet squared against a published result.
  def unconfirmed_stats = StatLine.unconfirmed(self)

  def season_stats(season)
    StatLine.for(self, fixtures: Fixture.where(season_id: season.id))
  end

  # Seasons this Player actually appeared in, newest first.
  def seasons_played
    team.seasons
        .where(id: appearances.joins(:fixture).select("fixtures.season_id"))
        .by_recency
  end

  def season_tries(season)   = season_stats(season).tries
  def season_assists(season) = season_stats(season).assists
  def season_points(season)  = season_stats(season).points
  def season_games(season)   = season_stats(season).games

  def total_tries   = career_stats.tries
  def total_assists = career_stats.assists
  def total_points  = career_stats.points
  def total_games   = career_stats.games
end
