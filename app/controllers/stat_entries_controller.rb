# Base for the three writers behind the match ladder.
#
# The field screen writes immediately: every gesture is one row inserted or
# deleted, and there is no sheet, no submit and no half-entered game to
# preserve. Going past TRL's score is no longer refused either — it flags the
# Fixture over official, which is the path the app already took when TRL
# corrected a score downward.
class StatEntriesController < ApplicationController
  before_action :set_context
  before_action -> { require_team_member!(@team) }

  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def set_context
    @team = Team.find(params[:team_id])
    @season = @team.seasons.find(params[:season_id])
    @fixture = @season.fixtures.find(params[:fixture_id])
  end

  def roster_player(id) = @team.players.find(id)

  # A rung is a total crossing a line, so it is earned the moment it is
  # crossed and the next gesture cannot take it back. The per-game accolades
  # are the ones that have to wait — see AccoladeLedger#settle_fixture.
  def settle_totals_for(*players)
    User.where(id: players.compact.filter_map(&:user_id).uniq)
        .find_each { |user| AccoladeLedger.settle_totals(user) }
  end

  def first_name(player) = player.name.split.first

  # Every write answers with the ladder as it now stands, so what is on screen
  # is always what is in the rows — the standing moves because the row landed,
  # not because the screen guessed.
  def render_ladder(toast:, undo: nil)
    render json: {
      ladder: render_to_string(
        partial: "fixtures/ladder",
        formats: [ :html ],
        locals: { ladder: MatchLadder.new(@fixture, @team), team: @team, season: @season, fixture: @fixture, editable: true }
      ),
      toast: toast,
      undo: undo
    }
  end
end
