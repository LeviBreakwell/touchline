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

  # A dropdown rather than chips: two seasons a year is seven chips after three
  # years, wrapping across a phone.
  test "leaderboard defaults to the season most recently played, not all time" do
    get team_path(teams(:warthogs))

    assert_response :success
    assert_select ".scope-select option[selected]", text: seasons(:winter_2026).name
    assert_select ".ladder--board .lcard", 1       # Jane did not play that season
    assert_select ".ladder--board .lcard-name", text: /John/
  end

  test "leaderboard can be filtered to a single season" do
    get team_path(teams(:warthogs), season_id: seasons(:winter_2026).id)

    assert_response :success
    assert_select ".scope-select option[selected]", text: seasons(:winter_2026).name
    assert_select ".ladder--board .lcard", 1       # Jane did not play that season
    assert_select ".ladder--board .lcard-name", text: /John/
  end

  test "all time is one tap away, and totals across every season" do
    get team_path(teams(:warthogs), season_id: "all")

    assert_response :success
    assert_select ".scope-select option[selected]", text: "All time"
    assert_select ".ladder--board .lcard", 2       # John and Jane have both appeared
  end

  test "an unknown season id falls back to all-time" do
    get team_path(teams(:warthogs), season_id: "999999")

    assert_response :success
    assert_select ".scope-select option[selected]", text: "All time"
  end

  # ── THE TABS ──────────────────────────────────────────────────────────────

  test "the three tabs are on every screen but the ladder" do
    get team_path(teams(:warthogs))

    assert_select ".tab-bar .tab", 3
    assert_select ".tab-bar .tab--on", text: /Team/
  end

  test "the ladder takes over the screen" do
    get team_season_fixture_path(teams(:warthogs), seasons(:winter_2026), fixtures(:played_with_stats))

    assert_select ".tab-bar", count: 0
  end

  test "the season tab points at the season most recently played" do
    get team_path(teams(:warthogs))

    assert_select ".tab-bar a[href=?]", team_season_path(teams(:warthogs), seasons(:winter_2026))
  end

  # Team is global context, so the tabs follow you off a team's own pages.
  test "the tabs stay on the team you were last looking at" do
    get team_path(teams(:warthogs))
    get profile_path

    assert_select ".tab-bar a[href=?]", team_path(teams(:warthogs))
    assert_select ".tab-bar .tab--on", text: /Profile/
  end

  # A User is one person, so their own name goes to the record that counts every
  # team they play for. Everyone else's goes to the Team's view of them, which
  # is the only view an unclaimed roster entry has.
  test "your own name on the board goes to your profile, everyone else's to theirs" do
    sign_in_as users(:member_user)   # linked to Jane
    get team_path(teams(:warthogs), season_id: "all")   # Jane only played the older season

    assert_select "a.leaderboard-player[href=?]", profile_path, text: players(:jane).name
    assert_select "a.leaderboard-player[href=?]", team_player_path(teams(:warthogs), players(:john))
    assert_select "a.leaderboard-player[href=?]", team_player_path(teams(:warthogs), players(:jane)), count: 0
  end

  test "the gear is the admin's way in, and only the admin's" do
    get team_path(teams(:warthogs))
    assert_select "a.btn-gear[href=?]", team_settings_path(teams(:warthogs))

    sign_in_as users(:member_user)
    get team_path(teams(:warthogs))
    assert_select "a.btn-gear", count: 0
  end

  test "the leaderboard is hidden from users who are not members" do
    sign_in_as users(:stranger)
    get team_path(teams(:warthogs))

    assert_select ".ladder--board", count: 0
  end

  test "create builds a new team and makes the creator admin" do
    assert_difference "Team.count" do
      post teams_path, params: { team: {
        name: "Brand New Team", location: "Sydney",
        spawtz_venue_id: "111", spawtz_league_id: "222",
        spawtz_season_id: "333", spawtz_team_id: "brand-new-id"
      } }
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
