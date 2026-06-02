class TeamMailer < ApplicationMailer
  def join_request(membership)
    @membership = membership
    @user = membership.user
    @team = membership.team
    @admins = @team.admins

    mail(
      to: @admins.map(&:email_address),
      subject: "#{@user.name} wants to join #{@team.name}"
    )
  end
end
