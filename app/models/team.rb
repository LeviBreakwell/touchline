class Team < ApplicationRecord
  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships
  has_many :players, dependent: :destroy
  has_many :seasons, dependent: :destroy
  has_many :fixtures, through: :seasons

  before_create :generate_invite_token

  validates :name, presence: true
  validates :location, presence: true

  def admins
    users.merge(TeamMembership.admin)
  end

  private

  def generate_invite_token
    self.invite_token ||= SecureRandom.urlsafe_base64(8)
  end
end
