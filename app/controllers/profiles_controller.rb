class ProfilesController < ApplicationController
  def current_tab = :profile

  def show
    @user = Current.user
    @progression = Progression.new(@user)
    @players = @user.players.includes(:team).order("teams.name")
    @career = StatLine.for(@players.map(&:id))
  end
end
