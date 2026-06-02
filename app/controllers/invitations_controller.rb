class InvitationsController < ApplicationController
  allow_unauthenticated_access only: [:show]

  def show
    @team = Team.find_by!(invite_token: params[:invite_token])
    @player_id = params[:player_id]

    unless Current.user
      session[:return_to_after_authenticating] = request.url
      @current_season = @team.seasons.order(created_at: :desc).first
      @joining_as = @team.players.find_by(id: @player_id, user_id: nil) if @player_id.present?
      @leaderboard = season_leaderboard(@current_season) if @current_season
      return
    end

    existing = @team.team_memberships.find_by(user: Current.user)
    if existing
      redirect_to team_path(@team), notice: "You're already part of #{@team.name}."
    else
      @team.team_memberships.create!(user: Current.user, role: :member, status: :accepted)
      if @player_id.present?
        player = @team.players.find_by(id: @player_id, user_id: nil)
        player&.update!(user: Current.user)
      end
      redirect_to team_path(@team), notice: "You're in! Welcome to #{@team.name}."
    end
  end

  private

  def season_leaderboard(season)
    stats = GameStat
      .joins(:fixture)
      .where(fixtures: { season_id: season.id })
      .group(:player_id)
      .select("player_id, SUM(tries) AS tries, SUM(assists) AS assists")
      .index_by(&:player_id)

    @team.players.order(:name).filter_map { |p|
      s = stats[p.id]
      next unless s
      tries = s.tries.to_i; assists = s.assists.to_i
      next if tries.zero? && assists.zero?
      { name: p.name, tries: tries, assists: assists, points: (tries * 2) + assists }
    }.sort_by { |r| -r[:points] }.first(5)
  end
end
