require "test_helper"

class StatLineTest < ActiveSupport::TestCase
  test "counts only appearances" do
    # Jane was named for two games and took the field in one of them
    line = StatLine.for(players(:jane))
    assert_equal 1, line.games
  end

  test "sums tries, assists and distinct seasons across the games" do
    line = players(:john).career_stats

    assert_equal 8, line.tries
    assert_equal 5, line.assists
    assert_equal 3, line.games
    assert_equal 2, line.seasons
  end

  test "points is tries x 2 plus assists" do
    assert_equal 21, players(:john).career_stats.points
  end

  test "per-game averages divide by appearances" do
    line = players(:john).career_stats

    assert_equal 2.7, line.tries_per_game
    assert_equal 1.7, line.assists_per_game
    assert_equal 7.0, line.points_per_game
  end

  test "per-season averages divide by seasons played" do
    line = players(:john).career_stats

    assert_equal 4.0, line.tries_per_season
    assert_equal 2.5, line.assists_per_season
    assert_equal 10.5, line.points_per_season
    assert_equal 1.5, line.games_per_season
  end

  # ── TRL VERIFICATION ──────────────────────────────────────────────────────

  test "a fixture TRL has not confirmed still counts towards a stat line" do
    # John's 4T 2A on awaiting_trl is inside his career line, not held back
    assert_equal 8, players(:john).career_stats.tries
    assert_equal 3, players(:john).career_stats.games
  end

  test "unconfirmed reports the slice TRL has not checked" do
    pending = players(:john).unconfirmed_stats

    assert_equal 4, pending.tries
    assert_equal 2, pending.assists
    assert_equal 1, pending.games
  end

  test "unconfirmed is empty once every result has landed" do
    fixtures(:awaiting_trl).update!(our_score: 9, opponent_score: 1)
    fixtures(:awaiting_trl).refresh_stats_verification!

    assert_not players(:john).unconfirmed_stats.any?
  end

  test "a result landing changes nothing about the totals" do
    before = players(:john).career_stats.points
    fixtures(:awaiting_trl).update!(our_score: 9, opponent_score: 1)
    fixtures(:awaiting_trl).refresh_stats_verification!

    assert_equal before, players(:john).reload.career_stats.points
  end

  test "averages are zero rather than a division error without appearances" do
    line = StatLine.new

    assert_equal 0.0, line.points_per_game
    assert_equal 0.0, line.points_per_season
    assert_not line.any?
  end

  # ── PLAYS ─────────────────────────────────────────────────────────────────

  def record(kind, count = 1, fixture: fixtures(:played_with_stats), player: players(:john))
    count.times { fixture.plays.create!(player: player, kind: kind) }
  end

  test "points counts plays, and can be dragged below a player's tries" do
    record(:opposition_assist, 3)   # −6 against John's 21

    assert_equal 15, players(:john).career_stats.points
  end

  test "a play is worth what it is worth, whichever way it points" do
    record(:bomb_catch, 2)
    record(:dropped_bomb)

    line = players(:john).career_stats
    assert_equal 2, line.bomb_catches
    assert_equal 1, line.dropped_bombs
    assert_equal 22, line.points   # 21 + 2 − 1
  end

  test "both negatives read as one number, and they stack" do
    record(:dropped_bomb)
    record(:opposition_assist)

    assert_equal 2, players(:john).career_stats.negative_plays
  end

  # The Social league ranks on Touchdowns alone, so a Player has two point
  # totals and any surface showing one has to say which.
  test "touchdown points leave plays out" do
    record(:bomb_catch, 5)

    line = players(:john).career_stats
    assert_equal 21, line.touchdown_points
    assert_equal 26, line.points
  end

  # ── CATCH RATE ────────────────────────────────────────────────────────────

  test "every contested kick-off is one or the other, so the rate falls out" do
    record(:bomb_catch, 7)
    record(:dropped_bomb, 1)

    assert_equal 88, players(:john).career_stats.catch_rate
  end

  test "catch rate is nil until somebody has gone up for one" do
    assert_nil players(:john).career_stats.catch_rate
  end
end
