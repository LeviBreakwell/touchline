class GameStatsController < ApplicationController
  before_action :set_context
  before_action -> { require_team_member!(@team) }

  def bulk
    ActiveRecord::Base.transaction do
      bulk_stat_params.each do |sp|
        stat = @fixture.game_stats.find_or_initialize_by(player_id: sp[:player_id])
        stat.update!(tries: sp[:tries].to_i, assists: sp[:assists].to_i)
      end
    end
    redirect_to team_season_fixture_path(@team, @season, @fixture), notice: "Stats saved."
  end

  def create
    @game_stat = @fixture.game_stats.find_or_initialize_by(player_id: game_stat_params[:player_id])
    @game_stat.assign_attributes(game_stat_params)
    @game_stat.save!
    redirect_to team_season_fixture_path(@team, @season, @fixture), notice: "Stats saved."
  end

  def update
    @game_stat = @fixture.game_stats.find(params[:id])
    @game_stat.update!(game_stat_params)
    redirect_to team_season_fixture_path(@team, @season, @fixture), notice: "Stats updated."
  end

  private

  def set_context
    @team = Team.find(params[:team_id])
    @season = @team.seasons.find(params[:season_id])
    @fixture = @season.fixtures.find(params[:fixture_id])
  end

  def bulk_stat_params
    (params[:game_stats] || {}).values.map do |sp|
      sp.permit(:player_id, :tries, :assists)
    end
  end

  def game_stat_params
    params.require(:game_stat).permit(:player_id, :tries, :assists)
  end
end
