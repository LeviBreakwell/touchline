# One accolade, earned once. Never revoked: a corrected sheet must not silently
# take back something somebody was shown yesterday.
class AccoladeAward < ApplicationRecord
  belongs_to :user

  validates :key, presence: true
  validates :key, uniqueness: { scope: [ :user_id, :subject ] }

  def accolade = Accolade[key]
end
