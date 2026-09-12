# The sideline toggle. The row's existence is the fact, so this inserts and
# deletes rather than setting a flag.
#
# An Appearance is identified by the pair it names — one Player, one Fixture,
# and a unique index saying so — which is why destroy takes the Player rather
# than a row id: the screen knows who was on the sideline, and does not need to
# have been told the id of a row it is about to remove.
class AppearancesController < StatEntriesController
  def create
    @fixture.open_sideline!

    player = roster_player(params.require(:player_id))
    Appearance.find_or_create_by!(fixture_id: @fixture.id, player_id: player.id)
    settle_totals_for(player)

    render_ladder(toast: "#{first_name(player)} — played")
  end

  # Recording a try or a Play is itself proof that somebody took the field, so
  # the sideline can never contradict the stats standing beside it: clear the
  # stats first, or leave them alone.
  def destroy
    @fixture.open_sideline!

    player = roster_player(params.require(:player_id))
    if stats_recorded_for?(player)
      return render json: { error: "#{first_name(player)} has stats in this game — take those off first." },
                    status: :unprocessable_entity
    end

    @fixture.appearances.find_by(player_id: player.id)&.destroy!

    render_ladder(toast: "#{first_name(player)} — didn't play")
  end

  private

  def stats_recorded_for?(player)
    @fixture.touchdowns.where(scorer_player_id: player).or(
      @fixture.touchdowns.where(assister_player_id: player)
    ).exists? || @fixture.plays.exists?(player_id: player.id)
  end
end
