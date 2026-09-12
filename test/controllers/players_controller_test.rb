require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team   = teams(:warthogs)
    @player = players(:john)
  end

  test "show displays career stats and a season breakdown" do
    get team_player_path(@team, @player)

    assert_response :success
    assert_select "h1", "John"
    assert_select ".season-table tbody tr", 2      # winter 2026 and summer 2025
  end

  # An unclaimed roster entry carries no cosmetics at all — banked history
  # earns nothing until somebody claims it — and the page has to say so.
  test "an unclaimed player says what it is" do
    get team_player_path(@team, @player)

    assert_select ".card-meta", text: /Roster only/
    assert_select ".identity", count: 0
  end

  test "a claimed player wears what they have reached" do
    get team_player_path(@team, players(:jane))

    assert_select ".identity .level-number"
  end

  # This season leads: it is the comparison every arrow on the page makes, so
  # it should not be below the fold.
  test "this season leads, and carries the arrows" do
    get team_player_path(@team, @player)

    assert_select "h2", text: /This season/
    assert_select ".average-row .form"
  end

  test "the career total says which points it is counting" do
    get team_player_path(@team, @player)

    assert_select ".stat-tile-label", text: "Points · team"
    assert_select "dt", text: /Social league/
  end

  test "show is publicly accessible without signing in" do
    get team_player_path(@team, @player)
    assert_response :success
  end

  test "show tells you when a player has no games yet" do
    player = @team.players.create!(name: "Newcomer")
    get team_player_path(@team, player)

    assert_response :success
    assert_select ".empty", text: /No games recorded/
    assert_select ".season-table", count: 0
  end

  test "claim links an unclaimed player to the current user" do
    sign_in_as users(:member_user)
    patch claim_team_player_path(@team, @player)

    assert_equal users(:member_user).id, @player.reload.user_id
    # Claiming lands on one consolidated screen: level, what the banked history
    # earned, what it unlocked, and a title to pick.
    assert_redirected_to profile_slots_path(claimed: @player.id)
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
    assert_redirected_to team_settings_path(@team)
  end

  test "a player can be added with an email to link up later" do
    sign_in_as users(:admin_user)
    post team_players_path(@team), params: { player: { name: "Sam", email: "  SAM@Example.COM " } }

    assert_equal "sam@example.com", Player.find_by(name: "Sam").email
  end

  test "a blank email is stored as nil rather than an empty string" do
    sign_in_as users(:admin_user)
    post team_players_path(@team), params: { player: { name: "Sam", email: "" } }

    assert_nil Player.find_by(name: "Sam").email
  end

  test "the roster reopens the add dialog when the name is missing" do
    sign_in_as users(:admin_user)
    assert_no_difference "Player.count" do
      post team_players_path(@team), params: { player: { name: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "[data-dialog-open-value=true]"
    assert_select ".flash.alert"
  end

  test "the roster offers the add dialog to admins" do
    sign_in_as users(:admin_user)
    get team_settings_path(@team)

    assert_select "dialog.modal"
    assert_select "[data-action='dialog#open']"
  end
end
