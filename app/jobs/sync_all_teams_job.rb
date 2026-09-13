class SyncAllTeamsJob < ApplicationJob
  queue_as :default

  def perform
    Team.where.not(spawtz_team_id: [ nil, "" ]).find_each do |team|
      SyncFixturesJob.perform_later(team.id)
    end
  end
end
