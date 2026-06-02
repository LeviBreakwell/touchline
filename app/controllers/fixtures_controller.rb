class FixturesController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :set_team_and_season

  def show
    @fixture = @season.fixtures.find(params[:id])
    @players = @team.players.order(:name)
    @game_stats = @fixture.game_stats.index_by(&:player_id)
    @is_member = Current.user&.member_of?(@team)

  end

  private

  def set_team_and_season
    @team = Team.find(params[:team_id])
    @season = @team.seasons.find(params[:season_id])
  end
end
