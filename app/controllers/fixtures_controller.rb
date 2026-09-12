class FixturesController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :set_team_and_season

  # The match ladder takes over the screen: entering a stat and watching the
  # standing move are the same act, and the ladder wants every pixel.
  def show
    @fixture = @season.fixtures.find(params[:id])
    remember_team(@team)
    @ladder = MatchLadder.new(@fixture, @team)
    @editable = Current.user&.member_of?(@team)
  end

  private

  def set_team_and_season
    @team = Team.find(params[:team_id])
    @season = @team.seasons.find(params[:season_id])
  end
end
