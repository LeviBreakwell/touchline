class Season < ApplicationRecord
  belongs_to :team
  has_many :fixtures, dependent: :destroy

  validates :name, presence: true
end
