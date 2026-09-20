class SeasonsController < ApplicationController
  allow_unauthenticated_access only: %i[show ladder]
  before_action :set_team

  def current_tab = :season

  def show
    @season = @team.seasons.find(params[:id])
    remember_team(@team)
    @seasons = @team.seasons.by_recency
    # The rows are preloaded for trl_status_badge, which needs to know whether
    # anything has been entered at all before it says anything about it, and
    # for the scorer tallies on each card. The roster is looked up once and
    # handed to the helper, so the cards cost no queries of their own.
    @fixtures = @season.fixtures.includes(:touchdowns, :plays, :appearances).order(date: :desc)
    @players_by_id = @team.players.index_by(&:id)

    # Most recent played fixture nobody has entered anything against yet
    @next_to_record = @season.fixtures
      .where.not(our_score: nil).where.not(opponent_score: nil)
      .without_stats
      .order(date: :desc)
      .first
  end

  # The team's ladder, not the player one — see Standing. Only ever populated
  # for a Team that has linked a Spawtz team; the tab itself is hidden for
  # anyone else (see the season-tabs partial).
  def ladder
    @season = @team.seasons.find(params[:id])
    remember_team(@team)
    @seasons = @team.seasons.by_recency
    @standings = @season.standings.by_position
    # Which of the other teams on the ladder are themselves on Touchline, so
    # their name can link to a page rather than sit there as plain text. One
    # query for the whole table rather than one per row.
    @touchline_teams = Team.where(spawtz_team_id: @standings.map(&:spawtz_team_id))
                            .index_by(&:spawtz_team_id)
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
