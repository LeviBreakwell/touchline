require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team   = teams(:warthogs)
    @season = seasons(:winter_2026)
    sign_in_as users(:member_user)
  end

  test "shows the enter-stats prompt for the most recent played game with no stats" do
    # played_no_stats (51 Shades of Shape) is played but has no game_stats
    get team_season_path(@team, @season)
    assert_response :success
    assert_select ".record-prompt", text: /51 Shades of Shape/
  end

  test "does not show enter-stats prompt when all played games have stats" do
    fixtures(:played_no_stats).update!(our_score: nil, opponent_score: nil)
    get team_season_path(@team, @season)
    assert_select ".record-prompt", count: 0
  end

  test "does not surface upcoming games in the enter-stats prompt" do
    # Make both played fixtures have no scores → prompt should disappear
    fixtures(:played_no_stats).update!(our_score: nil, opponent_score: nil)
    fixtures(:played_with_stats).game_stats.delete_all
    fixtures(:played_with_stats).update!(our_score: nil, opponent_score: nil)
    get team_season_path(@team, @season)
    assert_select ".record-prompt", count: 0
  end

  test "leaderboard table appears when stats exist" do
    get team_season_path(@team, @season)
    assert_select "table.leaderboard"
  end

  test "unauthenticated user can view the season page" do
    delete session_path
    get team_season_path(@team, @season)
    assert_response :success
  end

  test "enter-stats prompt is hidden from non-members" do
    sign_in_as users(:stranger)
    get team_season_path(@team, @season)
    assert_select ".record-prompt", count: 0
  end
end
