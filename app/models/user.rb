class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :players, dependent: :nullify
  has_many :accolade_awards, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP },
                            uniqueness: { case_sensitive: false }

  # The Teams you are actually in. A pending request is not yet one of them,
  # which is what the tabs and the Team switcher mean by "your teams".
  def accepted_teams = teams.merge(TeamMembership.accepted)

  def admin_of?(team)
    team_memberships.admin.accepted.exists?(team: team)
  end

  def member_of?(team)
    team_memberships.accepted.exists?(team: team)
  end
end
