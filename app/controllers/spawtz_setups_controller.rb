class SpawtzSetupsController < ApplicationController
  before_action :set_team
  before_action -> { require_team_admin!(@team) }

  def new
  end

  def create
    if @team.update(spawtz_params)
      SyncFixturesJob.perform_later(@team.id)
      redirect_to @team, notice: "Linked to TRL Australia. Fixtures are syncing now."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def spawtz_params
    params.require(:team).permit(:spawtz_venue_id, :spawtz_league_id, :spawtz_season_id)
  end
end
