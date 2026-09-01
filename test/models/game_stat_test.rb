require "test_helper"

class GameStatTest < ActiveSupport::TestCase
  test "points is tries × 2 plus assists" do
    stat = game_stats(:johns_game_one)  # 3 tries, 1 assist
    assert_equal 7, stat.points
  end

  test "points is zero when no tries or assists" do
    stat = GameStat.new(tries: 0, assists: 0)
    assert_equal 0, stat.points
  end

  test "recording a try marks the player as having played" do
    stat = game_stats(:janes_game_one)   # did not play
    stat.update!(tries: 1, played: false)

    assert stat.played
  end

  test "a scoreless player can be recorded as absent" do
    stat = game_stats(:johns_game_one)
    stat.update!(tries: 0, assists: 0, played: false)

    assert_not stat.played
  end

  test "played scope returns appearances only" do
    assert_equal [ true ], GameStat.played.where(player: players(:jane)).map(&:played)
  end

  test "destroying a season takes its fixtures and stats with it" do
    season = seasons(:winter_2026)

    assert_difference "GameStat.count", -season.fixtures.sum { |f| f.game_stats.count } do
      season.destroy
    end
  end

  test "destroying a team does not trip over verification on the way out" do
    assert_nothing_raised { teams(:warthogs).destroy }
    assert_equal 0, GameStat.count
  end
end
