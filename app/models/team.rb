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

  # Whether this Team has been through the TRL browser and picked a Spawtz
  # team to sync against. Gates anything scraped off TRL, the ladder tab
  # included — there is nothing to show, or scrape, for a Team that never
  # linked one.
  def linked_to_spawtz? = spawtz_team_id.present?

  private

  def generate_invite_token
    self.invite_token ||= SecureRandom.urlsafe_base64(8)
  end
end
