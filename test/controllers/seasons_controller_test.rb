require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team   = teams(:warthogs)
    @season = seasons(:winter_2026)
    sign_in_as users(:member_user)
  end

  test "shows the enter-stats prompt for the most recent played game with no stats" do
    # played_no_stats (51 Shades of Shape) is played but has nothing entered
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
    fixtures(:played_with_stats).touchdowns.delete_all
    fixtures(:played_with_stats).appearances.delete_all
    fixtures(:played_with_stats).update!(our_score: nil, opponent_score: nil)
    get team_season_path(@team, @season)
    assert_select ".record-prompt", count: 0
  end

  # The board is the Team tab's job, over any scope you like — this tab is the
  # draw. See TeamsControllerTest for the leaderboard itself.
  test "the season tab is the fixtures, not the board" do
    get team_season_path(@team, @season)

    assert_select ".ladder--board", count: 0
    assert_select ".fixture-card"
  end

  test "the season dropdown carries every season the team has played" do
    get team_season_path(@team, @season)

    assert_select ".scope-select option", @team.seasons.count
    assert_select ".scope-select option[selected]", text: @season.name
  end

  # winter_2026: john scored 3T/1A v WGD 13+ and 4T/2A v Toowong Terrors.
  test "each fixture card tallies its scorers with one icon per try and assist" do
    get team_season_path(@team, @season)

    assert_select ".fixture-scorers", 2
    assert_select ".fixture-scorers .scorer-name", text: "John", count: 2
    assert_select ".fixture-scorers .tally-tries svg", 7
    assert_select ".fixture-scorers .tally-assists svg", 3
  end

  test "a player named on the sheet who did not score is left off the card" do
    get team_season_path(@team, @season)

    assert_select ".scorer-name", text: "Jane", count: 0
  end

  test "a fixture with no stats entered gets no scorer strip" do
    get team_season_path(@team, @season)

    assert_select "a[href=?] .fixture-scorers",
      team_season_fixture_path(@team, @season, fixtures(:played_no_stats)), count: 0
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
