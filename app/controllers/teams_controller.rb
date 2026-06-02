class TeamsController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :set_team, only: %i[show]

  def index
    @my_teams = Current.user ? Current.user.teams : []
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

  def show
    @current_season = @team.seasons.order(created_at: :desc).first
    @membership = Current.user&.team_memberships&.find_by(team: @team)
    if @membership&.accepted?
      @my_player = @team.players.find_by(user_id: Current.user.id)
      @unclaimed_players = @team.players.where(user_id: nil).order(:name) if @my_player.nil?
    end
    stats_by_player = GameStat
      .joins(player: :team)
      .where(players: { team_id: @team.id })
      .group(:player_id)
      .select("player_id, SUM(tries) AS total_tries, SUM(assists) AS total_assists, COUNT(*) AS total_games")
      .index_by(&:player_id)

    @all_time_leaderboard = @team.players
      .order(:name)
      .filter_map { |p|
        s = stats_by_player[p.id]
        next if s.nil? || s.total_games.to_i.zero?
        tries   = s.total_tries.to_i
        assists = s.total_assists.to_i
        { player: p, tries: tries, assists: assists, points: (tries * 2) + assists, games: s.total_games.to_i }
      }
      .sort_by { |r| [-r[:points], -r[:tries], -r[:assists]] }
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
