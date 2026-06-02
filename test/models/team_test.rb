require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "invite token is generated on create" do
    team = Team.create!(name: "New Team", location: "Brisbane")
    assert_not_nil team.invite_token
    assert_operator team.invite_token.length, :>=, 8
  end

  test "each team gets a unique invite token" do
    a = Team.create!(name: "Team A", location: "Brisbane")
    b = Team.create!(name: "Team B", location: "Brisbane")
    assert_not_equal a.invite_token, b.invite_token
  end
end
