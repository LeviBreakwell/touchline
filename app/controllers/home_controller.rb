class HomeController < ApplicationController
  allow_unauthenticated_access only: [:index]

  def index
    @my_teams = Current.user ? Current.user.teams.order(:name) : []
  end
end
