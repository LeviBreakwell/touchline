require "application_system_test_case"

# Creating an account, in a real browser: the form itself, what a rejected
# submission looks like, and the invite link that most new users actually
# arrive from.
class RegistrationTest < ApplicationSystemTestCase
  def fill_signup_form(name: "New Comer", email: "newcomer@example.com", password: "secret123", confirmation: password)
    fill_in "Your name", with: name
    fill_in "Email", with: email
    fill_in "Password", with: password
    fill_in "Confirm password", with: confirmation
  end

  test "signing up lands you on Touchline, signed in" do
    visit new_registration_path
    fill_signup_form
    click_on "Create account"

    assert_text "Welcome to Touchline!"
    assert_selector "details.user-menu"
  end

  test "a duplicate email is refused without losing what you typed" do
    visit new_registration_path
    fill_signup_form(email: users(:member_user).email_address)
    click_on "Create account"

    assert_selector ".flash.alert", text: /Email address has already been taken/
    assert_field "Email", with: users(:member_user).email_address
    assert_no_selector "details.user-menu"
  end

  test "a mismatched confirmation is refused" do
    visit new_registration_path
    fill_signup_form(confirmation: "somethingelse")
    click_on "Create account"

    assert_selector ".flash.alert"
    assert_no_selector "details.user-menu"
  end

  test "signing up from an invite joins the team, not just the homepage" do
    team = teams(:warthogs)
    visit team_invite_path(team.invite_token)

    click_on "Create account & join"
    fill_signup_form
    click_on "Create account"

    assert_text "You're in! Welcome to #{team.name}."
    assert_equal team_path(team), current_path
  end
end
