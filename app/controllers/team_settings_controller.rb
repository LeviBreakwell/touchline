# One screen for everything an admin does to a Team.
class TeamSettingsController < ApplicationController
  before_action :set_team
  before_action -> { require_team_admin!(@team) }

  def show
    remember_team(@team)
    @settings = TeamSettings.new(@team)
    @player = Player.new
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
