# The three cosmetic slots, on their own screen.
#
# It is also where claiming lands, because that is the moment the whole system
# is worth explaining: a three-season veteran arrives at level 13 with sixteen
# accolades and a whole border era at once, and the useful thing to do with
# that is pick a title.
class ProfileSlotsController < ApplicationController
  def current_tab = :profile

  def show
    @user = Current.user
    @progression = Progression.new(@user)
    @claimed = @user.players.find_by(id: params[:claimed])
    @career = StatLine.for(@user.players.select(:id)) if @claimed
  end

  # A Title is selected by the Player from those unlocked, never assigned — the
  # negative accolades are only bearable because "Butterfingers" is worn on
  # purpose rather than pinned on somebody.
  def update
    user = Current.user
    user.update!(
      title_key: wearable(user, params.dig(:user, :title_key)),
      banner_key: wearable(user, params.dig(:user, :banner_key)),
      showcase_keys: Array(params.dig(:user, :showcase_keys)).filter_map { |key| wearable(user, key) }.uniq
    )

    redirect_to profile_path, notice: "Profile updated."
  end

  private

  # You can only wear what you have earned, whatever the form says.
  def wearable(user, key)
    key.presence if key.present? && user.accolade_awards.exists?(key: key)
  end
end
