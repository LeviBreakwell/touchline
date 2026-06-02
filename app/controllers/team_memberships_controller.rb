class TeamMembershipsController < ApplicationController
  before_action :set_team
  before_action -> { require_team_admin!(@team) }

  def index
    @pending = @team.team_memberships.pending.includes(:user)
    @accepted = @team.team_memberships.accepted.includes(:user)
  end

  def update
    membership = @team.team_memberships.find(params[:id])

    if params[:status].present?
      case params[:status]
      when "accepted"
        membership.update!(status: :accepted)
        redirect_to team_memberships_path(@team), notice: "#{membership.user.name} approved."
      when "rejected"
        membership.destroy!
        redirect_to team_memberships_path(@team), notice: "Request removed."
      end
    elsif params[:role].present?
      membership.update!(role: params[:role])
      label = params[:role] == "admin" ? "an admin" : "a member"
      redirect_to team_memberships_path(@team), notice: "#{membership.user.name} is now #{label}."
    end
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
