require "test_helper"

# John's winter season is two games: played_with_stats (3T 1A, verified) and
# awaiting_trl (4T 2A, entered before TRL published). Both count — verification
# gates the social league, not a Team's own numbers.
class PlayerTest < ActiveSupport::TestCase
  setup do
    @player = players(:john)
    @season = seasons(:winter_2026)
  end

  test "season_tries counts tries in the season" do
    assert_equal 7, @player.season_tries(@season)
  end

  test "season_assists counts assists in the season" do
    assert_equal 3, @player.season_assists(@season)
  end

  test "season_points is tries×2 plus assists" do
    assert_equal 17, @player.season_points(@season)
  end

  test "season_points is zero for a player with no stats" do
    assert_equal 0, players(:jane).season_points(@season)
  end

  test "name returns the player's name" do
    assert_equal "John", @player.name
  end

  test "season_games counts appearances in the season" do
    assert_equal 2, @player.season_games(@season)
  end

  test "season_games excludes a game the player did not take the field in" do
    assert_equal 0, players(:jane).season_games(@season)
  end

  test "career totals span every season" do
    assert_equal 8, @player.total_tries
    assert_equal 5, @player.total_assists
    assert_equal 21, @player.total_points
    assert_equal 3, @player.total_games
  end

  test "seasons_played lists only seasons the player appeared in, newest first" do
    assert_equal [ seasons(:winter_2026), seasons(:summer_2025) ], @player.seasons_played.to_a
    assert_equal [ seasons(:summer_2025) ], players(:jane).seasons_played.to_a
  end
end
