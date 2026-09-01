require "test_helper"

class FixturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team    = teams(:warthogs)
    @season  = seasons(:winter_2026)
    @fixture = fixtures(:played_with_stats)
    sign_in_as users(:member_user)
  end

  test "show is publicly accessible" do
    delete session_path
    get team_season_fixture_path(@team, @season, @fixture)
    assert_response :success
  end

  test "signed-in member sees stepper buttons" do
    get team_season_fixture_path(@team, @season, @fixture)
    assert_response :success
    assert_select ".stepper-btn"
  end

  test "unsigned-in visitor sees read-only stat view without steppers" do
    delete session_path
    get team_season_fixture_path(@team, @season, @fixture)
    assert_response :success
    assert_select ".stepper-btn", count: 0
    assert_select ".stat-readonly"
  end

  test "member sees an attendance tick per player, pre-set from the recorded stats" do
    get team_season_fixture_path(@team, @season, @fixture)

    # The roster is ordered by name: Jane first, then John
    assert_select ".played-toggle", 2
    assert_select "input[name=?][checked]", "game_stats[0][played]", count: 0   # Jane did not play
    assert_select "input[name=?][checked]", "game_stats[1][played]"             # John did
  end

  test "attendance defaults to played on a fixture with nothing recorded yet" do
    get team_season_fixture_path(@team, @season, fixtures(:played_no_stats))

    assert_select "input[name=?][checked]", "game_stats[0][played]"
    assert_select "input[name=?][checked]", "game_stats[1][played]"
  end

  test "read-only view marks players who did not take the field" do
    delete session_path
    get team_season_fixture_path(@team, @season, @fixture)

    assert_select ".stat-dnp", text: "Did not play"
  end
end
