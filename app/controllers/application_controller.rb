class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern

  private

  def require_team_member!(team)
    unless Current.user&.member_of?(team)
      redirect_to team_path(team), alert: "You must be an accepted team member to do that."
    end
  end

  def require_team_admin!(team)
    unless Current.user&.admin_of?(team)
      redirect_to team_path(team), alert: "Only team admins can do that."
    end
  end
end
