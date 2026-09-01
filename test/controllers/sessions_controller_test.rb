require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signing in claims a roster entry left waiting on the user's email" do
    player = teams(:warthogs).players.create!(name: "Sam", email: users(:stranger).email_address)

    sign_in_as users(:stranger)

    assert_equal users(:stranger), player.reload.user
    assert teams(:warthogs).team_memberships.accepted.exists?(user: users(:stranger))
  end

  test "the user is told which team they were added to" do
    teams(:warthogs).players.create!(name: "Sam", email: users(:stranger).email_address)

    sign_in_as users(:stranger)

    assert_match(/added to Warthogs as Sam/, flash[:notice])
  end

  test "signing in with nothing waiting says nothing about teams" do
    sign_in_as users(:stranger)

    assert_nil flash[:notice]
  end

  test "registering claims a roster entry left waiting on that email" do
    player = teams(:warthogs).players.create!(name: "Newcomer", email: "newcomer@example.com")

    post registration_path, params: { user: {
      name: "New Comer", email_address: "newcomer@example.com",
      password: "secret123", password_confirmation: "secret123"
    } }

    assert_equal "newcomer@example.com", player.reload.user.email_address
  end

  test "registering says which team you landed in rather than a generic welcome" do
    teams(:warthogs).players.create!(name: "Newcomer", email: "newcomer@example.com")

    post registration_path, params: { user: {
      name: "New Comer", email_address: "newcomer@example.com",
      password: "secret123", password_confirmation: "secret123"
    } }

    assert_match(/added to Warthogs as Newcomer/, flash[:notice])
  end

  test "registering with nothing waiting still gets the welcome" do
    post registration_path, params: { user: {
      name: "Nobody", email_address: "nobody@example.com",
      password: "secret123", password_confirmation: "secret123"
    } }

    assert_equal "Welcome to Touchline!", flash[:notice]
  end
end
