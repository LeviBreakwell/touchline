require "test_helper"

# A property of the Fixture, not the tab that set it — see
# match_ladder_controller#toggleLock.
class FixtureLocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team    = teams(:warthogs)
    @season  = seasons(:winter_2026)
    @fixture = fixtures(:played_no_stats)
    sign_in_as users(:member_user)
  end

  def lock_path(fixture = @fixture) = team_season_fixture_lock_path(@team, @season, fixture)

  def patch_json(path, body)
    patch path, params: body.to_json, headers: { "CONTENT_TYPE" => "application/json" }
  end

  test "locking persists past the request that set it" do
    patch_json lock_path, locked: true

    assert_response :success
    assert @fixture.reload.locked?
  end

  test "unlocking persists the same way" do
    @fixture.update!(locked: true)

    patch_json lock_path, locked: false

    assert_response :success
    assert_not @fixture.reload.locked?
  end

  test "a stranger cannot lock a fixture" do
    sign_in_as users(:stranger)

    patch_json lock_path, locked: true

    assert_redirected_to team_path(@team)
    assert_not @fixture.reload.locked?
  end
end
