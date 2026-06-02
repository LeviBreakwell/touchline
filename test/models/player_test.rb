require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  setup do
    @player = players(:john)
    @season = seasons(:winter_2026)
  end

  test "season_tries counts tries in the season" do
    assert_equal 3, @player.season_tries(@season)
  end

  test "season_assists counts assists in the season" do
    assert_equal 1, @player.season_assists(@season)
  end

  test "season_points is tries×2 plus assists" do
    assert_equal 7, @player.season_points(@season)
  end

  test "season_points is zero for a player with no stats" do
    assert_equal 0, players(:jane).season_points(@season)
  end

  test "name returns the player's name" do
    assert_equal "John", @player.name
  end
end
