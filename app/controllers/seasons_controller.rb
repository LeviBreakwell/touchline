class SeasonsController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :set_team

  def show
    @season = @team.seasons.find(params[:id])
    # game_stats is preloaded for trl_status_badge, which needs to know whether
    # a sheet exists at all before it says anything about it; the players ride
    # along for the scorer tallies on each card.
    @fixtures = @season.fixtures.includes(game_stats: :player).order(date: :desc)

    # Most recent played fixture that has no game_stats entered yet
    @next_to_record = @season.fixtures
      .where.not(our_score: nil).where.not(opponent_score: nil)
      .left_joins(:game_stats)
      .where(game_stats: { id: nil })
      .order(date: :desc)
      .first

    @leaderboard = Leaderboard.for(@team, season: @season)
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
