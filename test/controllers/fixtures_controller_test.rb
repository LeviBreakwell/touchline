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
end
