class TeamsController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :set_team, only: %i[show sync]

  def index
    @my_teams = Current.user ? Current.user.teams : []
  end

  def sync
    unless Current.user&.admin_of?(@team)
      redirect_to @team, alert: "Not authorised."
      return
    end
    SyncFixturesJob.perform_later(@team.id)
    redirect_to @team, notice: "Sync started — check back in a moment."
  end

  def regenerate_invite
    @team = Team.find(params[:id])
    unless Current.user&.admin_of?(@team)
      redirect_to @team, alert: "Not authorised."
      return
    end
    @team.update!(invite_token: SecureRandom.urlsafe_base64(8))
    redirect_to @team, notice: "Invite link regenerated. The old link no longer works."
  end

  def current_tab = :team

  def show
    remember_team(@team)
    @current_season = @team.seasons.by_recency.first
    @membership = Current.user&.team_memberships&.find_by(team: @team)
    if @membership&.accepted?
      @my_player = @team.players.find_by(user_id: Current.user.id)
      @unclaimed_players = @team.players.where(user_id: nil).order(:name) if @my_player.nil?

      @leaderboard_seasons = @team.seasons.by_recency
      # Nothing in the query string means nobody has chosen a scope yet, which
      # defaults to the season actually being played rather than every game the
      # Team has ever recorded. "All time" is still one tap away — see the
      # season_id=all link below — and stays sticky once picked.
      @leaderboard_season =
        case params[:season_id]
        when nil     then @current_season
        when "all"   then nil
        else @leaderboard_seasons.find_by(id: params[:season_id])
        end
      @leaderboard = Leaderboard.for(@team, season: @leaderboard_season)
    end
  end

  def new
    @team_name     = params[:team_name]
    @location_name = params[:location_name]
    @location_slug = params[:location_slug]
    @venue_id      = params[:venue_id]
    @league_id     = params[:league_id]
    @season_id     = params[:season_id]
    @team_id       = params[:team_id]
    @existing_team = Team.find_by(spawtz_team_id: @team_id)
  end

  def create
    existing = Team.find_by(spawtz_team_id: team_params[:spawtz_team_id])

    if existing
      membership = existing.team_memberships.find_by(user: Current.user)
      if membership
        redirect_to existing, notice: "You already have a membership for #{existing.name}."
      else
        existing.team_memberships.create!(user: Current.user, role: :member, status: :pending)
        redirect_to existing, notice: "Join request sent — an admin will approve you shortly."
      end
    else
      @team = Team.new(team_params)
      if @team.save
        @team.team_memberships.create!(user: Current.user, role: :admin, status: :accepted)
        SyncFixturesJob.perform_later(@team.id)
        redirect_to @team, notice: "Team linked! Fixtures are syncing."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  private

  def set_team
    @team = Team.find(params[:id])
  end

  def team_params
    params.require(:team).permit(
      :name, :location, :trl_location_slug,
      :spawtz_venue_id, :spawtz_league_id, :spawtz_season_id, :spawtz_team_id
    )
  end
end
