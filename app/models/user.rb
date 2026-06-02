class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :players, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true

  def admin_of?(team)
    team_memberships.admin.accepted.exists?(team: team)
  end

  def member_of?(team)
    team_memberships.accepted.exists?(team: team)
  end
end
