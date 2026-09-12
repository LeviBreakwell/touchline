class PlayersController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :set_team
  before_action -> { require_team_admin!(@team) }, except: %i[show claim edit update]

  def show
    @player = @team.players.find(params[:id])
    remember_team(@team)

    @career = @player.career_stats
    @pending = @player.unconfirmed_stats
    @seasons = @player.seasons_played

    # This season leads, because it is the comparison every arrow on the page
    # makes — it should not be below the fold.
    @season = @seasons.first
    @season_line = @season ? @player.season_stats(@season) : StatLine.new
    @form = Form.new(season: @season_line, career: @career)

    @progression = Progression.new(@player.user) if @player.user
  end

  def new
    @player = @team.players.new
  end

  def create
    @player = @team.players.new(player_params)
    if @player.save
      redirect_to team_settings_path(@team), notice: "#{@player.name} added to roster."
    else
      @settings = TeamSettings.new(@team)
      render "team_settings/show", status: :unprocessable_entity
    end
  end

  def edit
    @player = @team.players.find(params[:id])
    unless can_edit_player?(@player)
      redirect_to team_path(@team), alert: "Not authorised."
    end
  end

  def update
    @player = @team.players.find(params[:id])
    unless can_edit_player?(@player)
      redirect_to team_path(@team), alert: "Not authorised."
      return
    end
    if @player.update(player_params)
      if Current.user.admin_of?(@team)
        redirect_to team_settings_path(@team), notice: "#{@player.name} updated."
      else
        redirect_to team_path(@team), notice: "Your name has been updated to #{@player.name}."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @team.players.find(params[:id]).destroy
    redirect_to team_settings_path(@team), notice: "Player removed."
  end

  def claim
    unless Current.user.member_of?(@team)
      redirect_to team_path(@team), alert: "You must be a team member."
      return
    end

    player = @team.players.find(params[:id])

    if player.user_id.present? && player.user_id != Current.user.id
      redirect_to team_path(@team), alert: "#{player.name} is already linked to another account."
      return
    end

    # Unlink any other player this user was previously claiming on this team
    @team.players.where(user_id: Current.user.id).where.not(id: player.id).update_all(user_id: nil)
    player.update!(user_id: Current.user.id)

    # Banked history earns nothing until somebody claims it, and then it earns
    # all of it at once — which is the payoff the claim flow exists for.
    AccoladeLedger.settle(Current.user)

    redirect_to profile_slots_path(claimed: player.id), notice: "You're now linked as #{player.name}."
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def can_edit_player?(player)
    Current.user&.admin_of?(@team) || player.user_id == Current.user&.id
  end

  def player_params
    params.require(:player).permit(:name, :email)
  end
end
