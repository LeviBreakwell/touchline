class Player < ApplicationRecord
  belongs_to :team
  belongs_to :user, optional: true
  has_many :game_stats, dependent: :destroy

  validates :name, presence: true

  def season_tries(season)
    game_stats.joins(:fixture).where(fixtures: { season_id: season.id }).sum(:tries)
  end

  def season_assists(season)
    game_stats.joins(:fixture).where(fixtures: { season_id: season.id }).sum(:assists)
  end

  def season_points(season)
    (season_tries(season) * 2) + season_assists(season)
  end

  def season_games(season)
    game_stats.joins(:fixture).where(fixtures: { season_id: season.id }).count
  end

  def total_tries   = game_stats.sum(:tries)
  def total_assists = game_stats.sum(:assists)
  def total_points  = (total_tries * 2) + total_assists
  def total_games   = game_stats.count
end
