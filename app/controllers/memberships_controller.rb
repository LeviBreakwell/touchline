class MembershipsController < ApplicationController
  before_action :set_team

  def create
    existing = @team.team_memberships.find_by(user: Current.user)
    if existing
      redirect_to @team, alert: "You have already requested to join this team."
    else
      membership = @team.team_memberships.create!(user: Current.user, role: :member, status: :pending)
      TeamMailer.join_request(membership).deliver_later
      redirect_to @team, notice: "Join request sent. The admin will review it."
    end
  end

  def destroy
    @team.team_memberships.find_by(user: Current.user)&.destroy
    redirect_to @team, notice: "You have left the team."
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
