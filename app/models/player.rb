class Player < ApplicationRecord
  belongs_to :team
  belongs_to :user, optional: true
  has_many :game_stats, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase.presence }

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { scope: :team_id, case_sensitive: false },
                    allow_nil: true

  # An admin can put an email on a roster entry before that person has an
  # account. When they sign in, the entry is waiting for them.
  def self.claim_by_email(user)
    where(user_id: nil, email: user.email_address).includes(:team).filter_map do |player|
      player.update!(user: user)
      player.team.team_memberships.find_or_create_by!(user: user) do |membership|
        membership.role = :member
        membership.status = :accepted
      end
      player
    end
  end

  def career_stats = StatLine.for(game_stats)

  # The part of career_stats TRL has not confirmed yet — already counted, but
  # not yet squared against a published result.
  def unconfirmed_stats = StatLine.unconfirmed(game_stats)

  def season_stats(season)
    StatLine.for(game_stats.where(fixtures: { season_id: season.id }))
  end

  # Seasons this Player actually appeared in, newest first.
  def seasons_played
    team.seasons
        .where(id: game_stats.played.joins(:fixture).select("fixtures.season_id"))
        .order(created_at: :desc)
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
