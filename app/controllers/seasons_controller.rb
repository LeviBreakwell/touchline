class SeasonsController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :set_team

  def show
    @season = @team.seasons.find(params[:id])
    @fixtures = @season.fixtures.order(date: :desc)

    # Most recent played fixture that has no game_stats entered yet
    @next_to_record = @season.fixtures
      .where.not(our_score: nil).where.not(opponent_score: nil)
      .left_joins(:game_stats)
      .where(game_stats: { id: nil })
      .order(date: :desc)
      .first

    stats_by_player = GameStat
      .joins(:fixture)
      .where(fixtures: { season_id: @season.id })
      .group(:player_id)
      .select("player_id, SUM(tries) AS season_tries, SUM(assists) AS season_assists, COUNT(*) AS season_games")
      .index_by(&:player_id)

    @leaderboard = @team.players
      .order(:name)
      .map { |p|
        s = stats_by_player[p.id]
        tries   = s&.season_tries.to_i
        assists = s&.season_assists.to_i
        { player: p, tries: tries, assists: assists, points: (tries * 2) + assists, games: s&.season_games.to_i }
      }
      .sort_by { |r| [-r[:points], -r[:tries], -r[:assists]] }
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
