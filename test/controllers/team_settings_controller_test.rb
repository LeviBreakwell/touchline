require "test_helper"

# Admin is one screen behind a gear rather than a fourth tab, so everything an
# admin does to a Team has to be reachable from here.
class TeamSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:warthogs)
    sign_in_as users(:admin_user)
  end

  test "the roster is here, and it is the whole roster" do
    get team_settings_path(@team)

    assert_response :success
    assert_select ".settings-row a", text: "John"
    # Jane has no appearance this season, so the Team tab never ranks her —
    # this is the only screen a signing who has not played shows up on.
    assert_select ".settings-row a", text: "Jane"
  end

  test "the invite link, join requests and the TRL link are all on it" do
    @team.team_memberships.create!(user: users(:stranger), role: :member, status: :pending)

    get team_settings_path(@team)

    assert_select "form[action=?]", regenerate_invite_team_path(@team)
    assert_select "form[action=?]", team_membership_path(@team, @team.team_memberships.pending.sole)
    assert_select "form[action=?]", sync_team_path(@team)
  end

  test "a member who is not an admin cannot get in" do
    sign_in_as users(:member_user)

    get team_settings_path(@team)

    assert_redirected_to team_path(@team)
  end

  test "a stranger cannot get in" do
    sign_in_as users(:stranger)

    get team_settings_path(@team)

    assert_redirected_to team_path(@team)
  end
end
