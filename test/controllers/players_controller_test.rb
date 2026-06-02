require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team   = teams(:warthogs)
    @player = players(:john)
  end

  test "claim links an unclaimed player to the current user" do
    sign_in_as users(:member_user)
    patch claim_team_player_path(@team, @player)

    assert_equal users(:member_user).id, @player.reload.user_id
    assert_redirected_to team_path(@team)
  end

  test "claim replaces a previous claim on the same team" do
    sign_in_as users(:member_user)
    # member_user is already linked to :jane
    patch claim_team_player_path(@team, @player)   # now claims :john

    assert_equal users(:member_user).id, @player.reload.user_id
    assert_nil players(:jane).reload.user_id       # old link removed
  end

  test "claim is blocked for non-members" do
    sign_in_as users(:stranger)
    patch claim_team_player_path(@team, @player)
    assert_redirected_to team_path(@team)
    assert_nil @player.reload.user_id
  end

  test "admin can add a player to the roster" do
    sign_in_as users(:admin_user)
    assert_difference "Player.count" do
      post team_players_path(@team), params: { player: { name: "Sam" } }
    end
    assert_redirected_to team_players_path(@team)
  end
end
