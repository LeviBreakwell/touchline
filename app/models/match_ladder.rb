# One Fixture's standing, card by card: the live ladder the entry screen is.
#
# Entering a stat and watching the standing move are the same act, so the screen
# is not a pitch but a ranked list of the squad — which is also the Team
# leaderboard's card, at match scope.
class MatchLadder
  Row = Struct.new(:player, :played, :tries, :assists,
                   :bomb_catches, :dropped_bombs, :opposition_assists, keyword_init: true) do
    def points = Leaderboard.points_for(to_h)

    # Both negatives under one column. They stack — a dropped bomb the
    # opposition scored from is both — so this can exceed the number of
    # distinct incidents.
    def negative_plays = dropped_bombs + opposition_assists

    def played? = played
  end

  # An assist that has been recorded, and how often this pair have connected.
  Connection = Struct.new(:assister_id, :scorer_id, :count)

  def initialize(fixture, team)
    @fixture = fixture
    @team = team
  end

  # The squad, best first. Ties break the same way the Team board breaks them,
  # so a card does not jump when the scope changes.
  def played
    @played ||= rows.select(&:played?)
                    .sort_by { |row| [ -row.points, -row.tries, -row.assists, row.player.name ] }
  end

  def sidelined
    @sidelined ||= rows.reject(&:played?)
  end

  # The most points in this Fixture, Plays included — a Team's own award,
  # decided by the people who were at the game. Nobody is MVP of a scoreless
  # game.
  def mvp
    best = played.first
    best if best && played.any? { |row| row.points != 0 }
  end

  # Every assist so far, as pairs: the gutter draws one arc per pair and
  # thickens it the more often they connect.
  def connections
    touchdowns.select(&:assister_player_id)
              .group_by { |td| [ td.assister_player_id, td.scorer_player_id ] }
              .filter_map { |(assister, scorer), list| Connection.new(assister, scorer, list.size) if scorer }
  end

  def appearance_for(player) = appearances[player.id]

  def any_stats? = touchdowns.any? || plays.any?

  private

  def rows
    @rows ||= @team.players.order(:name).map do |player|
      kinds = plays.select { |play| play.player_id == player.id }.group_by(&:kind)

      Row.new(
        player: player,
        played: sideline_open? ? appearances.key?(player.id) : true,
        tries:   touchdowns.count { |td| td.scorer_player_id == player.id },
        assists: touchdowns.count { |td| td.assister_player_id == player.id },
        bomb_catches:       kinds.fetch("bomb_catch", []).size,
        dropped_bombs:      kinds.fetch("dropped_bomb", []).size,
        opposition_assists: kinds.fetch("opposition_assist", []).size
      )
    end
  end

  # Until somebody writes to this Fixture there are no Appearance rows, and
  # everyone defaults to played. The first write settles the squad — see
  # Fixture#open_sideline! — and from then on the rows are the record.
  def sideline_open? = appearances.any?

  def appearances = @appearances ||= @fixture.appearances.index_by(&:player_id)
  def touchdowns  = @touchdowns  ||= @fixture.touchdowns.to_a
  def plays       = @plays       ||= @fixture.plays.to_a
end
