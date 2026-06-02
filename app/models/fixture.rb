class Fixture < ApplicationRecord
  belongs_to :season
  has_many :game_stats, dependent: :destroy
  has_one :team, through: :season

  validates :opponent_name, :date, presence: true

  def result
    return nil unless played?
    if our_score > opponent_score then "win"
    elsif our_score < opponent_score then "loss"
    else "draw"
    end
  end

  def played?
    opponent_score.present? && our_score.present?
  end

end
