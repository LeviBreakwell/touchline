require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "shows who you are, what you have reached, and what it earned" do
    sign_in_as users(:member_user)   # linked to Jane
    get profile_path

    assert_response :success
    assert_select "h1", users(:member_user).name
    assert_select ".card-meta", text: /Joined/
    assert_select ".identity .level-number"
    assert_select ".showcase .showcase-slot", Progression::SHOWCASE_SLOTS
    assert_select ".stat-tile-label", text: "Catch rate"
  end

  # Somebody showing their card to a mate should not be looking at their own
  # dropdowns. The slots are a form, and they live behind Customise.
  test "the profile is what you have done, not the controls for saying it" do
    sign_in_as users(:member_user)
    get profile_path

    # the only form on the screen is the layout's own sign-out button
    assert_select "main select", count: 0
    assert_select "main form", count: 0
    assert_select "a[href=?]", profile_slots_path, text: "Customise"
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
