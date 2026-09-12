# A tap is a try. A drag from one card to another is that pass for that try:
# one row, carrying both names.
class TouchdownsController < StatEntriesController
  def create
    @fixture.open_sideline!

    scorer   = roster_player(params.require(:scorer_player_id))
    assister = params[:assister_player_id].present? ? roster_player(params[:assister_player_id]) : nil
    touchdown = @fixture.touchdowns.create!(scorer: scorer, assister: assister)
    settle_totals_for(scorer, assister)

    render_ladder(toast: toast_for(scorer, assister), undo: undo_for(touchdown))
  end

  def destroy
    @fixture.touchdowns.find(params[:id]).destroy!
    render_ladder(toast: "Undone")
  end

  private

  def toast_for(scorer, assister)
    return "#{first_name(scorer)} — try +2" if assister.nil?
    "#{first_name(assister)} → #{first_name(scorer)} · assist +1 · try +2"
  end

  def undo_for(touchdown)
    { path: team_season_fixture_touchdown_path(@team, @season, @fixture, touchdown) }
  end
end
