require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "shows career totals and join date for the signed-in user" do
    sign_in_as users(:member_user)   # linked to Jane
    get profile_path

    assert_response :success
    assert_select "h1", users(:member_user).name
    assert_select ".card-meta", text: /Joined/
    assert_select ".stat-tile-label", text: "Seasons"
  end

  test "lists the players the user is linked to" do
    sign_in_as users(:member_user)
    get profile_path

    assert_select "a[href=?]", team_player_path(teams(:warthogs), players(:jane))
  end

  test "requires authentication" do
    get profile_path
    assert_redirected_to new_session_path
  end
end
