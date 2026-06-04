class PlayersController < ApplicationController
  before_action :set_team
  before_action -> { require_team_admin!(@team) }, except: %i[claim edit update]

  def index
    @players = @team.players.order(:name)
  end

  def new
    @player = @team.players.new
  end

  def create
    @player = @team.players.new(player_params)
    if @player.save
      redirect_to team_players_path(@team), notice: "#{@player.name} added to roster."
    else
      render :new, status: :unprocessable_entity
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
        redirect_to team_players_path(@team), notice: "#{@player.name} updated."
      else
        redirect_to team_path(@team), notice: "Your name has been updated to #{@player.name}."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @team.players.find(params[:id]).destroy
    redirect_to team_players_path(@team), notice: "Player removed."
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

    redirect_to team_path(@team), notice: "You're now linked as #{player.name}."
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def can_edit_player?(player)
    Current.user&.admin_of?(@team) || player.user_id == Current.user&.id
  end

  def player_params
    params.require(:player).permit(:name)
  end
end
