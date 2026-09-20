# One team's row in a division's ladder, as TRL publishes it — captured
# alongside the fixtures on each sync and replaced wholesale every time, so a
# mid-season position is only ever this season's latest one. See
# SpawtzScraper#record_standings.
class Standing < ApplicationRecord
  belongs_to :season

  scope :by_position, -> { order(:position) }

  def us?(team) = spawtz_team_id == team.spawtz_team_id
end
