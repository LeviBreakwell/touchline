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

  test "a finals fixture is labelled with its round on its card" do
    fixtures(:played_with_stats).update!(finals_label: "Grand Final")

    get team_season_path(@team, @season)

    assert_select ".badge-finals", text: "Grand Final"
  end

  test "an ordinary fixture gets no finals badge" do
    get team_season_path(@team, @season)

    assert_select ".badge-finals", count: 0
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

  # ── THE LADDER TAB ─────────────────────────────────────────────────────────
  #
  # Not the player Leaderboard — the TRL division table, scraped into
  # Standing. See SpawtzScraperTest for how it gets there.

  test "the ladder tab is offered for a team linked to TRL" do
    get team_season_path(@team, @season)

    assert_select ".tabs a", text: "Ladder"
  end

  test "the ladder tab is hidden for a team that never linked TRL" do
    @team.update!(spawtz_team_id: nil)

    get team_season_path(@team, @season)

    assert_select ".tabs", count: 0
  end

  test "the ladder shows every team's row, best first" do
    get ladder_team_season_path(@team, @season)

    assert_response :success
    assert_select ".ladder-table tbody tr", 2
    names = css_select(".ladder-table tbody tr td:nth-child(2)").map { |td| td.text.strip }
    assert_equal [ "Just The Lads", "Warthogs" ], names
  end

  test "a rival team also on Touchline is a link to their page" do
    get ladder_team_season_path(@team, @season)

    assert_select "td a[href=?]", team_path(teams(:just_the_lads)), text: "Just The Lads"
  end

  test "a team not on Touchline is plain text, not a dead link" do
    teams(:just_the_lads).update!(spawtz_team_id: "not-203043")

    get ladder_team_season_path(@team, @season)

    assert_select "td a", text: "Just The Lads", count: 0
    assert_select ".ladder-table", text: /Just The Lads/
  end

  test "our own row is highlighted on the ladder" do
    get ladder_team_season_path(@team, @season)

    assert_select ".ladder-table-us", text: /Warthogs/
  end

  test "a season with no ladder synced yet shows an empty state, not an error" do
    get ladder_team_season_path(@team, seasons(:summer_2025))

    assert_response :success
    assert_select ".ladder-table", count: 0
    assert_select ".empty"
  end

  test "unauthenticated user can view the ladder" do
    delete session_path
    get ladder_team_season_path(@team, @season)
    assert_response :success
  end
end
