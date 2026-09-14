# The long-hold menu: the stats that are not tries. A row per occurrence, so
# undoing one is deleting it — and so a Player can have five of the same kind
# in a game without a counter anywhere.
class PlaysController < StatEntriesController
  LABELS = {
    "bomb_catch"     => "bomb catch +1",
    "dropped_bomb"   => "dropped bomb −1",
    "critical_error" => "critical error −8"
  }.freeze

  def create
    @fixture.open_sideline!

    kind = params.require(:kind)
    return head :unprocessable_entity unless Play.kinds.key?(kind)

    player = roster_player(params.require(:player_id))
    play = @fixture.plays.create!(player: player, kind: kind)
    settle_totals_for(player)

    render_ladder(
      toast: "#{first_name(player)} — #{LABELS.fetch(kind)}",
      undo: { path: team_season_fixture_play_path(@team, @season, @fixture, play) }
    )
  end

  def destroy
    @fixture.plays.find(params[:id]).destroy!
    render_ladder(toast: "Undone")
  end

  # The hold menu's Remove items: one kind can be several identical rows, and
  # the card only knows the kind was wrong, not which occurrence. They are
  # interchangeable, so the most recent one is the one it means.
  def destroy_latest
    kind = params.require(:kind)
    return head :unprocessable_entity unless Play.kinds.key?(kind)

    player = roster_player(params.require(:player_id))
    @fixture.plays.where(player_id: player.id, kind: kind).order(:created_at).last&.destroy!
    render_ladder(toast: "Undone")
  end
end
