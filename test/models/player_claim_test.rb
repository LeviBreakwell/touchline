require "test_helper"

class PlayerClaimTest < ActiveSupport::TestCase
  setup do
    @team = teams(:warthogs)
    @user = users(:stranger)
  end

  test "claims a roster entry carrying the user's email" do
    player = @team.players.create!(name: "Sam", email: @user.email_address)

    assert_equal [ player ], Player.claim_by_email(@user)
    assert_equal @user, player.reload.user
  end

  test "joins the user to the team as an accepted member" do
    @team.players.create!(name: "Sam", email: @user.email_address)
    Player.claim_by_email(@user)

    membership = @team.team_memberships.find_by(user: @user)
    assert membership.accepted?
    assert membership.member?
  end

  test "leaves an existing membership's role alone" do
    @team.team_memberships.create!(user: @user, role: :admin, status: :accepted)
    @team.players.create!(name: "Sam", email: @user.email_address)
    Player.claim_by_email(@user)

    assert @team.team_memberships.find_by(user: @user).admin?
  end

  test "ignores a roster entry someone else already claimed" do
    player = @team.players.create!(name: "Sam", email: @user.email_address, user: users(:member_user))

    assert_empty Player.claim_by_email(@user)
    assert_equal users(:member_user), player.reload.user
  end

  test "claims nothing when no roster entry carries the email" do
    assert_empty Player.claim_by_email(@user)
  end

  test "an email may not be repeated within a team" do
    @team.players.create!(name: "Sam", email: "sam@example.com")
    duplicate = @team.players.build(name: "Sammy", email: "SAM@example.com")

    assert_not duplicate.valid?
  end

  test "the same email may appear on two different teams" do
    other = Team.create!(name: "Other", location: "Sydney")
    @team.players.create!(name: "Sam", email: "sam@example.com")

    assert other.players.build(name: "Sam", email: "sam@example.com").valid?
  end

  test "rejects a malformed email" do
    assert_not @team.players.build(name: "Sam", email: "not-an-email").valid?
  end
end
