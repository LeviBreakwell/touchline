require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin_user) }

  test "show is publicly accessible without signing in" do
    delete session_path
    get team_path(teams(:warthogs))
    assert_response :success
  end

  test "show still identifies signed-in user on a public page" do
    get team_path(teams(:warthogs))
    assert_response :success
    assert_select "details.user-menu"   # avatar menu rendered → user recognised
  end

  test "leaderboard defaults to all-time totals across seasons" do
    get team_path(teams(:warthogs))

    assert_response :success
    assert_select ".chip-active", text: "All time"
    assert_select ".leaderboard tbody tr", 2       # John and Jane have both appeared
  end

  test "leaderboard can be filtered to a single season" do
    get team_path(teams(:warthogs), season_id: seasons(:winter_2026).id)

    assert_response :success
    assert_select ".chip-active", text: seasons(:winter_2026).name
    assert_select ".leaderboard tbody tr", 1       # Jane did not play that season
    assert_select ".leaderboard tbody td", text: "John"
  end

  test "an unknown season id falls back to all-time" do
    get team_path(teams(:warthogs), season_id: "999999")

    assert_response :success
    assert_select ".chip-active", text: "All time"
  end

  test "the leaderboard is hidden from users who are not members" do
    sign_in_as users(:stranger)
    get team_path(teams(:warthogs))

    assert_select ".leaderboard", count: 0
  end

  test "create builds a new team and makes the creator admin" do
    assert_difference "Team.count" do
      post teams_path, params: { team: {
        name: "Brand New Team", location: "Sydney",
        spawtz_venue_id: "111", spawtz_league_id: "222",
        spawtz_season_id: "333", spawtz_team_id: "brand-new-id"
      }}
    end
    team = Team.last
    assert_redirected_to team_path(team)
    assert team.team_memberships.admin.accepted.exists?(user: users(:admin_user))
  end

  test "create with an existing spawtz_team_id sends a join request instead of a new team" do
    existing = teams(:warthogs)
    sign_in_as users(:stranger)

    assert_no_difference "Team.count" do
      post teams_path, params: { team: { spawtz_team_id: existing.spawtz_team_id } }
    end

    assert existing.team_memberships.pending.exists?(user: users(:stranger))
    assert_redirected_to team_path(existing)
  end

  test "create with existing spawtz_team_id when already a member does not duplicate membership" do
    existing = teams(:warthogs)

    assert_no_difference "TeamMembership.count" do
      post teams_path, params: { team: { spawtz_team_id: existing.spawtz_team_id } }
    end

    assert_redirected_to team_path(existing)
  end
end
