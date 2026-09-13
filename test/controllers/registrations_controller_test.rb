require "test_helper"

# Signing up: the one way in that doesn't start with somebody else's invite
# link. The claim-a-waiting-roster-entry behaviour it shares with signing in
# lives in SessionsControllerTest; this file is what's particular to creating
# the account itself.
class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def valid_params(overrides = {})
    { user: {
      name: "New Comer", email_address: "newcomer@example.com",
      password: "secret123", password_confirmation: "secret123"
    }.merge(overrides) }
  end

  test "the form renders for a signed-out visitor" do
    get new_registration_path

    assert_response :success
    assert_select "form"
  end

  test "valid details create the account and sign it straight in" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: valid_params
    end

    user = User.find_by(email_address: "newcomer@example.com")
    assert_equal "New Comer", user.name
    assert user.authenticate("secret123")
    assert_not_nil cookies[:session_id], "signing up should start a session, the same as signing in does"
  end

  test "a blank name is refused" do
    assert_no_difference -> { User.count } do
      post registration_path, params: valid_params(name: "")
    end

    assert_response :unprocessable_entity
    assert_select ".flash.alert", text: /Name can't be blank/
  end

  test "an email that isn't one is refused" do
    assert_no_difference -> { User.count } do
      post registration_path, params: valid_params(email_address: "not-an-email")
    end

    assert_response :unprocessable_entity
  end

  test "an email already on the books is refused, whatever its case" do
    assert_no_difference -> { User.count } do
      post registration_path, params: valid_params(email_address: users(:member_user).email_address.upcase)
    end

    assert_response :unprocessable_entity
    assert_select ".flash.alert", text: /Email address has already been taken/
  end

  test "a confirmation that doesn't match the password is refused" do
    assert_no_difference -> { User.count } do
      post registration_path, params: valid_params(password_confirmation: "somethingelse")
    end

    assert_response :unprocessable_entity
  end

  test "a rejected submission keeps what was already typed" do
    post registration_path, params: valid_params(name: "")

    assert_select "input[name='user[email_address]'][value=?]", "newcomer@example.com"
  end

  test "signing up mid-invite lands back on the invite, not the homepage" do
    team = teams(:warthogs)
    get team_invite_path(team.invite_token)   # sets return_to_after_authenticating, same as a signed-out click would

    post registration_path, params: valid_params
    follow_redirect!

    assert_redirected_to team_path(team)
    assert team.team_memberships.accepted.exists?(user: User.find_by(email_address: "newcomer@example.com"))
  end
end
