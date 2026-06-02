class SyncFixturesJob < ApplicationJob
  queue_as :default

  def perform(team_id)
    team = Team.find(team_id)
    SpawtzScraper.new(team).sync_fixtures
  end
end
