require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup { @team = teams(:warthogs) }

  test "signed-in user is auto-joined and redirected to team" do
    sign_in_as users(:stranger)
    assert_difference "TeamMembership.count" do
      get team_invite_path(@team.invite_token)
    end
    assert_redirected_to team_path(@team)
    assert @team.team_memberships.accepted.exists?(user: users(:stranger))
  end

  test "claiming a preselected player backfills accolades already earned" do
    john = players(:john)
    sign_in_as users(:stranger)

    assert_difference -> { AccoladeAward.count }, 7 do
      get team_invite_path(@team.invite_token, player_id: john.id)
    end

    john.reload
    assert_equal users(:stranger), john.user
    assert users(:stranger).accolade_awards.exists?(key: "tries_5")
  end

  test "already-a-member gets redirected without duplicate membership" do
    sign_in_as users(:member_user)
    assert_no_difference "TeamMembership.count" do
      get team_invite_path(@team.invite_token)
    end
    assert_redirected_to team_path(@team)
  end

  test "unauthenticated user sees the invite landing page" do
    get team_invite_path(@team.invite_token)
    assert_response :success
    assert_select "h1", /#{@team.name}/
  end

  test "unauthenticated user has return URL stored for after sign-in" do
    get team_invite_path(@team.invite_token)
    assert_equal team_invite_url(@team.invite_token), session[:return_to_after_authenticating]
  end

  test "invalid token returns 404" do
    get team_invite_path("bogus-token")
    assert_response :not_found
  end
end
