# Which Team the tabs are pointing at.
#
# A Team is global context rather than something you carry through the
# navigation: the three tabs stay on whichever Team you were last looking at,
# and the Team tab's own header is where that changes. Addressing a Team
# directly still works and is what a shared link needs — visiting one is also
# what makes it the Team you were last looking at.
module TeamContext
  extend ActiveSupport::Concern

  included do
    helper_method :nav_team, :nav_season, :nav_teams, :current_tab
  end

  # Which of the three tabs is lit. Nil on a screen that is none of them.
  def current_tab = nil

  private

  def remember_team(team)
    session[:team_id] = team&.id
  end

  def nav_teams
    Current.user&.accepted_teams&.order(:name) || Team.none
  end

  def nav_team
    return @nav_team if defined?(@nav_team)

    @nav_team = @team || nav_teams.find_by(id: session[:team_id]) || nav_teams.first
  end

  def nav_season
    return @nav_season if defined?(@nav_season)

    @nav_season = @season || nav_team&.seasons&.by_recency&.first
  end
end
