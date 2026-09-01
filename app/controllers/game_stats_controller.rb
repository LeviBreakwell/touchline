class GameStatsController < ApplicationController
  before_action :set_context
  before_action -> { require_team_member!(@team) }

  def bulk
    sheet = StatSheet.new(@fixture, bulk_stat_params)

    if sheet.save
      redirect_to team_season_fixture_path(@team, @season, @fixture), notice: notice_for(@fixture)
    else
      render_sheet(sheet)
    end
  end

  private

  def set_context
    @team = Team.find(params[:team_id])
    @season = @team.seasons.find(params[:season_id])
    @fixture = @season.fixtures.find(params[:fixture_id])
  end

  def bulk_stat_params
    (params[:game_stats] || {}).values.map do |sp|
      sp.permit(:player_id, :tries, :assists, :played)
    end
  end

  def notice_for(fixture)
    if fixture.stats_verified?
      "Stats saved."
    else
      "Stats saved and counted. TRL hasn't published this result yet to check them against."
    end
  end

  # A rejected sheet is handed straight back with the Member's own numbers in
  # it, so nothing they typed is lost to the error.
  def render_sheet(sheet)
    @players = @team.players.order(:name)
    @game_stats = @fixture.game_stats.index_by(&:player_id).merge(sheet.stats)
    @is_member = true
    flash.now[:alert] = sheet.error
    render "fixtures/show", status: :unprocessable_entity
  end
end
