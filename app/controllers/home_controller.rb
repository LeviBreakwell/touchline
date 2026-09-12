class HomeController < ApplicationController
  allow_unauthenticated_access only: [:index]

  def index
    return unless Current.user

    @my_teams = Current.user.teams.includes(:seasons).order(:name)

    season_ids = @my_teams.flat_map { |t| t.seasons.map(&:id) }
    @next_to_record_by_season = if season_ids.any?
      Fixture
        .where(season_id: season_ids)
        .where.not(our_score: nil)
        .without_stats
        .order(date: :desc)
        .group_by(&:season_id)
        .transform_values(&:first)
    else
      {}
    end
  end
end
