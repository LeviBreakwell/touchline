class ProfilesController < ApplicationController
  def show
    @user = Current.user
    @players = @user.players.includes(:team).order("teams.name")
    @career = StatLine.for(GameStat.where(player_id: @players.map(&:id)))
  end
end
