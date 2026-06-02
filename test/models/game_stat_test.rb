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
end
